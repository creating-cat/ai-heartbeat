/**
 * List Theme Artifacts Tool
 * Lists all artifact files in a specific theme directory
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';

// Zod schema for list theme artifacts input
export const listThemeArtifactsInputSchema = z.object({
  themeStartId: z.string()
    .regex(/^\d{14}$/, 'THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .describe('テーマ開始時のハートビートID'),
  themeDirectoryPart: z.string()
    .describe('テーマディレクトリ名の一部。THEME_START_IDと組み合わせて "{THEME_START_ID}_{themeDirectoryPart}" の形式でテーマディレクトリが特定されます'),
  includeSubdirectories: z.boolean()
    .optional()
    .default(true)
    .describe('サブディレクトリも含めるか（デフォルト: true）'),
});

/**
 * Recursively get all files in a directory
 */
async function getAllFiles(dirPath: string, includeSubdirectories: boolean): Promise<string[]> {
  const files: string[] = [];
  
  if (!await fs.pathExists(dirPath)) {
    return files;
  }
  
  const items = await fs.readdir(dirPath);
  
  for (const item of items) {
    const itemPath = path.join(dirPath, item);
    const stats = await fs.stat(itemPath);
    
    if (stats.isFile()) {
      files.push(itemPath);
    } else if (stats.isDirectory() && includeSubdirectories) {
      // Recursively get files from subdirectories
      const subFiles = await getAllFiles(itemPath, includeSubdirectories);
      files.push(...subFiles);
    }
  }
  
  return files;
}

/**
 * Filter out system/hidden files and directories
 */
function shouldIncludeFile(filePath: string): boolean {
  const basename = path.basename(filePath);
  
  // Exclude hidden files (starting with .)
  if (basename.startsWith('.')) {
    return false;
  }
  
  // Exclude common system/temp files
  const excludePatterns = [
    /^Thumbs\.db$/i,
    /^\.DS_Store$/i,
    /^desktop\.ini$/i,
    /\.tmp$/i,
    /\.temp$/i,
    /~$/,
  ];
  
  for (const pattern of excludePatterns) {
    if (pattern.test(basename)) {
      return false;
    }
  }
  
  return true;
}

export const listThemeArtifactsTool = {
  name: 'list_theme_artifacts',
  description: '指定されたテーマディレクトリ内の成果物ファイルの一覧を取得します。プロジェクトルートからの絶対パスで表示され、名前順（時系列順）でソートされます。',
  input_schema: listThemeArtifactsInputSchema,
  execute: async (args: z.infer<typeof listThemeArtifactsInputSchema>) => {
    try {
      const { themeStartId, themeDirectoryPart, includeSubdirectories } = args;
      
      // Sanitize directory part to prevent directory traversal
      const sanitizedDirectoryPart = path.basename(themeDirectoryPart);
      
      // Build theme directory path
      const themeDirectoryName = `${themeStartId}_${sanitizedDirectoryPart}`;
      const themeDirectoryPath = path.join('artifacts', themeDirectoryName);
      
      // Check if theme directory exists
      if (!await fs.pathExists(themeDirectoryPath)) {
        return {
          content: [
            {
              type: 'text' as const,
              text: `エラー: テーマディレクトリが存在しません: ${themeDirectoryPath}`,
            },
          ],
        };
      }
      
      // Get all files in the theme directory
      const allFiles = await getAllFiles(themeDirectoryPath, includeSubdirectories);
      
      // Filter out system/hidden files and the histories directory
      const artifactFiles = allFiles.filter(filePath => {
        // Exclude the histories directory (not an artifact)
        if (filePath.includes(path.join(themeDirectoryPath, 'histories'))) {
          return false;
        }
        
        // Apply general file filtering
        return shouldIncludeFile(filePath);
      });
      
      // Sort files by name (which equals chronological order due to heartbeat IDs)
      artifactFiles.sort();
      
      // Convert to relative paths from project root
      const projectRoot = process.cwd();
      const relativeFiles = artifactFiles.map(filePath => {
        return path.relative(projectRoot, filePath);
      });
      
      // Generate response
      if (relativeFiles.length === 0) {
        return {
          content: [
            {
              type: 'text' as const,
              text: `テーマディレクトリに成果物ファイルが見つかりませんでした: ${themeDirectoryPath}`,
            },
          ],
        };
      }
      
      // Simple list format - just the file paths
      const responseText = relativeFiles.join('\n');
      
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