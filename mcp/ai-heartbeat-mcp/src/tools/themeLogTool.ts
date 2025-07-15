/**
 * Theme Log Creation Tool
 */

import * as fs from 'fs-extra';
import * as path from 'path';
import { z } from 'zod';
import { checkTimeDeviation } from '../lib/timeUtils';

// Zod schema for theme log input
export const themeLogInputSchema = z.object({
  action: z.enum(['start', 'end']).describe("テーマに対する操作種別。'start'または'end'のいずれかを指定します。"),
  themeStartId: z.string()
    .regex(/^\d{14}$/, 'THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .describe('テーマ開始時のハートビートID。テーマ開始・終了両方で必須'),
  themeEndId: z.string()
    .regex(/^\d{14}$/, 'THEME_END_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .optional()
    .describe('テーマ終了時のハートビートID。actionが"end"の場合のみ必須'),
  themeName: z.string().describe('テーマの正式名称。'),
  themeDirectoryPart: z.string()
    .describe('テーマディレクトリ名の一部。THEME_START_IDと組み合わせて "{THEME_START_ID}_{themeDirectoryPart}" の形式でテーマディレクトリが作成されます（例: themeDirectoryPart="ai_research" → ディレクトリ="20250115143000_ai_research"）。半角英小文字、数字、アンダースコアのみ推奨'),
  reason: z.string().describe('テーマを開始または終了する理由。'),
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
        action,
        themeStartId,
        themeEndId,
        themeName,
        themeDirectoryPart,
        reason,
        achievements,
        activityContent,
      } = args;

      // バリデーション
      if (action === 'end' && !themeEndId) {
        throw new Error('テーマ終了時はthemeEndIdパラメータが必須です');
      }

      // ディレクトリトラバーサルを防ぐためにbasenameを使用
      const baseThemeDirectoryPart = path.basename(themeDirectoryPart);

      // themeDirectoryPartをサニタイズし、AIにフィードバックできるように変更を追跡
      const sanitizedDirectoryPart = baseThemeDirectoryPart
        .toLowerCase()
        .replace(/[^a-z0-9_]+/g, '_')
        .replace(/_+/g, '_');
      const isSanitized = sanitizedDirectoryPart !== themeDirectoryPart;

      // ディレクトリ名の生成（統一ルール）
      const fullThemeDirectoryName = `${themeStartId}_${sanitizedDirectoryPart}`;
      const themeDirectoryPath = path.join('artifacts', fullThemeDirectoryName);

      // ファイル名の生成（IDに基づく）
      const logFileId = action === 'start' ? themeStartId : themeEndId;
      const logFileName = `${logFileId}_${action}_${sanitizedDirectoryPart}.md`;
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

      // テーマ開始時: ディレクトリ構造の確保
      if (action === 'start') {
        // ディレクトリが既に存在する場合（専門家コンテキスト作成済み）
        if (await fs.pathExists(themeDirectoryPath)) {
          console.log(`既存のテーマディレクトリを使用: ${themeDirectoryPath}`);
        } else {
          // 新規作成
          await fs.ensureDir(themeDirectoryPath);
        }
        
        // historiesディレクトリは常に確保
        await fs.ensureDir(path.join(themeDirectoryPath, 'histories'));
      } else {
        // テーマ終了時: ディレクトリ存在確認
        if (!await fs.pathExists(themeDirectoryPath)) {
          // 警告は出すが、処理は継続（履歴記録は重要）
          console.warn(`警告: テーマディレクトリが見つかりません: ${themeDirectoryPath}`);
        }
      }

      // マークダウン内容の生成
      let markdownContent = '';
      if (action === 'start') {
        const activityList = formatList(activityContent, '(このテーマで何を行うか)');
        markdownContent = `# テーマ開始: ${themeName}

**THEME_START_ID**: ${themeStartId}
**テーマディレクトリ**: \`${themeDirectoryPath}/\`

**開始理由**:
${reason || 'N/A'}

**活動内容**:
${activityList}
`;
      } else {
        const achievementList = formatList(achievements, 'N/A');
        markdownContent = `# テーマ終了: ${themeName}

**THEME_START_ID**: ${themeStartId}
**THEME_END_ID**: ${themeEndId}
**テーマディレクトリ**: \`${themeDirectoryPath}/\`

**終了理由**:
${reason || 'N/A'}

**主な成果**:
${achievementList}
`;
      }

      // 時刻乖離チェック
      const timeWarning = await checkTimeDeviation(logFileId!);

      // ファイル書き込み
      await fs.ensureDir(path.dirname(logFilePath));
      await fs.writeFile(logFilePath, markdownContent, 'utf-8');

      // 応答メッセージ作成
      let responseText = `テーマ履歴ファイルを作成しました: ${logFilePath}`;
      if (action === 'start') {
        responseText += `\n📁 テーマディレクトリ: ${themeDirectoryPath}`;
        responseText += `\n🆔 THEME_START_ID: ${themeStartId}`;
      } else {
        responseText += `\n🏁 テーマ終了: ${themeStartId} → ${themeEndId}`;
      }
      
      if (timeWarning) {
        responseText += `\n${timeWarning}`;
      }
      
      // サニタイズ警告
      if (isSanitized) {
        responseText += `\n⚠️ ディレクトリ名を「${themeDirectoryPart}」から「${sanitizedDirectoryPart}」に修正しました`;
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