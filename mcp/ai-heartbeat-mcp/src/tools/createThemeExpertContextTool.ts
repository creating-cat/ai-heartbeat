/**
 * Theme Expert Context Creation Tool
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';
import { glob } from 'glob';
import { resolveThemePath } from '../lib/themeUtils';

// Zod schema for the tool input (サブテーマ対応版)
export const createThemeExpertContextInputSchema = z.object({
  themeName: z.string().describe('テーマの名称。'),
  themeStartId: z.string()
    .regex(/^\d{14}$/, 'THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .describe('テーマのTHEME_START_ID。テーマ開始時のハートビートIDと同じ値'),
  themeDirectoryPart: z
    .string()
    .describe('テーマディレクトリ名の一部（THEME_START_IDは含めない）。THEME_START_IDと組み合わせて "{THEME_START_ID}_{themeDirectoryPart}" の形式でテーマディレクトリが作成されます（例: themeDirectoryPart="ai_research" → ディレクトリ="20250115143000_ai_research"）。半角英小文字、数字、アンダースコアのみ推奨'),
  heartbeatId: z.string()
    .regex(/^\d{14}$/, 'ハートビートIDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .describe('コンテキスト作成時のハートビートID。ファイル名として使用されます'),
  expertRole: z
    .string()
    .describe('このテーマにおける専門家の役割定義。'),
  expertPerspective: z
    .array(z.string())
    .describe('このテーマにおける専門的な視点とアプローチを箇条書きのリストで指定します。'),
  constraints: z
    .array(z.string())
    .describe('この専門家として活動する上での重要な制約や注意点を箇条書きのリストで指定します。'),
  expectedOutcome: z
    .array(z.string())
    .describe(
      'この専門家コンテキストで期待される成果や方向性を箇条書きのリストで指定します。'
    ),
  
  // 🆕 サブテーマ対応の新規フィールド（最小限）
  parentThemeStartId: z.string()
    .regex(/^\d{14}$/, 'PARENT_THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .optional()
    .describe('サブテーマの場合、親テーマのTHEME_START_IDを指定。nullまたは未指定の場合はルートテーマとして扱われます'),
  parentThemeDirectoryPart: z.string()
    .optional()
    .describe('サブテーマの場合、親テーマのディレクトリ部分を指定。parentThemeStartIdが指定された場合は必須'),
});



// Helper to generate markdown content (シンプル版)
const generateContextContent = (
  themeName: string,
  expertRole: string,
  expertPerspective: string[],
  constraints: string[],
  expectedOutcome: string[]
): string => {
  return `# テーマ専門家コンテキスト

## 専門家設定
**${expertRole}**

## 専門性・役割
${expertPerspective.map(item => `- ${item}`).join('\n')}

## 重要な制約・注意事項
${constraints.map(item => `- ${item}`).join('\n')}

## 期待される成果
${expectedOutcome.map(item => `- ${item}`).join('\n')}
`;
};

// The tool definition
export const createThemeExpertContextTool = {
  name: 'create_theme_expert_context',
  description: `テーマの成果物ディレクトリのcontexts/フォルダに、テーマ専門家コンテキストファイル（{heartbeat_id}.md）を作成します。

重要: 新規メインテーマの場合、このツールを使用する前に「1人の専門家 vs 複数の専門家」の比較検討を実施し、その結果を活動ログに記録してください。サブテーマの場合は比較検討不要です。

注意: サブテーマでは親テーマのコンテキストを継承せず、サブテーマに最適化された独立したコンテキストを設定してください。`,
  input_schema: createThemeExpertContextInputSchema,
  execute: async (args: z.infer<typeof createThemeExpertContextInputSchema>) => {
    try {
      const {
        themeName,
        themeStartId,
        themeDirectoryPart,
        heartbeatId,
        expertRole,
        expertPerspective,
        constraints,
        expectedOutcome,
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

      // ディレクトリ名のサニタイズ
      const baseThemeDirectoryPart = path.basename(themeDirectoryPart);
      const sanitizedDirectoryPart = baseThemeDirectoryPart
        .toLowerCase()
        .replace(/[^a-z0-9_]+/g, '_')
        .replace(/_+/g, '_');
      
      const baseParentThemeDirectoryPart = parentThemeDirectoryPart ? path.basename(parentThemeDirectoryPart) : undefined;
      const sanitizedParentDirectoryPart = baseParentThemeDirectoryPart
        ?.toLowerCase()
        .replace(/[^a-z0-9_]+/g, '_')
        .replace(/_+/g, '_');

      // テーマディレクトリパスを解決
      const themeArtifactsPath = resolveThemePath(
        themeStartId,
        sanitizedDirectoryPart,
        parentThemeStartId,
        sanitizedParentDirectoryPart
      );
      const contextsPath = path.join(themeArtifactsPath, 'contexts');
      const contextFilePath = path.join(contextsPath, `${heartbeatId}.md`);

      // ハートビートID重複チェック（全contextsディレクトリを検索）
      const contextPattern = path.join('.', 'artifacts', '**', 'contexts', `${heartbeatId}.md`);
      const existingContexts = await glob(contextPattern);
      
      if (existingContexts.length > 0) {
        const existingPath = existingContexts[0].replace('artifacts/', '');
        throw new Error(
          `ルール違反: ハートビートID (${heartbeatId}) は既に専門家コンテキストで使用されています: ${existingPath}\n` +
          `1つの活動サイクルでは1つのテーマ操作のみ実行可能です。\n` +
          `解決方法: 次のハートビートを待って新たな活動サイクルを開始してから専門家コンテキスト作成を実行してください。`
        );
      }

      // ディレクトリ存在確認（テーマが開始されているかチェック）
      if (!await fs.pathExists(themeArtifactsPath)) {
        // サブテーマの場合は親テーマの存在確認（ディレクトリ作成前）
        if (parentThemeStartId && sanitizedParentDirectoryPart) {
          const parentPath = resolveThemePath(parentThemeStartId, sanitizedParentDirectoryPart);
          if (!await fs.pathExists(parentPath)) {
            throw new Error(`親テーマディレクトリが存在しません: ${parentPath}`);
          }
        }
        
        // ディレクトリが存在しない場合は作成（テーマ開始前でも作成可能）
        await fs.ensureDir(themeArtifactsPath);
        await fs.ensureDir(path.join(themeArtifactsPath, 'histories'));
      }

      // contexts/ フォルダを確保
      await fs.ensureDir(contextsPath);

      // コンテンツ生成
      const content = generateContextContent(themeName, expertRole, expertPerspective, constraints, expectedOutcome);
      await fs.writeFile(contextFilePath, content, 'utf-8');

      // サニタイズ警告の準備
      const isSanitized = sanitizedDirectoryPart !== themeDirectoryPart;
      const isParentSanitized = sanitizedParentDirectoryPart && baseParentThemeDirectoryPart && 
                                sanitizedParentDirectoryPart !== parentThemeDirectoryPart;
      
      const themeType = parentThemeStartId ? 'サブテーマ' : 'テーマ';
      let responseText = `成功: ${themeType}専門家コンテキストファイルを作成しました: ${contextFilePath}`;
      responseText += `\n${themeType}ディレクトリ: ${themeArtifactsPath}`;
      responseText += `\nTHEME_START_ID: ${themeStartId}`;
      responseText += `\nハートビートID: ${heartbeatId}`;
      
      if (parentThemeStartId) {
        responseText += `\nPARENT_THEME_START_ID: ${parentThemeStartId}`;
      }
      
      if (isSanitized) {
        responseText += `\n警告: ディレクトリ名を「${themeDirectoryPart}」から「${sanitizedDirectoryPart}」に修正しました`;
      }
      
      if (isParentSanitized) {
        responseText += `\n警告: 親ディレクトリ名を「${parentThemeDirectoryPart}」から「${sanitizedParentDirectoryPart}」に修正しました`;
      }

      return { content: [{ type: 'text' as const, text: responseText }] };
    } catch (error: any) {
      return { content: [{ type: 'text' as const, text: `エラー: テーマ専門家コンテキストファイルの作成に失敗しました: ${error.message}` }] };
    }
  },
};
