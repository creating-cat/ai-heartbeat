/**
 * Get Latest Theme Context Tool
 * Retrieves the content of the latest theme expert context file from a specific theme directory.
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';
import { resolveThemePath, resolveThemeContextsPath } from '../lib/themeUtils';

// Zod schema for get latest theme context input (サブテーマ対応版)
export const getLatestThemeContextInputSchema = z.object({
  themeStartId: z.string()
    .regex(/^\d{14}$/, 'THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .describe('テーマ開始時のハートビートID'),
  themeDirectoryPart: z.string()
    .describe('テーマディレクトリ名の一部。THEME_START_IDと組み合わせて "{THEME_START_ID}_{themeDirectoryPart}" の形式でテーマディレクトリが特定されます'),
  
  // 🆕 サブテーマ対応の新規フィールド
  parentThemeStartId: z.string()
    .regex(/^\d{14}$/, 'PARENT_THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .optional()
    .describe('サブテーマの場合、親テーマのTHEME_START_IDを指定。nullまたは未指定の場合はルートテーマとして扱われます'),
  parentThemeDirectoryPart: z.string()
    .optional()
    .describe('サブテーマの場合、親テーマのディレクトリ部分を指定。parentThemeStartIdが指定された場合は必須'),
});

// Helper function to validate heartbeat ID format
function isValidHeartbeatId(filename: string): boolean {
  const match = filename.match(/^(\d{14})\.md$/);
  return match !== null;
}

// Helper function to extract heartbeat ID from filename
function extractHeartbeatId(filename: string): string | null {
  const match = filename.match(/^(\d{14})\.md$/);
  return match ? match[1] : null;
}

export const getLatestThemeContextTool = {
  name: 'get_latest_theme_context',
  description: '指定されたテーマディレクトリのcontexts/フォルダ内の最新のテーマ専門家コンテキストファイルの内容を取得します。ハートビートID順でソートして最新のコンテキストを特定します。専門家コンテキストの見直しや参照時に有用です。',
  input_schema: getLatestThemeContextInputSchema,
  execute: async (args: z.infer<typeof getLatestThemeContextInputSchema>) => {
    try {
      const { themeStartId, themeDirectoryPart, parentThemeStartId, parentThemeDirectoryPart } = args;
      
      // バリデーション
      if (parentThemeStartId && !parentThemeDirectoryPart) {
        throw new Error('parentThemeStartIdが指定された場合、parentThemeDirectoryPartも必須です');
      }

      if (parentThemeDirectoryPart && !parentThemeStartId) {
        throw new Error('parentThemeDirectoryPartが指定された場合、parentThemeStartIdも必須です');
      }
      
      // Sanitize directory part to prevent directory traversal
      const sanitizedDirectoryPart = path.basename(themeDirectoryPart);
      const sanitizedParentDirectoryPart = parentThemeDirectoryPart ? 
        path.basename(parentThemeDirectoryPart) : undefined;
      
      // Build theme directory path using common utility (サブテーマ対応)
      const themeDirectoryPath = resolveThemePath(
        themeStartId, 
        sanitizedDirectoryPart,
        parentThemeStartId,
        sanitizedParentDirectoryPart
      );
      const contextsDirectoryPath = resolveThemeContextsPath(
        themeStartId, 
        sanitizedDirectoryPart,
        parentThemeStartId,
        sanitizedParentDirectoryPart
      );
      
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
      
      // Check if contexts directory exists
      if (!await fs.pathExists(contextsDirectoryPath)) {
        return {
          content: [
            {
              type: 'text' as const,
              text: `情報: コンテキストディレクトリが存在しません: ${contextsDirectoryPath}\nまだテーマ専門家コンテキストが作成されていない可能性があります。`,
            },
          ],
        };
      }
      
      // Read all files in contexts directory
      const allFiles = await fs.readdir(contextsDirectoryPath);
      
      // Filter for valid context files (heartbeat_id.md format)
      const contextFiles = allFiles.filter(file => {
        if (!file.endsWith('.md')) return false;
        return isValidHeartbeatId(file);
      });
      
      if (contextFiles.length === 0) {
        return {
          content: [
            {
              type: 'text' as const,
              text: `情報: ${contextsDirectoryPath} にコンテキストファイルが見つかりませんでした。`,
            },
          ],
        };
      }
      
      // Sort files by heartbeat ID (descending - latest first)
      contextFiles.sort((a, b) => {
        const heartbeatA = extractHeartbeatId(a);
        const heartbeatB = extractHeartbeatId(b);
        if (!heartbeatA || !heartbeatB) return 0;
        return heartbeatB.localeCompare(heartbeatA);
      });
      
      // Get the latest file
      const latestFile = contextFiles[0];
      const latestHeartbeatId = extractHeartbeatId(latestFile);
      const latestFilePath = path.join(contextsDirectoryPath, latestFile);
      
      // Read content of the latest file
      const content = await fs.readFile(latestFilePath, 'utf-8');
      
      // Build response text
      const responseText = `パス: ${latestFilePath}

---

${content}`;
      
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