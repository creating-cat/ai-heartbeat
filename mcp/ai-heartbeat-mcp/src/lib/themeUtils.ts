/**
 * Theme utilities for AI Heartbeat MCP
 * Common functions for theme directory path resolution and operations
 */

import * as path from 'path';
import { ARTIFACTS_DIR } from './pathConstants';

/**
 * Resolves the full path to a theme directory
 * @param themeStartId - Theme start heartbeat ID (14 digits)
 * @param themeDirectoryPart - Theme directory name part
 * @param parentThemeStartId - Parent theme start ID (for subthemes)
 * @param parentThemeDirectoryPart - Parent theme directory part (for subthemes)
 * @returns Full path to the theme directory
 */
export function resolveThemePath(
  themeStartId: string,
  themeDirectoryPart: string,
  parentThemeStartId?: string,
  parentThemeDirectoryPart?: string
): string {
  if (parentThemeStartId && parentThemeDirectoryPart) {
    // サブテーマの場合
    const sanitizedParentPart = path.basename(parentThemeDirectoryPart);
    const sanitizedThemePart = path.basename(themeDirectoryPart);
    
    const parentDir = `${parentThemeStartId}_${sanitizedParentPart}`;
    const subthemeDir = `${themeStartId}_${sanitizedThemePart}`;
    return path.join(ARTIFACTS_DIR, parentDir, 'subthemes', subthemeDir);
  } else {
    // メインテーマの場合
    const sanitizedThemePart = path.basename(themeDirectoryPart);
    return path.join(ARTIFACTS_DIR, `${themeStartId}_${sanitizedThemePart}`);
  }
}

/**
 * Resolves the path to the histories subdirectory of a theme
 * @param themeStartId - Theme start heartbeat ID
 * @param themeDirectoryPart - Theme directory name part
 * @param parentThemeStartId - Parent theme start ID (for subthemes)
 * @param parentThemeDirectoryPart - Parent theme directory part (for subthemes)
 * @returns Full path to the theme's histories directory
 */
export function resolveThemeHistoriesPath(
  themeStartId: string,
  themeDirectoryPart: string,
  parentThemeStartId?: string,
  parentThemeDirectoryPart?: string
): string {
  const themePath = resolveThemePath(themeStartId, themeDirectoryPart, parentThemeStartId, parentThemeDirectoryPart);
  return path.join(themePath, 'histories');
}

/**
 * Resolves the path to the contexts subdirectory of a theme
 * @param themeStartId - Theme start heartbeat ID
 * @param themeDirectoryPart - Theme directory name part
 * @param parentThemeStartId - Parent theme start ID (for subthemes)
 * @param parentThemeDirectoryPart - Parent theme directory part (for subthemes)
 * @returns Full path to the theme's contexts directory
 */
export function resolveThemeContextsPath(
  themeStartId: string,
  themeDirectoryPart: string,
  parentThemeStartId?: string,
  parentThemeDirectoryPart?: string
): string {
  const themePath = resolveThemePath(themeStartId, themeDirectoryPart, parentThemeStartId, parentThemeDirectoryPart);
  return path.join(themePath, 'contexts');
}