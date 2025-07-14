/**
 * Theme Expert Context Creation Tool
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';

// Zod schema for the tool input
export const createThemeExpertContextInputSchema = z.object({
  themeName: z.string().describe('The name of the theme.'),
  themeDirectoryName: z
    .string()
    .describe('The sanitized directory name for the theme.'),
  expertRole: z
    .string()
    .describe('The definition of the expert role for this theme.'),
  expertPerspective: z
    .array(z.string())
    .describe('The expert perspective and approach for this theme as a list of points.'),
  constraints: z
    .array(z.string())
    .describe('Important constraints and notes for acting as this expert as a list of points.'),
  expectedOutcome: z
    .array(z.string())
    .describe(
      'The expected outcome or direction of results in this expert context as a list of points.'
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
  description:
    "Creates a theme expert context file (context.md) in the theme's artifact directory.",
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
