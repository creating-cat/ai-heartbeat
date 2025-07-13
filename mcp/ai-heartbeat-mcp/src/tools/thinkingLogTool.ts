/**
 * Thinking Log Creation Tool
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';

import { checkTimeDeviation } from '../lib/timeUtils';

// Zod schema for thinking log input
export const thinkingLogInputSchema = z.object({
  heartbeatId: z.string()
    .regex(/^\d{14}$/, 'ハートビートIDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .describe('ハートビートID (YYYYMMDDHHMMSS形式)'),
  activityType: z.enum(['観測', '思考', '創造', '内省', 'その他']).describe('活動種別'),
  activityContent: z.string().describe('活動内容の簡潔な説明'),
  artifacts: z.array(z.string()).optional().default([]).describe('作成・修正したファイルのパス一覧'),
  evaluation: z.string().optional().default('').describe('自己評価・備考'),
  auxiliaryOperations: z.array(z.enum(['ファイル読み込み', '軽微な検索', '軽微な置換', 'Web検索', 'その他'])).optional().default([]).describe('使用した補助操作'),
  themeDirectory: z.string().describe('現在のテーマディレクトリ名'),
});

// Helper functions
function generateThinkingLogMarkdown(args: z.infer<typeof thinkingLogInputSchema>): string {
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
  lines.push(args.activityContent);
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

function getThinkingLogFilePath(theme: string, heartbeatId: string, sequence?: number): string {
  // MCPサーバーはプロジェクトルートで実行される前提
  // 現在の作業ディレクトリから相対パスで指定
  const filename = sequence ? `${heartbeatId}_${sequence.toString().padStart(2, '0')}.md` : `${heartbeatId}.md`;
  return path.join('artifacts', theme, 'histories', filename);
}

async function findAvailableSequence(theme: string, heartbeatId: string): Promise<{ sequence: number | null; warning: string | null }> {
  const basePath = getThinkingLogFilePath(theme, heartbeatId);
  
  // 基本ファイルが存在しない場合は連番なしで作成
  if (!await fs.pathExists(basePath)) {
    return { sequence: null, warning: null };
  }
  
  // 連番ファイルをチェック
  for (let i = 1; i <= 99; i++) {
    const sequencePath = getThinkingLogFilePath(theme, heartbeatId, i);
    if (!await fs.pathExists(sequencePath)) {
      return { 
        sequence: i, 
        warning: `ハートビートID ${heartbeatId} の思考ログは既に存在するため、連番 ${i.toString().padStart(2, '0')} を付与しました。`
      };
    }
  }
  
  // 99個まで埋まっている場合はエラー
  throw new Error(`ハートビートID ${heartbeatId} の思考ログの連番が上限（99）に達しました。`);
}

export const thinkingLogTool = {
  name: 'create_thinking_log',
  description: 'AI心臓システム用の標準フォーマット思考ログを作成',
  input_schema: thinkingLogInputSchema,
  execute: async (args: z.infer<typeof thinkingLogInputSchema>) => {
    try {
      // Generate markdown content
      const markdownContent = generateThinkingLogMarkdown(args);
      
      // Determine file path (use basename for safety)
      const themeDir = path.basename(args.themeDirectory);
      
      // Check for duplicates and find available sequence
      const { sequence, warning } = await findAvailableSequence(themeDir, args.heartbeatId);
      const filePath = getThinkingLogFilePath(themeDir, args.heartbeatId, sequence ?? undefined);
      
      // Check time deviation
      const timeWarning = await checkTimeDeviation(args.heartbeatId);
      
      // Ensure directory exists
      await fs.ensureDir(path.dirname(filePath));
      
      // Write file
      await fs.writeFile(filePath, markdownContent, 'utf-8');
      
      // Prepare response message
      let responseText = `思考ログを作成しました: ${filePath}`;
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