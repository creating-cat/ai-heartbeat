/**
 * Get Latest Activity Log Tool
 * Retrieves the content of the latest activity log file from a specific theme directory.
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';

// Zod schema for get latest activity log input
export const getLatestActivityLogInputSchema = z.object({
  themeStartId: z.string()
    .regex(/^\d{14}$/, 'THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .describe('テーマ開始時のハートビートID'),
  themeDirectoryPart: z.string()
    .describe('テーマディレクトリ名の一部。THEME_START_IDと組み合わせて "{THEME_START_ID}_{themeDirectoryPart}" の形式でテーマディレクトリが特定されます'),
  includeSequenced: z.boolean()
    .optional()
    .default(true)
    .describe('連番付きファイル（_01, _02等）も検索対象に含めるか。デフォルトはtrue'),
});

// Helper function to parse heartbeat ID from filename
function parseHeartbeatIdFromFilename(filename: string): { heartbeatId: string; sequence: number | null } | null {
  // Remove .md extension
  const nameWithoutExt = filename.replace(/\.md$/, '');
  
  // Check for sequenced format: YYYYMMDDHHMMSS_NN
  const sequencedMatch = nameWithoutExt.match(/^(\d{14})_(\d{2})$/);
  if (sequencedMatch) {
    return {
      heartbeatId: sequencedMatch[1],
      sequence: parseInt(sequencedMatch[2], 10)
    };
  }
  
  // Check for basic format: YYYYMMDDHHMMSS
  const basicMatch = nameWithoutExt.match(/^(\d{14})$/);
  if (basicMatch) {
    return {
      heartbeatId: basicMatch[1],
      sequence: null
    };
  }
  
  return null;
}

// Helper function to compare activity log files for sorting (latest first)
function compareActivityLogFiles(a: string, b: string): number {
  const parsedA = parseHeartbeatIdFromFilename(a);
  const parsedB = parseHeartbeatIdFromFilename(b);
  
  if (!parsedA || !parsedB) {
    return 0; // Should not happen with filtered files
  }
  
  // First compare by heartbeat ID (timestamp) - descending
  const heartbeatComparison = parsedB.heartbeatId.localeCompare(parsedA.heartbeatId);
  if (heartbeatComparison !== 0) {
    return heartbeatComparison;
  }
  
  // If heartbeat IDs are the same, compare by sequence - descending (higher sequence = more recent)
  const seqA = parsedA.sequence ?? 0;
  const seqB = parsedB.sequence ?? 0;
  return seqB - seqA;
}

export const getLatestActivityLogTool = {
  name: 'get_latest_activity_log',
  description: '指定されたテーマディレクトリ内の最新の活動ログファイルの内容を取得します。過去の活動を振り返る際や、継続的な思考を行う際に有用です。',
  input_schema: getLatestActivityLogInputSchema,
  execute: async (args: z.infer<typeof getLatestActivityLogInputSchema>) => {
    try {
      const { themeStartId, themeDirectoryPart, includeSequenced } = args;
      
      // Sanitize directory part to prevent directory traversal
      const sanitizedDirectoryPart = path.basename(themeDirectoryPart);
      
      // Build theme directory path
      const fullThemeDirectoryName = `${themeStartId}_${sanitizedDirectoryPart}`;
      const themeDirectoryPath = path.join('artifacts', fullThemeDirectoryName);
      const historiesDirectoryPath = path.join(themeDirectoryPath, 'histories');
      
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
      
      // Check if histories directory exists
      if (!await fs.pathExists(historiesDirectoryPath)) {
        return {
          content: [
            {
              type: 'text' as const,
              text: `情報: 活動ログディレクトリが存在しません: ${historiesDirectoryPath}\nまだ活動ログが作成されていない可能性があります。`,
            },
          ],
        };
      }
      
      // Read all files in histories directory
      const allFiles = await fs.readdir(historiesDirectoryPath);
      
      // Filter for activity log files
      let activityLogFiles = allFiles.filter(file => {
        if (!file.endsWith('.md')) return false;
        
        const parsed = parseHeartbeatIdFromFilename(file);
        if (!parsed) return false;
        
        // If includeSequenced is false, exclude sequenced files
        if (!includeSequenced && parsed.sequence !== null) {
          return false;
        }
        
        return true;
      });
      
      if (activityLogFiles.length === 0) {
        const message = includeSequenced 
          ? `情報: ${historiesDirectoryPath} に活動ログファイルが見つかりませんでした。`
          : `情報: ${historiesDirectoryPath} に基本形式の活動ログファイルが見つかりませんでした。（連番付きファイルは除外されています）`;
        
        return {
          content: [
            {
              type: 'text' as const,
              text: message,
            },
          ],
        };
      }
      
      // Sort files to get the latest one
      activityLogFiles.sort(compareActivityLogFiles);
      const latestFile = activityLogFiles[0];
      const latestFilePath = path.join(historiesDirectoryPath, latestFile);
      
      // Read the content of the latest file
      const content = await fs.readFile(latestFilePath, 'utf-8');
      
      // Parse file info for response
      const parsed = parseHeartbeatIdFromFilename(latestFile);
      const sequenceInfo = parsed && parsed.sequence !== null ? ` (連番: ${parsed.sequence.toString().padStart(2, '0')})` : '';
      
      const responseText = `最新の活動ログを取得しました:
📁 テーマ: ${sanitizedDirectoryPart} (${themeStartId})
📄 ファイル: ${latestFile}${sequenceInfo}
📍 パス: ${latestFilePath}
📊 総活動ログ数: ${activityLogFiles.length}件

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