/**
 * Preview Next Theme Tool
 * Safely previews the next theme candidate from themebox without changing any state.
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';
import { THEMEBOX_DIR } from '../lib/pathConstants';

// Zod schema for the tool input (no parameters needed)
export const previewNextThemeInputSchema = z.object({});

// The tool definition
export const previewNextThemeTool = {
  name: 'preview_next_theme',
  description: 'themeboxにある次に処理すべきテーマ候補の内容を、状態を一切変更せずに確認します。何度呼び出してもシステムの状態が変わらない安全な読み取り専用ツールです。',
  input_schema: previewNextThemeInputSchema,
  execute: async (args: z.infer<typeof previewNextThemeInputSchema>) => {
    try {
      // 1. Ensure directory exists
      if (!(await fs.pathExists(THEMEBOX_DIR))) {
        return {
          content: [{ 
            type: 'text' as const, 
            text: '情報: themeboxディレクトリが存在しません。処理対象のテーマ候補はありません。' 
          }],
        };
      }

      // 2. Read and filter files
      const allFiles = await fs.readdir(THEMEBOX_DIR);
      const processableFiles = allFiles
        .filter(file => !file.startsWith('draft.') && !file.startsWith('processed.') && file.endsWith('.md'))
        .sort(); // Sort to get the oldest file first

      if (processableFiles.length === 0) {
        return { 
          content: [{ 
            type: 'text' as const, 
            text: '情報: themeboxに新しいテーマ候補は見つかりませんでした。' 
          }] 
        };
      }

      // 3. Read the first file content without modifying anything
      const nextThemeFile = processableFiles[0];
      const filePath = path.join(THEMEBOX_DIR, nextThemeFile);
      const content = await fs.readFile(filePath, 'utf-8');

      const remainingCount = processableFiles.length - 1;
      let responseText = `次のテーマ候補を確認しました:\n\n**ファイル名**: ${nextThemeFile}\n\n**内容**:\n---\n${content}\n---`;
      
      if (remainingCount > 0) {
        responseText += `\n\n情報: themeboxには、さらに${remainingCount}件のテーマ候補があります。`;
      }

      responseText += `\n\n注意: この操作では何も変更されていません。テーマを開始する場合は start_theme ツールを使用してください。`;

      return { 
        content: [{ 
          type: 'text' as const, 
          text: responseText 
        }] 
      };
    } catch (error) {
      return { 
        content: [{ 
          type: 'text' as const, 
          text: `エラー: テーマ候補の確認に失敗しました。理由: ${error instanceof Error ? error.message : String(error)}` 
        }] 
      };
    }
  },
} as const;