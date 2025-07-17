/**
 * Generic Tool Usage Reporting Tool
 */
import * as fs from 'fs-extra';
import * as path from 'path';
import { z } from 'zod';

const COOLDOWN_DIR = path.join('stats', 'cooldown');
const LOCK_DIR = path.join('stats', 'lock');

export const reportToolUsageInputSchema = z.object({
  toolId: z.string()
    .min(1, 'toolIdは必須です。')
    .regex(/^[a-zA-Z0-9_.-]+$/, 'toolIdには英数字、アンダースコア、ドット、ハイフンのみ使用できます。')
    .describe('報告するツールの一意なID。例: "gemini.google.search"'),
  status: z.enum(['success', 'quota_exceeded'])
    .describe("ツールの実行結果。'success'はクールダウンを設定し、'quota_exceeded'はロックを設定します。"),
});

export const reportToolUsageTool = {
  name: 'report_tool_usage',
  description: 'ツールの使用状況を報告し、クールダウンやAPIクォータを管理します。使用制限のあるツールを使用した後に呼び出す必要があります。',
  input_schema: reportToolUsageInputSchema,
  execute: async (args: z.infer<typeof reportToolUsageInputSchema>) => {
    try {
      const { toolId, status } = args;
      const targetDir = status === 'success' ? COOLDOWN_DIR : LOCK_DIR;
      const stateFile = path.join(targetDir, toolId);

      await fs.ensureDir(targetDir);
      await fs.ensureFile(stateFile);

      if (status === 'success' && await fs.pathExists(path.join(LOCK_DIR, toolId))) {
        await fs.remove(path.join(LOCK_DIR, toolId));
      }

      return { content: [{ type: 'text' as const, text: `Success: Recorded '${status}' status for tool [${toolId}].` }] };
    } catch (error) {
      return {
        content: [{ type: 'text' as const, text: `Error: Failed to report tool usage. Reason: ${error instanceof Error ? error.message : String(error)}` }],
      };
    }
  },
} as const;