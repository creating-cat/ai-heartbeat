/**
 * Extended Processing Declaration Tool
 * 長時間処理の事前宣言ツール
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';
import { EXTENDED_PROCESSING_DIR } from '../lib/pathConstants';
import { convertTimestampToSeconds } from '../lib/timeUtils';

// Zod schema for extended processing declaration
export const declareExtendedProcessingInputSchema = z.object({
  heartbeatId: z.string()
    .regex(/^\d{14}$/, 'ハートビートIDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります。')
    .describe('YYYYMMDDHHMMSS形式のハートビートID'),
  plannedDurationMinutes: z.number()
    .min(1, '計画時間は1分以上である必要があります')
    .max(30, '計画時間は最大30分までです')
    .describe('計画処理時間（分）。最大30分まで'),
  reason: z.string()
    .min(10, '理由は10文字以上で記述してください')
    .max(200, '理由は200文字以内で記述してください')
    .describe('長時間処理が必要な理由の説明'),
});

/**
 * 長時間処理宣言ファイルの内容を生成（簡素化版）
 */
function generateDeclarationContent(args: z.infer<typeof declareExtendedProcessingInputSchema>): string {
  return `# 長時間処理宣言
ハートビートID: ${args.heartbeatId}
計画処理時間: ${args.plannedDurationMinutes}分
理由: ${args.reason}
`;
}

/**
 * 既存の宣言ファイルをクリーンアップ（異なるハートビートIDの場合）
 */
async function cleanupOldDeclarations(currentHeartbeatId: string): Promise<string[]> {
  const declarationFile = path.join(EXTENDED_PROCESSING_DIR, 'current.conf');
  const cleanupMessages: string[] = [];
  
  if (await fs.pathExists(declarationFile)) {
    try {
      const content = await fs.readFile(declarationFile, 'utf-8');
      const match = content.match(/ハートビートID: (\d{14})/);
      
      if (match && match[1] !== currentHeartbeatId) {
        await fs.remove(declarationFile);
        cleanupMessages.push(`古い宣言ファイルを削除しました（ハートビートID: ${match[1]}）`);
      }
    } catch (error) {
      // ファイル読み込みエラーの場合は削除
      await fs.remove(declarationFile);
      cleanupMessages.push('破損した宣言ファイルを削除しました');
    }
  }
  
  return cleanupMessages;
}

export const declareExtendedProcessingTool = {
  name: 'declare_extended_processing',
  description: '長時間処理（最大30分）の事前宣言を行います。この宣言により、活動ログ頻度異常検知とタイムスタンプ異常検知が一時的に無効化されます。活動ログ作成時に自動的に宣言は解除されます。',
  input_schema: declareExtendedProcessingInputSchema,
  execute: async (args: z.infer<typeof declareExtendedProcessingInputSchema>) => {
    try {
      // 宣言ディレクトリの作成
      await fs.ensureDir(EXTENDED_PROCESSING_DIR);
      
      // 古い宣言のクリーンアップ
      const cleanupMessages = await cleanupOldDeclarations(args.heartbeatId);
      
      // 宣言内容の生成
      const declarationContent = generateDeclarationContent(args);
      
      // 宣言ファイルの作成
      const declarationFile = path.join(EXTENDED_PROCESSING_DIR, 'current.conf');
      await fs.writeFile(declarationFile, declarationContent, 'utf-8');
      
      // レスポンスメッセージの構築
      let responseText = `長時間処理を宣言しました: ${args.plannedDurationMinutes}分間`;
      responseText += `\n理由: ${args.reason}`;
      responseText += `\n宣言ファイル: ${declarationFile}`;
      
      if (cleanupMessages.length > 0) {
        responseText += `\n${cleanupMessages.join('\n')}`;
      }
      
      responseText += '\n\nこの時間内は活動ログ頻度異常検知とタイムスタンプ異常検知が無効化されます。';
      responseText += '\n活動ログ作成時に宣言は自動的に解除されます。';
      
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