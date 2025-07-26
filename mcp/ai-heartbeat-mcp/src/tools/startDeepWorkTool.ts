/**
 * Start Deep Work Tool
 * 深い作業宣言ツール
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';
import { convertTimestampToSeconds } from '../lib/timeUtils';

// 深い作業ディレクトリのパス
const DEEP_WORK_DIR = 'stats/deep_work';

// Base Zod schema for deep work declaration
const startDeepWorkBaseSchema = z.object({
  heartbeatId: z.string()
    .regex(/^\d{14}$/, 'ハートビートIDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります。')
    .describe('YYYYMMDDHHMMSS形式のハートビートID'),
  restrictionType: z.enum(['flexible', 'strict'])
    .describe('制限タイプ: flexible（チェックポイント可能）またはstrict（完全に中断なし）'),
  activityDescription: z.string()
    .min(10, '活動予定内容は10文字以上で記述してください')
    .max(200, '活動予定内容は200文字以内で記述してください')
    .describe('深い作業の内容説明'),
  plannedDurationMinutes: z.number()
    .min(1, '予定時間は1分以上である必要があります')
    .max(30, '予定時間は最大30分までです')
    .optional()
    .describe('予定時間（分）。strictモードの場合のみ必須、最大30分まで'),
});

// Refined schema for validation
export const startDeepWorkInputSchema = startDeepWorkBaseSchema.refine((data) => {
  // strictモードの場合はplannedDurationMinutesが必須
  if (data.restrictionType === 'strict' && !data.plannedDurationMinutes) {
    return false;
  }
  return true;
}, {
  message: 'strictモードの場合は予定時間の指定が必要です',
  path: ['plannedDurationMinutes'],
});

/**
 * 深い作業宣言ファイルの内容を生成
 */
function generateDeepWorkContent(args: z.infer<typeof startDeepWorkBaseSchema>): string {
  let content = `制限タイプ: ${args.restrictionType}\n`;
  content += `活動予定内容: ${args.activityDescription}\n`;
  
  if (args.restrictionType === 'strict' && args.plannedDurationMinutes) {
    content += `予定時間: ${args.plannedDurationMinutes}分\n`;
  }
  
  return content;
}

/**
 * 既存の深い作業宣言ファイルをクリーンアップ
 */
async function cleanupOldDeepWorkDeclarations(currentHeartbeatId: string): Promise<string[]> {
  const cleanupMessages: string[] = [];
  
  try {
    // アクティブなファイル（.completed.txt と .expired.txt 以外）を検索
    const files = await fs.readdir(DEEP_WORK_DIR);
    const activeFiles = files.filter(file => 
      file.match(/^\d{14}\.txt$/) && file !== `${currentHeartbeatId}.txt`
    );
    
    for (const file of activeFiles) {
      const filePath = path.join(DEEP_WORK_DIR, file);
      const heartbeatId = file.replace('.txt', '');
      
      // 古いファイルを .expired.txt にリネーム
      const expiredPath = path.join(DEEP_WORK_DIR, `${heartbeatId}.expired.txt`);
      await fs.move(filePath, expiredPath);
      cleanupMessages.push(`古い深い作業宣言を期限切れに変更しました（ハートビートID: ${heartbeatId}）`);
    }
  } catch (error) {
    // ディレクトリが存在しない場合などは無視
  }
  
  return cleanupMessages;
}

/**
 * 制限タイプに応じたアドバイスメッセージを生成
 */
function generateAdviceMessage(restrictionType: 'flexible' | 'strict', plannedDurationMinutes?: number): string {
  if (restrictionType === 'flexible') {
    return `
**flexibleモード（柔軟な制限）:**
- 活動ログの作成は一時的に停止しても構いません
- ただし、定期的にcheckpointツールでチェックポイントログを作成してください
- 内省不足エラーは無効化されます
- 次の活動ログ作成時に宣言は自動的に解除されます

**推奨事項:**
- 長時間の処理でも、適度な間隔でcheckpointツールを使用してください
- 処理が完了したら、必ず活動ログを作成してください`;
  } else {
    return `
**strictモード（厳格な制限）:**
- 指定時間（${plannedDurationMinutes}分）まで、全ての異常検知が無効化されます
- チェックポイントログの作成も不要です
- 内省不足エラーも無効化されます
- 指定時間内に活動ログを作成すれば正常完了となります
- 時間超過した場合は自動的に期限切れとなり、異常検知が復活します

**注意事項:**
- 指定時間は余裕を持って設定してください
- 時間内に必ず活動ログを作成してください`;
  }
}

export const startDeepWorkTool = {
  name: 'start_deep_work',
  description: `深い作業の宣言を行います。2つのモードがあります：
  
**flexibleモード**: チェックポイント作成可能、内省不足エラーのみ無効化
**strictモード**: 指定時間まで全ての異常検知を無効化

活動ログ作成時に宣言は自動的に解除されます。深い作業完了後は必ず内省活動を行ってください。`,
  input_schema: startDeepWorkBaseSchema,
  execute: async (args: z.infer<typeof startDeepWorkBaseSchema>) => {
    // 入力検証（strictモードの場合のplannedDurationMinutes必須チェック）
    const validationResult = startDeepWorkInputSchema.safeParse(args);
    if (!validationResult.success) {
      return {
        content: [
          {
            type: 'text' as const,
            text: `入力エラー: ${validationResult.error.errors.map(e => e.message).join(', ')}`,
          },
        ],
      };
    }
    try {
      // 深い作業ディレクトリの作成
      await fs.ensureDir(DEEP_WORK_DIR);
      
      // 古い宣言のクリーンアップ
      const cleanupMessages = await cleanupOldDeepWorkDeclarations(args.heartbeatId);
      
      // 宣言内容の生成
      const declarationContent = generateDeepWorkContent(args);
      
      // 宣言ファイルの作成
      const declarationFile = path.join(DEEP_WORK_DIR, `${args.heartbeatId}.txt`);
      await fs.writeFile(declarationFile, declarationContent, 'utf-8');
      
      // レスポンスメッセージの構築
      let responseText = `深い作業を宣言しました（${args.restrictionType}モード）`;
      responseText += `\n活動内容: ${args.activityDescription}`;
      
      if (args.restrictionType === 'strict' && args.plannedDurationMinutes) {
        responseText += `\n予定時間: ${args.plannedDurationMinutes}分`;
      }
      
      responseText += `\n宣言ファイル: ${declarationFile}`;
      
      if (cleanupMessages.length > 0) {
        responseText += `\n\n${cleanupMessages.join('\n')}`;
      }
      
      // 制限タイプに応じたアドバイス
      responseText += generateAdviceMessage(args.restrictionType, args.plannedDurationMinutes);
      
      responseText += '\n\n**重要**: 深い作業完了後は必ず内省活動を行ってください。';
      
      return {
        content: [
          {
            type: 'text' as const,
            text: responseText,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text' as const,
            text: `エラーが発生しました: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
      };
    }
  },
} as const;