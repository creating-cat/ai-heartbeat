/**
 * Theme Log Creation Tool
 */

import * as fs from 'fs-extra';
import * as path from 'path';
import { z } from 'zod';
import { glob } from 'glob';
import { resolveThemePath } from '../lib/themeUtils';
import { THEME_HISTORIES_DIR } from '../lib/pathConstants';

// Zod schema for theme log input (サブテーマ対応版)
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

  // 🆕 サブテーマ対応の新規フィールド
  parentThemeStartId: z.string()
    .regex(/^\d{14}$/, 'PARENT_THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .optional()
    .describe('サブテーマの場合、親テーマのTHEME_START_IDを指定。nullまたは未指定の場合はルートテーマとして扱われます'),
  parentThemeDirectoryPart: z.string()
    .optional()
    .describe('サブテーマの場合、親テーマのディレクトリ部分を指定。parentThemeStartIdが指定された場合は必須'),
});



// テーマタイプ判定
function getThemeType(parentThemeStartId?: string): string {
  return parentThemeStartId ? 'サブテーマ' : 'テーマ';
}

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
  description: 'AIハートビートシステム用のテーマ履歴ログを作成します。サブテーマにも対応しており、parentThemeStartIdを指定することでサブテーマとして作成されます。',
  input_schema: themeLogInputSchema,
  execute: async (args: z.infer<typeof themeLogInputSchema>) => {
    try {
      // 一時ファイルパスを先に定義
      let tmpLogFilePath: string | null = null;

      const {
        action,
        themeStartId,
        themeEndId,
        themeName,
        themeDirectoryPart,
        reason,
        achievements,
        activityContent,
        parentThemeStartId,
        parentThemeDirectoryPart,
      } = args;

      // バリデーション
      if (action === 'end' && !themeEndId) {
        throw new Error('テーマ終了時はthemeEndIdパラメータが必須です');
      }

      if (parentThemeStartId && !parentThemeDirectoryPart) {
        throw new Error('parentThemeStartIdが指定された場合、parentThemeDirectoryPartも必須です');
      }

      if (parentThemeDirectoryPart && !parentThemeStartId) {
        throw new Error('parentThemeDirectoryPartが指定された場合、parentThemeStartIdも必須です');
      }

      // ディレクトリトラバーサルを防ぐためにbasenameを使用
      const baseThemeDirectoryPart = path.basename(themeDirectoryPart);
      const baseParentThemeDirectoryPart = parentThemeDirectoryPart ? path.basename(parentThemeDirectoryPart) : undefined;

      // themeDirectoryPartをサニタイズし、AIにフィードバックできるように変更を追跡
      const sanitizedDirectoryPart = baseThemeDirectoryPart
        .toLowerCase()
        .replace(/[^a-z0-9_]+/g, '_')
        .replace(/_+/g, '_');
      const sanitizedParentDirectoryPart = baseParentThemeDirectoryPart
        ?.toLowerCase()
        .replace(/[^a-z0-9_]+/g, '_')
        .replace(/_+/g, '_');

      const isSanitized = sanitizedDirectoryPart !== themeDirectoryPart;
      const isParentSanitized = baseParentThemeDirectoryPart && sanitizedParentDirectoryPart !== parentThemeDirectoryPart;

      // テーマタイプの判定
      const themeType = getThemeType(parentThemeStartId);
      const isSubtheme = !!parentThemeStartId;

      // テーマディレクトリパスを解決
      const themeDirectoryPath = resolveThemePath(
        themeStartId,
        sanitizedDirectoryPart,
        parentThemeStartId,
        sanitizedParentDirectoryPart
      );

      // ファイル名の生成（IDに基づく）
      const logFileId = action === 'start' ? themeStartId : themeEndId;
      const logFileName = `${logFileId}_${action}_${sanitizedDirectoryPart}.md`;
      const logFilePath = path.join(
        THEME_HISTORIES_DIR,
        logFileName
      );

      // ハートビートID重複チェック（全テーマ履歴ファイルを検索）
      const themeHistoryPattern = path.join(THEME_HISTORIES_DIR, `${logFileId}_*.md`);
      const existingThemeHistories = await glob(themeHistoryPattern);

      if (existingThemeHistories.length > 0) {
        const existingFile = path.basename(existingThemeHistories[0]);
        const warningMessage =
          `警告: このハートビートでは既にテーマ操作が実行されています（${existingFile}）。ルール違反になるため、この操作は実行されませんでした。\n` +
          `解決方法: 次のハートビートを待ってからテーマ操作を実行してください。`;
        return {
          content: [{ type: 'text' as const, text: warningMessage }],
        };
      }

      // マークダウン内容の生成
      let markdownContent = '';
      const actionType = action === 'start' ? '開始' : '終了';
      const title = `${themeType}${actionType}: ${themeName}`;

      if (action === 'start') {
        const activityList = formatList(activityContent, '(このテーマで何を行うか)');
        markdownContent = `# ${title}

${isSubtheme ? `**PARENT_THEME_START_ID**: ${parentThemeStartId}
**PARENT_THEME_DIRECTORY**: ${parentThemeStartId}_${sanitizedParentDirectoryPart}
` : ''}**THEME_START_ID**: ${themeStartId}
**テーマディレクトリ**: \`${themeDirectoryPath}/\`

**開始理由**:
${reason || 'N/A'}

**活動内容**:
${activityList}
`;
      } else {
        const achievementList = formatList(achievements, 'N/A');
        markdownContent = `# ${title}

${isSubtheme ? `**PARENT_THEME_START_ID**: ${parentThemeStartId}
**PARENT_THEME_DIRECTORY**: ${parentThemeStartId}_${sanitizedParentDirectoryPart}
` : ''}**THEME_START_ID**: ${themeStartId}
**THEME_END_ID**: ${themeEndId}
**テーマディレクトリ**: \`${themeDirectoryPath}/\`

**終了理由**:
${reason || 'N/A'}

**主な成果**:
${achievementList}
`;
      }

      // --- 堅牢なファイル操作 ---
      // 1. 一時ファイルに書き込み
      tmpLogFilePath = `${logFilePath}.tmp`;
      await fs.ensureDir(path.dirname(tmpLogFilePath)); // 一時ファイル用のディレクトリも確保
      await fs.writeFile(tmpLogFilePath, markdownContent, 'utf-8');

      // 2. ディレクトリ構造の確保（ファイル書き込み成功後）
      if (action === 'start') {
        if (isSubtheme) {
          const parentPath = resolveThemePath(parentThemeStartId!, sanitizedParentDirectoryPart!);
          if (!await fs.pathExists(parentPath)) {
            throw new Error(`親テーマディレクトリが存在しません: ${parentPath}`);
          }
        }
        // ディレクトリが既に存在する場合でもensureDirは問題ない
        await fs.ensureDir(themeDirectoryPath);
        await fs.ensureDir(path.join(themeDirectoryPath, 'histories'));
      } else { // action === 'end'
        if (!await fs.pathExists(themeDirectoryPath)) {
          console.warn(`警告: テーマディレクトリが見つかりません: ${themeDirectoryPath}`);
        }
      }

      // 3. 最終的なファイルパスの重複を再度チェック（リネーム直前）
      if (await fs.pathExists(logFilePath)) {
        throw new Error(
          `テーマ履歴ファイルは既に存在します: ${logFilePath}。競合が発生した可能性があります。`
        );
      }

      // 4. 一時ファイルを本番パスにリネーム（アトミック操作）
      await fs.rename(tmpLogFilePath, logFilePath);
      tmpLogFilePath = null; // 成功したのでクリーンアップ対象から外す

      /* 従来のファイル書き込み処理は削除
      await fs.ensureDir(path.dirname(logFilePath));
      await fs.writeFile(logFilePath, markdownContent, 'utf-8');
      */

      // 応答メッセージ作成
      let responseText = `${themeType}履歴ファイルを作成しました: ${logFilePath}`;
      if (action === 'start') {
        responseText += `\n${themeType}ディレクトリ: ${themeDirectoryPath}`;
        responseText += `\nTHEME_START_ID: ${themeStartId}`;
        if (isSubtheme) {
          responseText += `\nPARENT_THEME_START_ID: ${parentThemeStartId}`;
        }
      } else {
        responseText += `\n${themeType}終了: ${themeStartId} → ${themeEndId}`;
        if (isSubtheme) {
          responseText += `\n親テーマに戻ります: ${parentThemeStartId}_${sanitizedParentDirectoryPart}`;
        }

        // テーマ終了時のリセット指示（より具体的に）
        responseText += `\n\nテーマが正常に完了しました。`;
        responseText += `\nこの後、テーマ終了活動の活動ログを作成してこのタスクを完了してください。`;
        responseText += `\n活動が完了すると、思考コンテキストがリセットされ、次のテーマに備えるためのクールダウン期間に入ります。`;
        responseText += `\n\n重要: 新しいテーマの開始は、次のハートビートまで待機してください。`;
      }

      // サニタイズ警告
      if (isSanitized) {
        responseText += `\n警告: ディレクトリ名を「${themeDirectoryPart}」から「${sanitizedDirectoryPart}」に修正しました`;
      }
      if (isParentSanitized) {
        responseText += `\n警告: 親ディレクトリ名を「${parentThemeDirectoryPart}」から「${sanitizedParentDirectoryPart}」に修正しました`;
      }

      return { content: [{ type: 'text' as const, text: responseText }] };
    } catch (error) {
      // エラー発生時に一時ファイルをクリーンアップ
      // @ts-ignore tmpLogFilePath is not defined in this scope
      if (typeof tmpLogFilePath === 'string' && await fs.pathExists(tmpLogFilePath)) {
        // @ts-ignore
        await fs.remove(tmpLogFilePath);
      }
      return {
        content: [
          { type: 'text' as const, text: `エラーが発生しました: ${error instanceof Error ? error.message : String(error)}` },
        ],
      };
    }
  },
} as const;