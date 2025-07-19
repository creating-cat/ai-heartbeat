/**
 * Activity Log Creation Tool
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';

import { checkTimeDeviation, convertTimestampToSeconds } from '../lib/timeUtils';
import { resolveThemePath } from '../lib/themeUtils';

// Zod schema for activity log input (サブテーマ対応版)
export const activityLogInputSchema = z.object({
  heartbeatId: z.string()
    .regex(/^\d{14}$/, 'ハートビートIDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります。')
    .describe('YYYYMMDDHHMMSS形式のハートビートID。注意: 同じIDのログが既に存在する場合、自動で連番が付与されます（例: _01）。これは活動ログ作成後に処理を継続してしまったことを示唆するため、通常は避けるべきです。'),
  activityType: z.enum(['観測', '思考', '創造', '内省', 'テーマ開始', 'テーマ終了', '回復', 'その他'])
    .describe("実行した活動の種別。'観測', '思考', '創造', '内省', 'テーマ開始', 'テーマ終了', '回復', 'その他' のいずれかである必要があります。"),
  activityContent: z.array(z.string()).describe('活動内容の簡潔な説明のリスト。'),
  artifacts: z.array(z.string()).optional().default([]).describe('作成または修正したファイルのパスのリスト。'),
  evaluation: z.string().optional().default('').describe('自己評価や備考。'),
  auxiliaryOperations: z.array(z.enum(['ファイル読み込み', '軽微な検索', '軽微な置換', 'Web検索', 'その他']))
    .optional()
    .default([])
    .describe("活動中に使用した補助的な操作。'ファイル読み込み', '軽微な検索', '軽微な置換', 'Web検索', 'その他' の要素を含む配列です。"),
  themeStartId: z.string()
    .regex(/^\d{14}$/, 'THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .describe('テーマ開始時のハートビートID'),
  themeDirectoryPart: z.string()
    .describe('テーマディレクトリ名の一部。THEME_START_IDと組み合わせて "{THEME_START_ID}_{themeDirectoryPart}" の形式でテーマディレクトリが特定されます'),
  
  // 🆕 サブテーマ対応の新規フィールド
  parentThemeStartId: z.string()
    .regex(/^\d{14}$/, 'PARENT_THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .optional()
    .describe('サブテーマの場合、親テーマのTHEME_START_IDを指定。nullまたは未指定の場合はルートテーマとして扱われます'),
  parentThemeDirectoryPart: z.string()
    .optional()
    .describe('サブテーマの場合、親テーマのディレクトリ部分を指定。parentThemeStartIdが指定された場合は必須'),
});



// Helper functions

/**
 * ハートビート開始からの経過時間をチェックして警告メッセージを生成
 */
function checkProcessingTime(heartbeatId: string): string | null {
  try {
    const heartbeatTime = convertTimestampToSeconds(heartbeatId);
    const currentTime = Math.floor(Date.now() / 1000);
    const elapsedSeconds = currentTime - heartbeatTime;
    const elapsedMinutes = Math.floor(elapsedSeconds / 60);
    
    if (elapsedSeconds >= 600) { // 10分
      return `長時間処理警告: ハートビート開始から${elapsedMinutes}分が経過しています。処理を区切ることを推奨します。`;
    } else if (elapsedSeconds >= 300) { // 5分
      return `処理時間通知: ハートビート開始から${elapsedMinutes}分が経過しています。`;
    }
    
    return null;
  } catch (error) {
    // タイムスタンプ変換エラーの場合は警告を出さない
    return null;
  }
}

function generateActivityLogMarkdown(args: z.infer<typeof activityLogInputSchema>): string {
  const lines: string[] = [];
  
  // Title
  lines.push(`# ハートビートログ：${args.heartbeatId}`);
  lines.push('');
  
  // サブテーマ情報（サブテーマの場合のみ）
  if (args.parentThemeStartId && args.parentThemeDirectoryPart) {
    lines.push('## テーマ情報');
    lines.push(`**現在のテーマ**: ${args.themeStartId}_${args.themeDirectoryPart} (サブテーマ)`);
    lines.push(`**親テーマ**: ${args.parentThemeStartId}_${args.parentThemeDirectoryPart}`);
    lines.push('');
  }
  
  // Activity type with auxiliary operations
  lines.push('## 活動種別');
  let activityTypeText = args.activityType;
  if (args.auxiliaryOperations && args.auxiliaryOperations.length > 0) {
    const operationsText = args.auxiliaryOperations.join('、');
    activityTypeText += ` (${operationsText}使用)`;
  }
  lines.push(activityTypeText);
  lines.push('');
  
  // Activity content
  lines.push('## 活動内容');
  if (args.activityContent.length > 0) {
    args.activityContent.forEach(content => {
      lines.push(`- ${content}`);
    });
  } else {
    lines.push('具体的な活動内容なし');
  }
  lines.push('');
  
  // Artifacts
  lines.push('## 成果物、関連ファイル');
  if (args.artifacts && args.artifacts.length > 0) {
    args.artifacts.forEach(artifact => {
      lines.push(`- ${artifact}`);
    });
  } else {
    lines.push('なし');
  }
  lines.push('');
  
  // Evaluation
  lines.push('## 自己評価、備考');
  if (args.evaluation && args.evaluation.trim()) {
    lines.push(args.evaluation);
  } else {
    lines.push('特記事項なし');
  }
  lines.push('');
  
  return lines.join('\n');
}

function getActivityLogFilePath(
  themeStartId: string, 
  themeDirectoryPart: string, 
  heartbeatId: string, 
  sequence?: number,
  parentThemeStartId?: string,
  parentThemeDirectoryPart?: string
): string {
  // テーマディレクトリパスを解決
  const themeDirectoryPath = resolveThemePath(
    themeStartId,
    themeDirectoryPart,
    parentThemeStartId,
    parentThemeDirectoryPart
  );
  
  // ファイル名生成
  const filename = sequence ? `${heartbeatId}_${sequence.toString().padStart(2, '0')}.md` : `${heartbeatId}.md`;
  
  return path.join(themeDirectoryPath, 'histories', filename);
}

async function findAvailableSequence(
  themeStartId: string, 
  themeDirectoryPart: string, 
  heartbeatId: string,
  parentThemeStartId?: string,
  parentThemeDirectoryPart?: string
): Promise<{ sequence: number | null; warning: string | null }> {
  const basePath = getActivityLogFilePath(
    themeStartId, 
    themeDirectoryPart, 
    heartbeatId, 
    undefined,
    parentThemeStartId,
    parentThemeDirectoryPart
  );
  
  // 基本ファイルが存在しない場合は連番なしで作成
  if (!await fs.pathExists(basePath)) {
    return { sequence: null, warning: null };
  }
  
  // 連番ファイルをチェック（ファイル重複回避のため連番生成ロジックは維持）
  for (let i = 1; i <= 99; i++) {
    const sequencePath = getActivityLogFilePath(
      themeStartId, 
      themeDirectoryPart, 
      heartbeatId, 
      i,
      parentThemeStartId,
      parentThemeDirectoryPart
    );
    if (!await fs.pathExists(sequencePath)) {
      // 連番警告は削除し、時間ベース警告に統一
      return { 
        sequence: i, 
        warning: null  // 連番警告を削除
      };
    }
  }
  
  // 99個まで埋まっている場合はエラー
  throw new Error(`ハートビートID ${heartbeatId} の活動ログの連番が上限（99）に達しました。`);
}

export const activityLogTool = {
  name: 'create_activity_log',
  description: 'AIハートビートシステム用の、標準形式の活動ログを作成します。サブテーマにも対応しており、parentThemeStartIdを指定することでサブテーマの活動ログとして作成されます。原則は1ハートビートに対して1つの活動ログの作成です。このハートビート内での活動がまだ終わっていない場合は、まだこのツールを使用すべきではありません。逆にこのツールを使用した後は活動を終了させて、次の活動は次のハートビートで行うべきです。',
  input_schema: activityLogInputSchema,
  execute: async (args: z.infer<typeof activityLogInputSchema>) => {
    try {
      // バリデーション
      if (args.parentThemeStartId && !args.parentThemeDirectoryPart) {
        throw new Error('parentThemeStartIdが指定された場合、parentThemeDirectoryPartも必須です');
      }

      if (args.parentThemeDirectoryPart && !args.parentThemeStartId) {
        throw new Error('parentThemeDirectoryPartが指定された場合、parentThemeStartIdも必須です');
      }

      // Generate markdown content
      const markdownContent = generateActivityLogMarkdown(args);
      
      // Sanitize directory part to prevent directory traversal
      const sanitizedDirectoryPart = path.basename(args.themeDirectoryPart);
      const sanitizedParentDirectoryPart = args.parentThemeDirectoryPart ? 
        path.basename(args.parentThemeDirectoryPart) : undefined;
      
      // テーマディレクトリパスを構築
      const themeDirectoryPath = resolveThemePath(
        args.themeStartId,
        sanitizedDirectoryPart,
        args.parentThemeStartId,
        sanitizedParentDirectoryPart
      );
      
      // テーマディレクトリの存在確認
      if (!await fs.pathExists(themeDirectoryPath)) {
        const themeType = args.parentThemeStartId ? 'サブテーマ' : 'テーマ';
        throw new Error(`${themeType}ディレクトリが存在しません: ${themeDirectoryPath}`);
      }
      
      // Check for duplicates and find available sequence
      const { sequence, warning } = await findAvailableSequence(
        args.themeStartId, 
        sanitizedDirectoryPart, 
        args.heartbeatId,
        args.parentThemeStartId,
        sanitizedParentDirectoryPart
      );
      
      const filePath = getActivityLogFilePath(
        args.themeStartId, 
        sanitizedDirectoryPart, 
        args.heartbeatId, 
        sequence ?? undefined,
        args.parentThemeStartId,
        sanitizedParentDirectoryPart
      );
      
      // Check time deviation (既存の時間チェック)
      const timeWarning = await checkTimeDeviation(args.heartbeatId);
      
      // Check processing time (新しい時間ベース警告)
      const processingTimeWarning = checkProcessingTime(args.heartbeatId);
      
      // Ensure directory exists
      await fs.ensureDir(path.dirname(filePath));
      
      // Write file
      await fs.writeFile(filePath, markdownContent, 'utf-8');
      
      // Prepare response message
      const themeType = args.parentThemeStartId ? 'サブテーマ' : 'テーマ';
      let responseText = `活動ログを作成しました: ${filePath}`;
      
      if (args.parentThemeStartId) {
        responseText += `\n${themeType}: ${sanitizedDirectoryPart} (${args.themeStartId})`;
        responseText += `\n親テーマ: ${sanitizedParentDirectoryPart} (${args.parentThemeStartId})`;
      } else {
        responseText += `\n${themeType}: ${sanitizedDirectoryPart} (${args.themeStartId})`;
      }
      
      if (warning) {
        responseText += `\n警告: ${warning}`;
      }
      
      // Sanitization warning
      if (sanitizedDirectoryPart !== args.themeDirectoryPart) {
        responseText += `\n警告: ディレクトリ名を「${args.themeDirectoryPart}」から「${sanitizedDirectoryPart}」に修正しました`;
      }
      
      if (sanitizedParentDirectoryPart && args.parentThemeDirectoryPart && 
          sanitizedParentDirectoryPart !== args.parentThemeDirectoryPart) {
        responseText += `\n警告: 親ディレクトリ名を「${args.parentThemeDirectoryPart}」から「${sanitizedParentDirectoryPart}」に修正しました`;
      }
      
      if (timeWarning) {
        responseText += `\n${timeWarning}`;
      }
      
      // 新しい時間ベース警告を追加
      if (processingTimeWarning) {
        responseText += `\n${processingTimeWarning}`;
      }
      
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