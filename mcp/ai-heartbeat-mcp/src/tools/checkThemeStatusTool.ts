/**
 * Clean Check Theme Status Tool - サブテーマ対応版（クリーンアップ済み）
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';
import { THEME_HISTORIES_DIR } from '../lib/pathConstants';
import { resolveThemePath } from '../lib/themeUtils';

// テーマ状態情報の型定義（統一版）
interface ThemeStatus {
  themeStartId: string;
  themeDirectoryPart: string;
  themeName?: string;
  status: 'active' | 'completed';
  activityCount: number;
  directoryPath: string;
  
  // 親テーマ情報（サブテーマの場合のみ）
  parentThemeStartId?: string;
  parentThemeDirectoryPart?: string;
  
  // サブテーマ情報（メインテーマの場合のみ）
  subthemes: ThemeStatus[];
  
  // 統計情報（ルートレベルでのみ計算）
  totalActivities?: number;
  activityDistribution?: { [key: string]: number };
}

// 入力スキーマ
export const checkThemeStatusInputSchema = z.object({
  themeStartId: z.string()
    .regex(/^\d{14}$/, 'THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .describe('確認したいテーマのTHEME_START_ID'),
  themeDirectoryPart: z.string()
    .describe('テーマディレクトリ名の一部。THEME_START_IDと組み合わせて "{THEME_START_ID}_{themeDirectoryPart}" の形式でテーマディレクトリが特定されます'),
  includeSubthemes: z.boolean()
    .optional()
    .default(true)
    .describe('サブテーマ情報も含めるかどうか'),
});


// 活動ログ数をカウント
async function countActivityLogs(themeDirectoryPath: string): Promise<number> {
  const historiesPath = path.join(themeDirectoryPath, 'histories');
  if (!await fs.pathExists(historiesPath)) {
    return 0;
  }
  
  const files = await fs.readdir(historiesPath);
  return files.filter(file => file.endsWith('.md')).length;
}

// 活動分布を取得
async function getActivityDistribution(themeDirectoryPath: string): Promise<{ [key: string]: number }> {
  const historiesPath = path.join(themeDirectoryPath, 'histories');
  if (!await fs.pathExists(historiesPath)) {
    return {};
  }
  
  const files = await fs.readdir(historiesPath);
  const mdFiles = files.filter(file => file.endsWith('.md'));
  const distribution: { [key: string]: number } = {};
  
  for (const file of mdFiles) {
    try {
      const content = await fs.readFile(path.join(historiesPath, file), 'utf-8');
      const activityTypeMatch = content.match(/^## 活動種別\s*\n(.+?)(?:\s*\(|$)/m);
      if (activityTypeMatch) {
        const activityType = activityTypeMatch[1].trim();
        distribution[activityType] = (distribution[activityType] || 0) + 1;
      }
    } catch (error) {
      console.warn(`活動ログファイルの読み込みに失敗: ${file}`);
    }
  }
  
  return distribution;
}

// サブテーマ情報を取得
async function getSubthemeInfo(subthemeDir: string, parentPath: string): Promise<ThemeStatus | null> {
  const subthemePath = path.join(parentPath, 'subthemes', subthemeDir);
  
  if (!await fs.pathExists(subthemePath)) {
    return null;
  }
  
  // ディレクトリ名からIDと名前を抽出
  const match = subthemeDir.match(/^(\d{14})_(.+)$/);
  if (!match) {
    return null;
  }
  
  const [, subthemeStartId, subthemeDirectoryPart] = match;
  
  // サブテーマのステータスをtheme_historiesから判定
  let status: 'active' | 'completed' = 'active';
  const themeHistoriesPath = THEME_HISTORIES_DIR;
  if (await fs.pathExists(themeHistoriesPath)) {
    const historyFiles = await fs.readdir(themeHistoriesPath);
    
    // 改良された検索ロジック: themeDirectoryPartでの正確なマッチング
    const endFile = historyFiles.find(file => 
      file.includes(`_end_${subthemeDirectoryPart}.md`) && file.endsWith('.md')
    );
    
    if (endFile) {
      // THEME_START_IDとの関連性を確認（開始ファイルの存在確認）
      const startFile = historyFiles.find(file => 
        file.startsWith(`${subthemeStartId}_start_${subthemeDirectoryPart}.md`)
      );
      
      if (startFile) {
        status = 'completed';
      } else {
        // 開始ファイルが見つからない場合の警告（デバッグ用）
        console.warn(`サブテーマ終了ファイルは存在するが開始ファイルが見つかりません: ${endFile}`);
      }
    }
  }
  
  // 活動ログ数をカウント
  const activityCount = await countActivityLogs(subthemePath);
  
  // テーマ履歴からテーマ名を取得
  let subthemeName: string | undefined;
  if (await fs.pathExists(themeHistoriesPath)) {
    const historyFiles = await fs.readdir(themeHistoriesPath);
    const startFile = historyFiles.find(file => 
      file.startsWith(`${subthemeStartId}_start_`) && file.endsWith('.md')
    );
    
    if (startFile) {
      try {
        const content = await fs.readFile(path.join(themeHistoriesPath, startFile), 'utf-8');
        const nameMatch = content.match(/^#\s*(?:サブ)?テーマ開始:\s*(.+)$/m);
        if (nameMatch) {
          subthemeName = nameMatch[1].trim();
        }
      } catch (error) {
        console.warn(`テーマ履歴ファイルの読み込みに失敗: ${startFile}`);
      }
    }
  }
  
  return {
    themeStartId: subthemeStartId,
    themeDirectoryPart: subthemeDirectoryPart,
    themeName: subthemeName,
    status: status,
    activityCount,
    directoryPath: subthemePath,
    subthemes: [], // サブテーマは現在1階層のみ
  };
}

// 全サブテーマを取得
async function getAllSubthemes(themeDirectoryPath: string): Promise<ThemeStatus[]> {
  const subthemesPath = path.join(themeDirectoryPath, 'subthemes');
  
  if (!await fs.pathExists(subthemesPath)) {
    return [];
  }
  
  const subthemeDirs = await fs.readdir(subthemesPath);
  const subthemes: ThemeStatus[] = [];
  
  for (const dir of subthemeDirs) {
    const subthemeInfo = await getSubthemeInfo(dir, themeDirectoryPath);
    if (subthemeInfo) {
      subthemes.push(subthemeInfo);
    }
  }
  
  // 作成日時でソート（ディレクトリ名のIDでソート）
  subthemes.sort((a, b) => a.themeStartId.localeCompare(b.themeStartId));
  
  return subthemes;
}

// テーマ名を取得
async function getThemeName(themeStartId: string): Promise<string | undefined> {
  const themeHistoriesPath = THEME_HISTORIES_DIR;
  if (!await fs.pathExists(themeHistoriesPath)) {
    return undefined;
  }
  
  const historyFiles = await fs.readdir(themeHistoriesPath);
  const startFile = historyFiles.find(file => 
    file.startsWith(`${themeStartId}_start_`) && file.endsWith('.md')
  );
  
  if (!startFile) {
    return undefined;
  }
  
  try {
    const content = await fs.readFile(path.join(themeHistoriesPath, startFile), 'utf-8');
    const nameMatch = content.match(/^#\s*(?:サブ)?テーマ開始:\s*(.+)$/m);
    return nameMatch ? nameMatch[1].trim() : undefined;
  } catch (error) {
    console.warn(`テーマ履歴ファイルの読み込みに失敗: ${startFile}`);
    return undefined;
  }
}

// テーマ状態を取得
async function getThemeStatus(
  themeStartId: string,
  themeDirectoryPart: string,
  includeSubthemes: boolean = true
): Promise<ThemeStatus | null> {
  const themeDirectoryPath = resolveThemePath(themeStartId, themeDirectoryPart);
  
  if (!await fs.pathExists(themeDirectoryPath)) {
    return null;
  }
  
  // 基本情報
  const activityCount = await countActivityLogs(themeDirectoryPath);
  const themeName = await getThemeName(themeStartId);
  
  // 活動分布を取得（メインテーマ + 全サブテーマ）
  const mainActivityDistribution = await getActivityDistribution(themeDirectoryPath);
  
  // サブテーマ情報
  const subthemes = includeSubthemes ? await getAllSubthemes(themeDirectoryPath) : [];
  const totalActivities = activityCount + subthemes.reduce((sum, sub) => sum + sub.activityCount, 0);
  
  // 全体の活動分布を計算（メイン + サブテーマ）
  const totalActivityDistribution = { ...mainActivityDistribution };
  for (const subtheme of subthemes) {
    const subthemeDistribution = await getActivityDistribution(subtheme.directoryPath);
    for (const [activityType, count] of Object.entries(subthemeDistribution)) {
      totalActivityDistribution[activityType] = (totalActivityDistribution[activityType] || 0) + count;
    }
  }
  
  // テーマの完了状態を判定（テーマ履歴から）
  let status: 'active' | 'completed' = 'active';
  const themeHistoriesPath = THEME_HISTORIES_DIR;
  if (await fs.pathExists(themeHistoriesPath)) {
    const historyFiles = await fs.readdir(themeHistoriesPath);
    
    // 改良された検索ロジック: themeDirectoryPartでの正確なマッチング
    const endFile = historyFiles.find(file => 
      file.includes(`_end_${themeDirectoryPart}.md`) && file.endsWith('.md')
    );
    
    if (endFile) {
      // THEME_START_IDとの関連性を確認（開始ファイルの存在確認）
      const startFile = historyFiles.find(file => 
        file.startsWith(`${themeStartId}_start_${themeDirectoryPart}.md`)
      );
      
      if (startFile) {
        status = 'completed';
      } else {
        // 開始ファイルが見つからない場合の警告（デバッグ用）
        console.warn(`テーマ終了ファイルは存在するが開始ファイルが見つかりません: ${endFile}`);
      }
    }
  }
  
  return {
    themeStartId,
    themeDirectoryPart,
    themeName,
    status,
    activityCount,
    directoryPath: themeDirectoryPath,
    subthemes,
    totalActivities,
    activityDistribution: totalActivityDistribution,
  };
}

// JSON形式でテーマ状態を生成
function generateThemeStatusJson(themeStatus: ThemeStatus): any {
  const result: any = {
    is_active: themeStatus.status === 'active',
    theme_name: themeStatus.themeName,
    theme_start_id: themeStatus.themeStartId,
    theme_directory_part: themeStatus.themeDirectoryPart,
    activity_count: themeStatus.activityCount
  };

  // メインテーマの場合は親テーマ情報を追加（サブテーマかどうかの判別用）
  if (themeStatus.parentThemeStartId) {
    result.parent_theme_start_id = themeStatus.parentThemeStartId;
    result.parent_theme_directory_part = themeStatus.parentThemeDirectoryPart;
  }

  // サブテーマ情報（シンプルで実用的な構造）
  result.subthemes = themeStatus.subthemes.map(subtheme => ({
    is_active: subtheme.status === 'active',
    theme_name: subtheme.themeName,
    theme_start_id: subtheme.themeStartId,
    theme_directory_part: subtheme.themeDirectoryPart,
    activity_count: subtheme.activityCount,
    parent_theme_start_id: themeStatus.themeStartId,
    parent_theme_directory_part: themeStatus.themeDirectoryPart
  }));

  // 実用的な統計情報（常時表示）
  result.stats = {
    total_activities: themeStatus.totalActivities,
    activity_distribution: themeStatus.activityDistribution
  };

  return result;
}

export const checkThemeStatusTool = {
  name: 'check_theme_status',
  description: `テーマの状態をJSON形式で確認します。サブテーマ情報も含めて、現在のテーマの進捗状況や構造を詳細に返却します。

返却されるJSONフィールド:
- is_active (boolean): テーマが現在アクティブかどうか
- theme_name (string): テーマの正式名称
- theme_start_id (string): テーマ開始時のハートビートID
- theme_directory_part (string): ディレクトリ名の一部
- activity_count (number): このテーマの活動数
- parent_theme_start_id (string, optional): 親テーマのID（サブテーマの場合のみ）
- parent_theme_directory_part (string, optional): 親テーマのディレクトリ部分（サブテーマの場合のみ）
- subthemes (array): サブテーマの配列（同じ構造がネスト）
- stats (object): 実用的な統計情報
  - total_activities (number): 総活動数（メイン + サブテーマ）
  - activity_distribution (object): 活動種別ごとの件数

parent_theme_start_idの有無でメインテーマかサブテーマかを判別できます。`,
  input_schema: checkThemeStatusInputSchema,
  execute: async (args: z.infer<typeof checkThemeStatusInputSchema>) => {
    try {
      const { themeStartId, themeDirectoryPart } = args;
      
      // テーマ状態を取得
      const themeStatus = await getThemeStatus(
        themeStartId,
        themeDirectoryPart,
        args.includeSubthemes
      );
      
      if (!themeStatus) {
        return {
          content: [
            {
              type: 'text' as const,
              text: `指定されたテーマが見つかりませんでした: ${themeStartId}_${themeDirectoryPart}`,
            },
          ],
        };
      }
      
      // JSON形式で結果を生成
      const jsonResult = generateThemeStatusJson(themeStatus);
      
      return {
        content: [
          {
            type: 'text' as const,
            text: JSON.stringify(jsonResult, null, 2),
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text' as const,
            text: `エラーが発生しました: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
      };
    }
  },
} as const;