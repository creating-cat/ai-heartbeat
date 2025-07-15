/**
 * Activity Log Creation Tool
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';

import { checkTimeDeviation } from '../lib/timeUtils';

// Zod schema for activity log input
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
  themeDirectory: z.string().describe('現在のテーマのディレクトリ名。推奨形式: "20250115143000_ai_research" (THEME_START_ID付き)。既存の古い形式ディレクトリも使用可能。'),
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

function getActivityLogFilePath(theme: string, heartbeatId: string, sequence?: number): string {
  // MCPサーバーはプロジェクトルートで実行される前提
  // 現在の作業ディレクトリから相対パスで指定
  const filename = sequence ? `${heartbeatId}_${sequence.toString().padStart(2, '0')}.md` : `${heartbeatId}.md`;
  return path.join('artifacts', theme, 'histories', filename);
}

async function findAvailableSequence(theme: string, heartbeatId: string): Promise<{ sequence: number | null; warning: string | null }> {
  const basePath = getActivityLogFilePath(theme, heartbeatId);
  
  // 基本ファイルが存在しない場合は連番なしで作成
  if (!await fs.pathExists(basePath)) {
    return { sequence: null, warning: null };
  }
  
  // 連番ファイルをチェック
  for (let i = 1; i <= 99; i++) {
    const sequencePath = getActivityLogFilePath(theme, heartbeatId, i);
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
  description: 'Creates a standard format activity log for the AI Heartbeat System.',
  input_schema: activityLogInputSchema,
  execute: async (args: z.infer<typeof activityLogInputSchema>) => {
    try {
      // Generate markdown content
      const markdownContent = generateActivityLogMarkdown(args);
      
      // Determine file path (use basename for safety)
      const themeDir = path.basename(args.themeDirectory);
      
      // ディレクトリ存在確認
      const themeDirectoryPath = path.join('artifacts', themeDir);
      if (!await fs.pathExists(themeDirectoryPath)) {
        throw new Error(`テーマディレクトリが存在しません: ${themeDirectoryPath}`);
      }

      // オプション: 形式チェックは警告レベルに
      const themeStartIdMatch = themeDir.match(/^(\d{14})_(.+)$/);
      let themeStartId = 'unknown';
      let themeName = themeDir;

      if (themeStartIdMatch) {
        [, themeStartId, themeName] = themeStartIdMatch;
      } else {
        console.warn(`注意: ディレクトリ名が推奨形式ではありません: ${themeDir}`);
        themeName = themeDir;
      }
      
      // Check for duplicates and find available sequence
      const { sequence, warning } = await findAvailableSequence(themeDir, args.heartbeatId);
      const filePath = getActivityLogFilePath(themeDir, args.heartbeatId, sequence ?? undefined);
      
      // Check time deviation
      const timeWarning = await checkTimeDeviation(args.heartbeatId);
      
      // Ensure directory exists
      await fs.ensureDir(path.dirname(filePath));
      
      // Write file
      await fs.writeFile(filePath, markdownContent, 'utf-8');
      
      // Prepare response message
      let responseText = `活動ログを作成しました: ${filePath}`;
      if (themeStartId !== 'unknown') {
        responseText += `\n📁 テーマ: ${themeName} (${themeStartId})`;
      } else {
        responseText += `\n📁 テーマ: ${themeName}`;
      }
      if (warning) {
        responseText += `\n⚠️ ${warning}`;
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