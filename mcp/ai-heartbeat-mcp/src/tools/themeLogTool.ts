/**
 * Theme Log Creation Tool
 */

import * as fs from 'fs-extra';
import * as path from 'path';
import { z } from 'zod';
import { checkTimeDeviation } from '../lib/timeUtils';

// Zod schema for theme log input
export const themeLogInputSchema = z.object({
  heartbeatId: z.string().regex(/^\d{14}$/, 'ハートビートIDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります').describe('YYYYMMDDHHMMSS形式のハートビートID。注意: 1つのハートビートで複数のテーマ操作（開始/終了）はルール違反であり、IDが重複した場合はエラーとなります。また、このツールは時刻乖離警告を出力する可能性があります。'),
  action: z.enum(['start', 'end']).describe("テーマに対する操作種別。'start'または'end'のいずれかを指定します。"),
  themeName: z.string().describe('テーマの正式名称。'),
  themeDirectoryName: z.string().describe('テーマのディレクトリ名。注意: このツールは安全のため、指定された名前を自動的にサニタイズします（例:「AIの研究」->「ai__」）。半角英小文字、数字、アンダースコアのみを使用してください。'),
  reason: z.string().optional().describe('テーマを開始または終了する理由。'),
  achievements: z.array(z.string()).optional().describe("テーマ終了時に記録する主な成果のリスト。actionが'end'の場合に使用します。"),
  activityContent: z.array(z.string()).optional().describe("テーマ開始時に記録する初期活動計画のリスト。actionが'start'の場合に使用します。"),
});

function formatList(items: string[] | undefined, emptyPlaceholder: string): string {
  if (!items || items.length === 0) {
    return emptyPlaceholder;
  }
  if (items.length === 1) {
    return items[0];
  }
  return items.map(item => `- ${item}`).join('\n');
}

export const themeLogTool = {
  name: 'create_theme_log',
  description: 'Create theme history log for AI Heartbeat System',
  input_schema: themeLogInputSchema,
  execute: async (args: z.infer<typeof themeLogInputSchema>) => {
    try {
      const {
        heartbeatId,
        action,
        themeName,
        reason,
        achievements,
      } = args;

      // ディレクトリトラバーサルを防ぐためにbasenameを使用
      const baseThemeDirectoryName = path.basename(args.themeDirectoryName);

      // themeDirectoryNameをサニタイズし、AIにフィードバックできるように変更を追跡
      const sanitizedThemeDirectoryName = baseThemeDirectoryName
        .toLowerCase()
        .replace(/[^a-z0-9_]+/g, '_')
        .replace(/_+/g, '_');
      const isSanitized = sanitizedThemeDirectoryName !== args.themeDirectoryName;

      // ファイルパスを生成
      const logFileName = `${heartbeatId}_${action}_${sanitizedThemeDirectoryName}.md`;
      const logFilePath = path.join(
        'artifacts',
        'theme_histories',
        logFileName
      );

      // 重複チェック (heartbeat.shの異常検知を避けるため)
      if (await fs.pathExists(logFilePath)) {
        throw new Error(
          `テーマ履歴ファイルは既に存在します: ${logFilePath}。ハートビートIDが重複していないか確認してください。`
        );
      }

      // ハートビートIDの重複チェック（エラー処理）
      const themeHistoriesDir = path.dirname(logFilePath);
      if (await fs.pathExists(themeHistoriesDir)) {
          const files = await fs.readdir(themeHistoriesDir);
          const duplicates = files.filter(file => file.startsWith(`${heartbeatId}_`));
          if (duplicates.length >= 1) {
              throw new Error(
                  `🚨 ルール違反: 同じハートビートID (${heartbeatId}) を持つテーマ履歴ファイルが既に存在します（${duplicates.join(', ')}）。1つのハートビートで複数のテーマ操作（開始/終了）はできません。`
              );
          }
      }

      // ファイル内容を生成
      const themeDirectoryPath = path.join('artifacts', sanitizedThemeDirectoryName);
      let markdownContent = '';
      if (action === 'start') {
        const activityList = formatList(args.activityContent, '(このテーマで何を行うか)');
        markdownContent = `# テーマ開始: ${themeName}\n\n**テーマディレクトリ**: \`${themeDirectoryPath}/\`\n\n**開始理由**:\n${
          reason || 'N/A'
        }\n\n**活動内容**:\n${activityList}\n`;
      } else {
        const achievementList = formatList(args.achievements, 'N/A');
        markdownContent = `# テーマ終了: ${themeName}\n\n**テーマディレクトリ**: \`${themeDirectoryPath}/\`\n\n**終了理由**:\n${
          reason || 'N/A'
        }\n\n**主な成果**:\n${achievementList}\n`;
      }

      // 時刻乖離チェック
      const timeWarning = await checkTimeDeviation(heartbeatId);

      // ファイル書き込み
      await fs.ensureDir(path.dirname(logFilePath));
      await fs.writeFile(logFilePath, markdownContent, 'utf-8');

      // 応答メッセージ作成
      let responseText = `テーマ履歴ファイルを作成しました: ${logFilePath}`;
      if (timeWarning) {
        responseText += `\n${timeWarning}`;
      }
      if (isSanitized) {
        responseText += `\n⚠️ 注意: 指定されたディレクトリ名「${args.themeDirectoryName}」は命名規則に合わない、または安全でない可能性があるため、「${sanitizedThemeDirectoryName}」に修正しました。今後は半角英小文字、数字、アンダースコアのみを使用してください。`;
      }

      return { content: [{ type: 'text' as const, text: responseText }] };
    } catch (error) {
      return {
        content: [
          { type: 'text' as const, text: `エラーが発生しました: ${error instanceof Error ? error.message : String(error)}` },
        ],
      };
    }
  },
} as const;