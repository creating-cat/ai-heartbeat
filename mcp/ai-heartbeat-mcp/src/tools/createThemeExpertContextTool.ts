/**
 * Theme Expert Context Creation Tool
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';

// Zod schema for the tool input
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
});

// Helper to generate markdown content
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
  description: "テーマの成果物ディレクトリのcontexts/フォルダに、テーマ専門家コンテキストファイル（{heartbeat_id}.md）を作成します。",
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
      } = args;

      // THEME_START_ID付きの完全なディレクトリ名を生成
      const baseThemeDirectoryPart = path.basename(themeDirectoryPart);
      const sanitizedDirectoryPart = baseThemeDirectoryPart
        .toLowerCase()
        .replace(/[^a-z0-9_]+/g, '_')
        .replace(/_+/g, '_');
      const fullThemeDirectoryName = `${themeStartId}_${sanitizedDirectoryPart}`;
      const themeArtifactsPath = path.join('artifacts', fullThemeDirectoryName);
      const contextsPath = path.join(themeArtifactsPath, 'contexts');
      const contextFilePath = path.join(contextsPath, `${heartbeatId}.md`);

      // ディレクトリ存在確認（テーマが開始されているかチェック）
      if (!await fs.pathExists(themeArtifactsPath)) {
        // ディレクトリが存在しない場合は作成（テーマ開始前でも作成可能）
        await fs.ensureDir(themeArtifactsPath);
        await fs.ensureDir(path.join(themeArtifactsPath, 'histories'));
      }

      // contexts/ フォルダを確保
      await fs.ensureDir(contextsPath);

      // 重複チェック
      if (await fs.pathExists(contextFilePath)) {
        throw new Error(`コンテキストファイルは既に存在します: ${contextFilePath}`);
      }

      const content = generateContextContent(themeName, expertRole, expertPerspective, constraints, expectedOutcome);
      await fs.writeFile(contextFilePath, content, 'utf-8');

      // サニタイズ警告の準備
      const isSanitized = sanitizedDirectoryPart !== themeDirectoryPart;
      let responseText = `成功: テーマ専門家コンテキストファイルを作成しました: ${contextFilePath}`;
      responseText += `\nテーマディレクトリ: ${themeArtifactsPath}`;
      responseText += `\nTHEME_START_ID: ${themeStartId}`;
      responseText += `\nハートビートID: ${heartbeatId}`;
      
      if (isSanitized) {
        responseText += `\n警告: ディレクトリ名を「${themeDirectoryPart}」から「${sanitizedDirectoryPart}」に修正しました`;
      }

      return { content: [{ type: 'text' as const, text: responseText }] };
    } catch (error: any) {
      return { content: [{ type: 'text' as const, text: `エラー: テーマ専門家コンテキストファイルの作成に失敗しました: ${error.message}` }] };
    }
  },
};
