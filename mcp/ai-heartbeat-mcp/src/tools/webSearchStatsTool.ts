/**
 * Web Search Statistics Update Tool
 */

import * as fs from 'fs-extra';
import * as path from 'path';
import { z } from 'zod';

const STATS_DIR = 'stats';
const LAST_SEARCH_FILE = path.join(STATS_DIR, 'last_web_search.txt');
const QUOTA_EXCEEDED_FILE = path.join(STATS_DIR, 'quota_exceeded.txt');

export const webSearchStatsInputSchema = z.object({
  status: z.enum(['success', 'quota_exceeded']).describe("Web検索の試行結果。'success'または'quota_exceeded'のいずれかを指定します。"),
});

export const webSearchStatsTool = {
  name: 'update_web_search_stats',
  description: 'Web検索の結果に基づいて統計ファイルを更新します。このツールは、組み込みのWeb検索ツールを使用した後に呼び出す必要があります。',
  input_schema: webSearchStatsInputSchema,
  execute: async (args: z.infer<typeof webSearchStatsInputSchema>) => {
    try {
      await fs.ensureDir(STATS_DIR);

      if (args.status === 'success') {
        await fs.ensureFile(LAST_SEARCH_FILE);
        // If a search is successful, any previous quota exceeded state is now invalid.
        if (await fs.pathExists(QUOTA_EXCEEDED_FILE)) {
          await fs.remove(QUOTA_EXCEEDED_FILE);
        }
        return { content: [{ type: 'text' as const, text: '成功: Web検索の最終実行時刻を更新しました。' }] };
      } else if (args.status === 'quota_exceeded') {
        await fs.ensureFile(QUOTA_EXCEEDED_FILE);
        return { content: [{ type: 'text' as const, text: '成功: Web検索のクォータ制限状態を記録しました。' }] };
      }
      // This path should not be reachable due to the enum validation
      return { content: [{ type: 'text' as const, text: 'エラー: 不明なステータスが指定されました。' }] };
    } catch (error) {
      return {
        content: [{ type: 'text' as const, text: `エラー: Web検索統計の更新に失敗しました。理由: ${error instanceof Error ? error.message : String(error)}` }],
      };
    }
  },
} as const;