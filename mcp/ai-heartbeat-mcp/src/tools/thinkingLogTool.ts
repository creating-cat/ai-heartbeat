/**
 * Thinking Log Creation Tool
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';

// Zod schema for thinking log input
export const thinkingLogInputSchema = z.object({
  heartbeatId: z.string().describe('ハートビートID (YYYYMMDDHHMMSS形式)'),
  activityType: z.enum(['観測', '思考', '創造', '内省', 'その他']).describe('活動種別'),
  activityContent: z.string().describe('活動内容の簡潔な説明'),
  artifacts: z.array(z.string()).optional().default([]).describe('作成・修正したファイルのパス一覧'),
  evaluation: z.string().optional().default('').describe('自己評価・備考'),
  auxiliaryOperations: z.array(z.enum(['ファイル読み込み', '軽微な検索', '軽微な置換', 'Web検索', 'その他'])).optional().default([]).describe('使用した補助操作'),
  currentTheme: z.string().optional().describe('現在のテーマ名（自動検出も可能）'),
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

function getThinkingLogFilePath(theme: string, heartbeatId: string): string {
  // Get project root (4 levels up from this file)
  const projectRoot = path.resolve(__dirname, '../../../../');
  
  // Create path: artifacts/{theme}/histories/{heartbeatId}.md
  return path.join(projectRoot, 'artifacts', theme, 'histories', `${heartbeatId}.md`);
}

export const thinkingLogTool = {
  name: 'create_thinking_log',
  description: 'AI心臓システム用の標準フォーマット思考ログを作成',
  input_schema: thinkingLogInputSchema,
  execute: async (args: z.infer<typeof thinkingLogInputSchema>) => {
    try {
      // Generate markdown content
      const markdownContent = generateThinkingLogMarkdown(args);
      
      // Determine file path
      const theme = args.currentTheme || 'default_theme';
      const filePath = getThinkingLogFilePath(theme, args.heartbeatId);
      
      // Ensure directory exists
      await fs.ensureDir(path.dirname(filePath));
      
      // Write file
      await fs.writeFile(filePath, markdownContent, 'utf-8');
      
      return {
        content: [
          {
            type: 'text' as const,
            text: `思考ログを作成しました: ${filePath}`,
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