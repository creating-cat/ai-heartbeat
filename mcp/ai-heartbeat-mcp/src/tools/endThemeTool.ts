/**
 * End Theme Tool
 * Dedicated tool for ending themes with proper cleanup and messaging.
 */

import * as fs from 'fs-extra';
import * as path from 'path';
import { z } from 'zod';
import { glob } from 'glob';
import { resolveThemePath } from '../lib/themeUtils';
import { THEME_HISTORIES_DIR } from '../lib/pathConstants';

// Zod schema for end theme input
export const endThemeInputSchema = z.object({
  themeStartId: z.string()
    .regex(/^\d{14}$/, 'THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .describe('終了対象テーマのTHEME_START_ID'),
  themeDirectoryPart: z.string()
    .describe('終了対象テーマのディレクトリ部分'),
  themeName: z.string().describe('テーマの正式名称'),
  reason: z.string().describe('テーマを終了する理由'),
  achievements: z.array(z.string()).optional().describe('テーマで達成した主な成果のリスト'),
  
  // サブテーマ対応
  parentThemeStartId: z.string()
    .regex(/^\d{14}$/, 'PARENT_THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .optional()
    .describe('サブテーマの場合、親テーマのTHEME_START_IDを指定'),
  parentThemeDirectoryPart: z.string()
    .optional()
    .describe('サブテーマの場合、親テーマのディレクトリ部分を指定'),
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

function getThemeType(parentThemeStartId?: string): string {
  return parentThemeStartId ? 'サブテーマ' : 'テーマ';
}

export const endThemeTool = {
  name: 'end_theme',
  description: `現在のテーマの終了に関する処理を専門に実行します。
このツールは、以下の処理を一連のトランザクションとして実行します：

1. 現在のハートビートID（THEME_END_ID）の生成
2. テーマ履歴ファイルの作成
4. 履歴ファイルの最終確認とリネーム

途中で失敗した場合は一切の状態変更を行わず、具体的なエラーメッセージを返します。`,
  input_schema: endThemeInputSchema,
  execute: async (args: z.infer<typeof endThemeInputSchema>) => {
    try {
      const {
        themeStartId,
        themeDirectoryPart,
        themeName,
        reason,
        achievements,
        parentThemeStartId,
        parentThemeDirectoryPart,
      } = args;

      // バリデーション
      if (parentThemeStartId && !parentThemeDirectoryPart) {
        throw new Error('parentThemeStartIdが指定された場合、parentThemeDirectoryPartも必須です');
      }

      if (parentThemeDirectoryPart && !parentThemeStartId) {
        throw new Error('parentThemeDirectoryPartが指定された場合、parentThemeStartIdも必須です');
      }

      // 現在のハートビートIDを生成（THEME_END_ID）
      const now = new Date();
      const themeEndId = now.getFullYear().toString() +
        (now.getMonth() + 1).toString().padStart(2, '0') +
        now.getDate().toString().padStart(2, '0') +
        now.getHours().toString().padStart(2, '0') +
        now.getMinutes().toString().padStart(2, '0') +
        now.getSeconds().toString().padStart(2, '0');

      // ハートビートID重複チェック（全テーマ履歴ファイルを検索）
      const themeHistoryPattern = path.join(THEME_HISTORIES_DIR, `${themeEndId}_*.md`);
      const existingThemeHistories = await glob(themeHistoryPattern);

      if (existingThemeHistories.length > 0) {
        const existingFile = path.basename(existingThemeHistories[0]);
        const warningMessage =
          `警告: この活動サイクルでは既にテーマ操作が実行されています（${existingFile}）。ルール違反になるため、この操作は実行されませんでした。\n` +
          `解決方法: 次のハートビートを待って新たな活動サイクルを開始してからテーマ操作を実行してください。`;
        return {
          content: [{ type: 'text' as const, text: warningMessage }],
        };
      }

      // ディレクトリ名のサニタイズ
      const baseThemeDirectoryPart = path.basename(themeDirectoryPart);
      const baseParentThemeDirectoryPart = parentThemeDirectoryPart ? path.basename(parentThemeDirectoryPart) : undefined;

      const sanitizedDirectoryPart = baseThemeDirectoryPart
        .toLowerCase()
        .replace(/[^a-z0-9_]+/g, '_')
        .replace(/_+/g, '_');
      const sanitizedParentDirectoryPart = baseParentThemeDirectoryPart
        ?.toLowerCase()
        .replace(/[^a-z0-9_]+/g, '_')
        .replace(/_+/g, '_');

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

      // 履歴ファイル作成
      const logFileName = `${themeEndId}_end_${sanitizedDirectoryPart}.md`;
      const logFilePath = path.join(THEME_HISTORIES_DIR, logFileName);

      // 履歴ファイルの内容生成
      const achievementList = formatList(achievements, 'N/A');
      const markdownContent = `# ${themeType}終了: ${themeName}

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

      // 堅牢なファイル操作
      const tmpLogFilePath = `${logFilePath}.tmp`;
      await fs.ensureDir(path.dirname(tmpLogFilePath));
      await fs.writeFile(tmpLogFilePath, markdownContent, 'utf-8');

      // 最終的なファイルパスの重複を再度チェック（リネーム直前）
      if (await fs.pathExists(logFilePath)) {
        await fs.remove(tmpLogFilePath); // 一時ファイルをクリーンアップ
        throw new Error(`テーマ履歴ファイルは既に存在します: ${logFilePath}。競合が発生した可能性があります。`);
      }

      // 一時ファイルを本番パスにリネーム（アトミック操作）
      await fs.rename(tmpLogFilePath, logFilePath);

      // テーマディレクトリの存在確認（警告のみ）
      if (!await fs.pathExists(themeDirectoryPath)) {
        console.warn(`警告: テーマディレクトリが見つかりません: ${themeDirectoryPath}`);
      }

      // 応答メッセージ作成
      let responseText = `${themeType}履歴ファイルを作成しました: ${logFilePath}\n`;
      responseText += `${themeType}終了: ${themeStartId} → ${themeEndId}`;
      
      if (isSubtheme) {
        responseText += `\n親テーマに戻ります: ${parentThemeStartId}_${sanitizedParentDirectoryPart}`;
      }

      // テーマ終了時のリセット指示（AIファースト設計に基づく明確なメッセージ）
      responseText += `\n\nテーマが正常に完了しました。`;
      responseText += `\nこの後、テーマ終了活動の活動ログを作成して必ずターン完了応答を行なってください。`;
      responseText += `\n\n重要: 新しいテーマの開始は、次のハートビートを待って新たな活動サイクルで行ってください。`;

      return { 
        content: [{ 
          type: 'text' as const, 
          text: responseText 
        }] 
      };

    } catch (error) {
      return {
        content: [
          { 
            type: 'text' as const, 
            text: `エラーが発生しました: ${error instanceof Error ? error.message : String(error)}` 
          },
        ],
      };
    }
  },
} as const;