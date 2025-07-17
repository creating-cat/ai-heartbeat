/**
 * Get Latest Activity Log Tool
 * Retrieves the content of the latest activity log file from a specific theme directory.
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';
import { parseActivityLogFileName, FileNameInfo } from '../lib/activityLogParser';

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
  numLogs: z.number()
    .int()
    .min(1)
    .max(10)
    .optional()
    .default(1)
    .describe('取得する最新ログの件数（1-10件、デフォルト: 1）'),
});

// Helper function to compare activity log files for sorting (latest first)
function compareActivityLogFiles(a: string, b: string): number {
  const parsedA = parseActivityLogFileName(a);
  const parsedB = parseActivityLogFileName(b);
  
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
  description: '指定されたテーマディレクトリ内の最新の活動ログファイルの内容を取得します。numLogsパラメータで複数のログを一度に取得可能です。過去の活動を振り返る際や、継続的な思考を行う際に有用です。',
  input_schema: getLatestActivityLogInputSchema,
  execute: async (args: z.infer<typeof getLatestActivityLogInputSchema>) => {
    try {
      const { themeStartId, themeDirectoryPart, includeSequenced, numLogs } = args;
      
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
        
        const parsed = parseActivityLogFileName(file);
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
      
      // Sort files to get the latest ones
      activityLogFiles.sort(compareActivityLogFiles);
      
      // Get the requested number of latest files
      const requestedFiles = activityLogFiles.slice(0, numLogs);
      
      // Read content of all requested files
      const logContents: Array<{ filename: string; content: string; parsed: FileNameInfo | null }> = [];
      
      for (const filename of requestedFiles) {
        const filePath = path.join(historiesDirectoryPath, filename);
        const content = await fs.readFile(filePath, 'utf-8');
        const parsed = parseActivityLogFileName(filename);
        logContents.push({ filename, content, parsed });
      }
      
      // Build response text
      let responseText: string;
      
      if (numLogs === 1) {
        // Single log format (backward compatibility)
        const { filename, content, parsed } = logContents[0];
        const sequenceInfo = parsed && parsed.sequence !== null ? ` (連番: ${parsed.sequence.toString().padStart(2, '0')})` : '';
        
        responseText = `最新の活動ログを取得しました:
📁 テーマ: ${sanitizedDirectoryPart} (${themeStartId})
📄 ファイル: ${filename}${sequenceInfo}
📍 パス: ${path.join(historiesDirectoryPath, filename)}
📊 総活動ログ数: ${activityLogFiles.length}件

---

${content}`;
      } else {
        // Multiple logs format
        responseText = `最新の活動ログ ${numLogs}件を取得しました:
📁 テーマ: ${sanitizedDirectoryPart} (${themeStartId})
📊 取得件数: ${logContents.length}件 / 総件数: ${activityLogFiles.length}件

`;
        
        logContents.forEach((log, index) => {
          const sequenceInfo = log.parsed && log.parsed.sequence !== null ? ` (連番: ${log.parsed.sequence.toString().padStart(2, '0')})` : '';
          const isLatest = index === 0 ? ' (最新)' : '';
          
          responseText += `========================================
📄 ログ ${index + 1}/${logContents.length}: ${log.filename}${sequenceInfo}${isLatest}
========================================

${log.content}

`;
        });
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