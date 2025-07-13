/**
 * Item Processor Tool
 * Checks for and processes items from themebox or feedbackbox.
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';

// Zod schema for the tool input
export const itemProcessorInputSchema = z.object({
  type: z.enum(['themebox', 'feedbackbox']).describe('The type of box to check: themebox or feedbackbox'),
});

// The tool definition
export const itemProcessorTool = {
  name: 'check_and_process_item',
  description: 'Checks for and processes the first available item in the specified box (themebox or feedbackbox).',
  input_schema: itemProcessorInputSchema,
  execute: async (args: z.infer<typeof itemProcessorInputSchema>) => {
    const { type } = args;
    const directoryPath = type; // Assumes execution from project root

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