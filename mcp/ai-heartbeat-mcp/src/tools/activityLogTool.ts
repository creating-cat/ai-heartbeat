/**
 * Activity Log Creation Tool
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';

import { checkTimeDeviation } from '../lib/timeUtils';

// Zod schema for activity log input (new format only)
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
});

// Helper functions
function generateActivityLogMarkdown(args: z.infer<typeof activityLogInputSchema>): string {
  const lines: string[] = [];
  
  // Title
  lines.push(`# ハートビートログ：${args.heartbeatId}`);
  lines.push('');
  
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

function getActivityLogFilePath(themeStartId: string, themeDirectoryPart: string, heartbeatId: string, sequence?: number): string {
  // Build theme directory name
  const themeDirectoryName = `${themeStartId}_${themeDirectoryPart}`;
  
  // Build filename
  const filename = sequence ? `${heartbeatId}_${sequence.toString().padStart(2, '0')}.md` : `${heartbeatId}.md`;
  
  return path.join('artifacts', themeDirectoryName, 'histories', filename);
}

async function findAvailableSequence(themeStartId: string, themeDirectoryPart: string, heartbeatId: string): Promise<{ sequence: number | null; warning: string | null }> {
  const basePath = getActivityLogFilePath(themeStartId, themeDirectoryPart, heartbeatId);
  
  // 基本ファイルが存在しない場合は連番なしで作成
  if (!await fs.pathExists(basePath)) {
    return { sequence: null, warning: null };
  }
  
  // 連番ファイルをチェック
  for (let i = 1; i <= 99; i++) {
    const sequencePath = getActivityLogFilePath(themeStartId, themeDirectoryPart, heartbeatId, i);
    if (!await fs.pathExists(sequencePath)) {
      return { 
        sequence: i, 
        warning: `ハートビートID ${heartbeatId} の活動ログは既に存在するため、連番 ${i.toString().padStart(2, '0')} を付与しました。`
      };
    }
  }
  
  // 99個まで埋まっている場合はエラー
  throw new Error(`ハートビートID ${heartbeatId} の活動ログの連番が上限（99）に達しました。`);
}

export const activityLogTool = {
  name: 'create_activity_log',
  description: 'AIハートビートシステム用の、標準形式の活動ログを作成します。原則は1ハートビートに対して1つの活動ログの作成です。このハートビート内での活動がまだ終わっていない場合は、まだこのツールを使用すべきではありません。逆にこのツールを使用した後は活動を終了させて、次の活動は次のハートビートで行うべきです。\n\n新形式: themeStartId + themeDirectoryPart の組み合わせでテーマを指定してください。',
  input_schema: activityLogInputSchema,
  execute: async (args: z.infer<typeof activityLogInputSchema>) => {
    try {
      // Generate markdown content
      const markdownContent = generateActivityLogMarkdown(args);
      
      // Sanitize directory part to prevent directory traversal
      const sanitizedDirectoryPart = path.basename(args.themeDirectoryPart);
      
      // Build theme directory path
      const themeDirectoryName = `${args.themeStartId}_${sanitizedDirectoryPart}`;
      const themeDirectoryPath = path.join('artifacts', themeDirectoryName);
      
      // Check if theme directory exists
      if (!await fs.pathExists(themeDirectoryPath)) {
        throw new Error(`テーマディレクトリが存在しません: ${themeDirectoryPath}`);
      }
      
      // Check for duplicates and find available sequence
      const { sequence, warning } = await findAvailableSequence(args.themeStartId, sanitizedDirectoryPart, args.heartbeatId);
      const filePath = getActivityLogFilePath(args.themeStartId, sanitizedDirectoryPart, args.heartbeatId, sequence ?? undefined);
      
      // Check time deviation
      const timeWarning = await checkTimeDeviation(args.heartbeatId);
      
      // Ensure directory exists
      await fs.ensureDir(path.dirname(filePath));
      
      // Write file
      await fs.writeFile(filePath, markdownContent, 'utf-8');
      
      // Prepare response message
      let responseText = `活動ログを作成しました: ${filePath}`;
      responseText += `\n📁 テーマ: ${sanitizedDirectoryPart} (${args.themeStartId})`;
      
      if (warning) {
        responseText += `\n⚠️ ${warning}`;
      }
      
      // Sanitization warning
      if (sanitizedDirectoryPart !== args.themeDirectoryPart) {
        responseText += `\n⚠️ ディレクトリ名を「${args.themeDirectoryPart}」から「${sanitizedDirectoryPart}」に修正しました`;
      }
      
      if (timeWarning) {
        responseText += `\n${timeWarning}`;
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