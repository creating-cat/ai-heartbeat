/**
 * Start Theme Tool
 * Atomically starts a new theme with all necessary operations.
 */

import * as fs from 'fs-extra';
import * as path from 'path';
import { z } from 'zod';
import { glob } from 'glob';
import { resolveThemePath } from '../lib/themeUtils';
import { THEME_HISTORIES_DIR, THEMEBOX_DIR } from '../lib/pathConstants';

// Zod schema for start theme input
export const startThemeInputSchema = z.object({
  target_filename: z.string().describe('preview_next_themeで取得した、処理対象のファイル名'),
  themeName: z.string().describe('AIが決定したテーマの正式名称'),
  themeDirectoryPart: z.string()
    .describe('テーマディレクトリ名の一部。THEME_START_IDと組み合わせて "{THEME_START_ID}_{themeDirectoryPart}" の形式でテーマディレクトリが作成されます。半角英小文字、数字、アンダースコアのみ推奨'),
  reason: z.string().describe('テーマを開始する理由'),
  activityContent: z.array(z.string()).optional().describe('テーマ開始時に記録する初期活動計画のリスト'),
  
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

export const startThemeTool = {
  name: 'start_theme',
  description: 'AIがテーマ開始を意思決定した後に、テーマの開始に必要なすべての処理をアトミック（不可分）に実行します。途中で失敗した場合は一切の状態変更を行わず、具体的なエラーメッセージを返します。',
  input_schema: startThemeInputSchema,
  execute: async (args: z.infer<typeof startThemeInputSchema>) => {
    // クリーンアップ用の変数
    let createdHistoryFile: string | null = null;
    let createdThemeDirectory: string | null = null;
    let tmpHistoryFile: string | null = null;

    try {
      const {
        target_filename,
        themeName,
        themeDirectoryPart,
        reason,
        activityContent,
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

      // 現在のハートビートIDを生成（THEME_START_ID）
      const now = new Date();
      const themeStartId = now.getFullYear().toString() +
        (now.getMonth() + 1).toString().padStart(2, '0') +
        now.getDate().toString().padStart(2, '0') +
        now.getHours().toString().padStart(2, '0') +
        now.getMinutes().toString().padStart(2, '0') +
        now.getSeconds().toString().padStart(2, '0');

      // --- 段階1: ファイル存在確認 ---
      const targetFilePath = path.join(THEMEBOX_DIR, target_filename);
      if (!(await fs.pathExists(targetFilePath))) {
        throw new Error('指定されたテーマファイルが見つかりません');
      }

      // 既に処理済みかチェック
      if (target_filename.startsWith('processed.')) {
        throw new Error('指定されたテーマファイルは既に処理済みです');
      }

      // --- 段階2: クールダウン期間確認（ハートビートID重複チェック） ---
      const themeHistoryPattern = path.join(THEME_HISTORIES_DIR, `${themeStartId}_*.md`);
      const existingThemeHistories = await glob(themeHistoryPattern);

      if (existingThemeHistories.length > 0) {
        const existingFile = path.basename(existingThemeHistories[0]);
        throw new Error(`クールダウン期間中です。この活動サイクルでは既にテーマ操作が実行されています（${existingFile}）。次のハートビートを待って新たな活動サイクルを開始してから再実行してください。`);
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

      // --- 段階3: 履歴ファイル作成 ---
      const logFileName = `${themeStartId}_start_${sanitizedDirectoryPart}.md`;
      const logFilePath = path.join(THEME_HISTORIES_DIR, logFileName);

      // 履歴ファイルの内容生成
      const activityList = formatList(activityContent, '(このテーマで何を行うか)');
      const markdownContent = `# ${themeType}開始: ${themeName}

${isSubtheme ? `**PARENT_THEME_START_ID**: ${parentThemeStartId}
**PARENT_THEME_DIRECTORY**: ${parentThemeStartId}_${sanitizedParentDirectoryPart}
` : ''}**THEME_START_ID**: ${themeStartId}
**テーマディレクトリ**: \`${themeDirectoryPath}/\`

**開始理由**:
${reason || 'N/A'}

**活動内容**:
${activityList}
`;

      // 一時ファイルに書き込み
      tmpHistoryFile = `${logFilePath}.tmp`;
      await fs.ensureDir(path.dirname(tmpHistoryFile));
      await fs.writeFile(tmpHistoryFile, markdownContent, 'utf-8');

      // --- 段階4: テーマディレクトリ作成 ---
      try {
        if (isSubtheme) {
          const parentPath = resolveThemePath(parentThemeStartId!, sanitizedParentDirectoryPart!);
          if (!await fs.pathExists(parentPath)) {
            throw new Error(`親テーマディレクトリが存在しません: ${parentPath}`);
          }
        }
        
        await fs.ensureDir(themeDirectoryPath);
        await fs.ensureDir(path.join(themeDirectoryPath, 'histories'));
        createdThemeDirectory = themeDirectoryPath;
      } catch (error) {
        // 段階3で作成した一時ファイルをクリーンアップ
        if (tmpHistoryFile && await fs.pathExists(tmpHistoryFile)) {
          await fs.remove(tmpHistoryFile);
        }
        throw new Error(`テーマディレクトリの作成に失敗しました: ${error instanceof Error ? error.message : String(error)}`);
      }

      // --- 段階5: ファイルリネーム（最終段階） ---
      try {
        // 履歴ファイルの最終確認とリネーム
        if (await fs.pathExists(logFilePath)) {
          throw new Error(`テーマ履歴ファイルは既に存在します: ${logFilePath}。競合が発生した可能性があります。`);
        }

        // 一時ファイルを本番パスにリネーム（アトミック操作）
        await fs.rename(tmpHistoryFile, logFilePath);
        createdHistoryFile = logFilePath;
        tmpHistoryFile = null; // 成功したのでクリーンアップ対象から外す

        // themeboxファイルを処理済みにリネーム
        const processedFilePath = path.join(THEMEBOX_DIR, `processed.${target_filename}`);
        await fs.rename(targetFilePath, processedFilePath);

      } catch (error) {
        // 段階3・4で作成したファイル・ディレクトリをクリーンアップ
        if (tmpHistoryFile && await fs.pathExists(tmpHistoryFile)) {
          await fs.remove(tmpHistoryFile);
        }
        if (createdThemeDirectory && await fs.pathExists(createdThemeDirectory)) {
          await fs.remove(createdThemeDirectory);
        }
        throw new Error(`テーマファイルの処理完了マークに失敗しました: ${error instanceof Error ? error.message : String(error)}`);
      }

      // 成功レスポンス
      let responseText = `${themeType}を正常に開始しました。\n`;
      responseText += `${themeType}履歴ファイル: ${logFilePath}\n`;
      responseText += `${themeType}ディレクトリ: ${themeDirectoryPath}\n`;
      responseText += `THEME_START_ID: ${themeStartId}`;
      
      if (isSubtheme) {
        responseText += `\nPARENT_THEME_START_ID: ${parentThemeStartId}`;
      }

      // サニタイズ警告
      if (isSanitized) {
        responseText += `\n警告: ディレクトリ名を「${themeDirectoryPart}」から「${sanitizedDirectoryPart}」に修正しました`;
      }
      if (isParentSanitized) {
        responseText += `\n警告: 親ディレクトリ名を「${parentThemeDirectoryPart}」から「${sanitizedParentDirectoryPart}」に修正しました`;
      }

      return { 
        content: [{ 
          type: 'text' as const, 
          text: responseText 
        }] 
      };

    } catch (error) {
      // エラー時のクリーンアップ処理
      try {
        if (tmpHistoryFile && await fs.pathExists(tmpHistoryFile)) {
          await fs.remove(tmpHistoryFile);
        }
        if (createdHistoryFile && await fs.pathExists(createdHistoryFile)) {
          await fs.remove(createdHistoryFile);
        }
        if (createdThemeDirectory && await fs.pathExists(createdThemeDirectory)) {
          await fs.remove(createdThemeDirectory);
        }
      } catch (cleanupError) {
        console.error('クリーンアップ処理でエラーが発生しました:', cleanupError);
        return {
          content: [
            { 
              type: 'text' as const, 
              text: `エラー: ${error instanceof Error ? error.message : String(error)}\n\n追加エラー: クリーンアップ処理に失敗しました。手動でファイルの確認が必要な場合があります。` 
            },
          ],
        };
      }

      return {
        content: [
          { 
            type: 'text' as const, 
            text: `エラー: ${error instanceof Error ? error.message : String(error)}\n\n作成済みファイルをクリーンアップしました。安心して再実行してください。` 
          },
        ],
      };
    }
  },
} as const;