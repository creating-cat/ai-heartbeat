/**
 * Theme Expert Context Creation Tool
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';

// Zod schema for the tool input
export const createThemeExpertContextInputSchema = z.object({
  themeName: z.string().describe('テーマの名称。'),
  themeDirectoryName: z
    .string()
    .describe('テーマのサニタイズされたディレクトリ名。'),
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
  return `# テーマ専門家コンテキスト: ${themeName}

## 専門家役割
${expertRole}

## 専門的視点
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
  description: "テーマの成果物ディレクトリに、テーマ専門家コンテキストファイル（context.md）を作成します。",
  input_schema: createThemeExpertContextInputSchema,
  execute: async (args: z.infer<typeof createThemeExpertContextInputSchema>) => {
    try {
      const {
        themeName,
        themeDirectoryName,
        expertRole,
        expertPerspective,
        constraints,
        expectedOutcome,
      } = args;

      const baseThemeDirectoryName = path.basename(themeDirectoryName);
      const themeArtifactsPath = path.join('artifacts', baseThemeDirectoryName);
      const contextFilePath = path.join(themeArtifactsPath, 'context.md');

      await fs.ensureDir(themeArtifactsPath);

      const content = generateContextContent(themeName, expertRole, expertPerspective, constraints, expectedOutcome);
      await fs.writeFile(contextFilePath, content, 'utf-8');

      return { content: [{ type: 'text' as const, text: `成功: テーマ専門家コンテキストファイルを作成しました: ${contextFilePath}` }] };
    } catch (error: any) {
      return { content: [{ type: 'text' as const, text: `エラー: テーマ専門家コンテキストファイルの作成に失敗しました: ${error.message}` }] };
    }
  },
};
