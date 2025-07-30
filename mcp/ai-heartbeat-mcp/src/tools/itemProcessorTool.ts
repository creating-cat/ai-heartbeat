/**
 * Item Processor Tool
 * Checks for and processes items from feedbackbox.
 * Note: themebox functionality has been replaced by preview_next_theme and start_theme tools.
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';
import { FEEDBACKBOX_DIR } from '../lib/pathConstants';

// Zod schema for the tool input (feedbackbox only)
export const itemProcessorInputSchema = z.object({
  type: z.literal('feedbackbox').describe("チェックするボックスの種類。現在は'feedbackbox'のみサポートしています。"),
});

// The tool definition
export const itemProcessorTool = {
  name: 'check_and_process_item',
  description: 'feedbackboxで利用可能な最初のアイテムを確認し、処理します。注意: themebox機能は preview_next_theme と start_theme ツールに置き換えられました。',
  input_schema: itemProcessorInputSchema,
  execute: async (args: z.infer<typeof itemProcessorInputSchema>) => {
    const { type } = args;
    
    if (type !== 'feedbackbox') {
      return {
        content: [{ 
          type: 'text' as const, 
          text: 'エラー: このツールは現在feedbackboxのみをサポートしています。themebox機能は preview_next_theme と start_theme ツールを使用してください。' 
        }],
      };
    }

    const directoryPath = FEEDBACKBOX_DIR;

    try {
      // 1. Ensure directory exists
      if (!(await fs.pathExists(directoryPath))) {
        await fs.ensureDir(directoryPath);
        return {
          content: [{ type: 'text' as const, text: `情報: ${type}ディレクトリが存在しなかったため作成しました。処理対象のアイテムはありません。` }],
        };
      }

      // 2. Read and filter files
      const allFiles = await fs.readdir(directoryPath);
      const processableFiles = allFiles
        .filter(file => !file.startsWith('draft.') && !file.startsWith('processed.') && file.endsWith('.md'))
        .sort(); // Sort to process in a predictable order (e.g., 001, 002...)

      const processableFileCount = processableFiles.length;

      if (processableFileCount === 0) {
        return { content: [{ type: 'text' as const, text: `情報: ${type}に新しいアイテムは見つかりませんでした。` }] };
      }

      // Process the first file
      const fileToProcess = processableFiles[0];
      const originalPath = path.join(directoryPath, fileToProcess);
      const newPath = path.join(directoryPath, `processed.${fileToProcess}`);
      const content = await fs.readFile(originalPath, 'utf-8');
      await fs.rename(originalPath, newPath);

      const remainingCount = processableFileCount - 1;
      let responseText = `成功: ${type}のアイテムを処理しました。\n元のパス: ${type}/${fileToProcess}\n内容:\n---\n${content}\n---`;
      if (remainingCount > 0) {
        responseText += `\n\n情報: ${type}には、さらに${remainingCount}件の未処理アイテムがあります。`;
      }

      return { content: [{ type: 'text' as const, text: responseText }] };
    } catch (error) {
      return { content: [{ type: 'text' as const, text: `エラー: ${type}のアイテム処理に失敗しました。理由: ${error instanceof Error ? error.message : String(error)}` }] };
    }
  },
} as const;