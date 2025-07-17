/**
 * Check Theme Status Tool
 * Analyzes the current status and statistics of a specific theme
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';
import { 
  parseActivityLogDirectory, 
  ActivityLogInfo,
  parseHeartbeatIdToDate 
} from '../lib/activityLogParser';

// Zod schema for check theme status input
export const checkThemeStatusInputSchema = z.object({
  themeStartId: z.string()
    .regex(/^\d{14}$/, 'THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .describe('テーマ開始時のハートビートID'),
  themeDirectoryPart: z.string()
    .describe('テーマディレクトリ名の一部。THEME_START_IDと組み合わせて "{THEME_START_ID}_{themeDirectoryPart}" の形式でテーマディレクトリが特定されます'),
  includeDetailedStats: z.boolean()
    .optional()
    .default(true)
    .describe('詳細な統計情報を含めるか（false の場合は基本情報のみ）'),
  recentActivityCount: z.number()
    .int()
    .min(3)
    .max(20)
    .optional()
    .default(10)
    .describe('直近の活動パターン分析に使用する活動数'),
});

// Types for theme status analysis
interface ThemeBasicInfo {
  exists: boolean;
  themeDirectory: string;
  startTimestamp: string;
  startDate: Date;
  isActive: boolean;
  endTimestamp?: string;
  endDate?: Date;
  duration: {
    days: number;
    hours: number;
    minutes: number;
    totalHours: number;
    humanReadable: string;
  };
}

interface ActivityStats {
  totalCount: number;
  firstActivity?: string;
  lastActivity?: string;
  timeSinceLastActivity?: {
    hours: number;
    minutes: number;
    humanReadable: string;
  };
  typeDistribution: {
    [key: string]: {
      count: number;
      percentage: number;
      lastOccurrence?: string;
    };
  };
  recentPattern: Array<{
    heartbeatId: string;
    activityType: string;
    timestamp: Date;
  }>;
  frequencyAnalysis: {
    averageInterval: number; // in minutes
    isRegular: boolean;
    lastGap: number; // minutes since last activity
  };
}

interface ArtifactStats {
  totalCount: number;
  fileTypes: {
    [extension: string]: {
      count: number;
      files: string[];
    };
  };
  recentArtifacts: Array<{
    filename: string;
    heartbeatId: string;
  }>;
  productivityTrend: {
    artifactsPerActivity: number;
    mostProductiveActivityType: string;
  };
}

// Helper functions

/**
 * Check if theme is active (no end log exists)
 */
async function checkThemeActiveStatus(themeStartId: string, themeDirectoryPart: string): Promise<{
  isActive: boolean;
  endTimestamp?: string;
  endDate?: Date;
}> {
  const themeHistoriesDir = path.join('artifacts', 'theme_histories');
  
  if (!await fs.pathExists(themeHistoriesDir)) {
    return { isActive: true }; // No theme histories directory means active
  }
  
  try {
    const files = await fs.readdir(themeHistoriesDir);
    
    // Look for end log: *_end_*.md files that match our theme
    const endLogPattern = new RegExp(`\\d{14}_end_${themeDirectoryPart}\\.md$`);
    const endLogFiles = files.filter(file => endLogPattern.test(file));
    
    // Check if any end log corresponds to our theme start ID
    for (const endLogFile of endLogFiles) {
      const content = await fs.readFile(path.join(themeHistoriesDir, endLogFile), 'utf-8');
      
      // Check if this end log references our theme start ID
      if (content.includes(`**THEME_START_ID**: ${themeStartId}`)) {
        // Extract end timestamp from filename
        const endTimestampMatch = endLogFile.match(/^(\d{14})_end_/);
        if (endTimestampMatch) {
          const endTimestamp = endTimestampMatch[1];
          return {
            isActive: false,
            endTimestamp,
            endDate: parseHeartbeatIdToDate(endTimestamp)
          };
        }
      }
    }
  } catch (error) {
    console.warn('Error checking theme active status:', error);
  }
  
  return { isActive: true };
}

/**
 * Calculate duration between two dates
 */
function calculateDuration(startDate: Date, endDate: Date = new Date()): ThemeBasicInfo['duration'] {
  const diffMs = endDate.getTime() - startDate.getTime();
  const totalMinutes = Math.floor(diffMs / (1000 * 60));
  const totalHours = Math.floor(totalMinutes / 60);
  const days = Math.floor(totalHours / 24);
  const hours = totalHours % 24;
  const minutes = totalMinutes % 60;
  
  let humanReadable = '';
  if (days > 0) humanReadable += `${days}日`;
  if (hours > 0) humanReadable += `${hours}時間`;
  if (minutes > 0) humanReadable += `${minutes}分`;
  if (humanReadable === '') humanReadable = '1分未満';
  
  return {
    days,
    hours,
    minutes,
    totalHours,
    humanReadable
  };
}

/**
 * Analyze activity statistics
 */
function analyzeActivityStats(activities: ActivityLogInfo[], recentCount: number): ActivityStats {
  if (activities.length === 0) {
    return {
      totalCount: 0,
      typeDistribution: {},
      recentPattern: [],
      frequencyAnalysis: {
        averageInterval: 0,
        isRegular: false,
        lastGap: 0
      }
    };
  }
  
  // Sort by timestamp (newest first)
  const sortedActivities = [...activities].sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());
  
  const firstActivity = sortedActivities[sortedActivities.length - 1];
  const lastActivity = sortedActivities[0];
  
  // Calculate time since last activity
  const now = new Date();
  const timeSinceLastMs = now.getTime() - lastActivity.timestamp.getTime();
  const timeSinceLastMinutes = Math.floor(timeSinceLastMs / (1000 * 60));
  const timeSinceLastHours = Math.floor(timeSinceLastMinutes / 60);
  
  // Activity type distribution
  const typeDistribution: ActivityStats['typeDistribution'] = {};
  const typeLastOccurrence: { [key: string]: string } = {};
  
  for (const activity of activities) {
    const type = activity.activityType;
    if (!typeDistribution[type]) {
      typeDistribution[type] = { count: 0, percentage: 0 };
    }
    typeDistribution[type].count++;
    
    // Track last occurrence (most recent timestamp for each type)
    if (!typeLastOccurrence[type] || activity.timestamp.getTime() > parseHeartbeatIdToDate(typeLastOccurrence[type]).getTime()) {
      typeLastOccurrence[type] = activity.heartbeatId;
    }
  }
  
  // Calculate percentages and add last occurrence
  for (const type in typeDistribution) {
    typeDistribution[type].percentage = Math.round((typeDistribution[type].count / activities.length) * 100);
    typeDistribution[type].lastOccurrence = typeLastOccurrence[type];
  }
  
  // Recent activity pattern
  const recentPattern = sortedActivities
    .slice(0, Math.min(recentCount, activities.length))
    .reverse() // Show chronological order (oldest to newest)
    .map(activity => ({
      heartbeatId: activity.heartbeatId,
      activityType: activity.activityType,
      timestamp: activity.timestamp
    }));
  
  // Frequency analysis
  let averageInterval = 0;
  let isRegular = false;
  
  if (activities.length > 1) {
    const intervals: number[] = [];
    for (let i = 1; i < sortedActivities.length; i++) {
      const intervalMs = sortedActivities[i - 1].timestamp.getTime() - sortedActivities[i].timestamp.getTime();
      intervals.push(intervalMs / (1000 * 60)); // Convert to minutes
    }
    
    averageInterval = intervals.reduce((sum, interval) => sum + interval, 0) / intervals.length;
    
    // Check regularity (coefficient of variation < 0.5 indicates regular pattern)
    const mean = averageInterval;
    const variance = intervals.reduce((sum, interval) => sum + Math.pow(interval - mean, 2), 0) / intervals.length;
    const stdDev = Math.sqrt(variance);
    const coefficientOfVariation = stdDev / mean;
    isRegular = coefficientOfVariation < 0.5;
  }
  
  return {
    totalCount: activities.length,
    firstActivity: firstActivity.heartbeatId,
    lastActivity: lastActivity.heartbeatId,
    timeSinceLastActivity: {
      hours: timeSinceLastHours,
      minutes: timeSinceLastMinutes % 60,
      humanReadable: timeSinceLastHours > 0 ? `${timeSinceLastHours}時間${timeSinceLastMinutes % 60}分前` : `${timeSinceLastMinutes}分前`
    },
    typeDistribution,
    recentPattern,
    frequencyAnalysis: {
      averageInterval: Math.round(averageInterval),
      isRegular,
      lastGap: timeSinceLastMinutes
    }
  };
}

/**
 * Analyze artifact statistics
 */
function analyzeArtifactStats(activities: ActivityLogInfo[]): ArtifactStats {
  const allArtifacts: Array<{ filename: string; heartbeatId: string; activityType: string }> = [];
  const fileTypes: { [extension: string]: { count: number; files: string[] } } = {};
  const activityTypeArtifactCount: { [type: string]: number } = {};
  
  for (const activity of activities) {
    const artifactCount = activity.artifacts.length;
    activityTypeArtifactCount[activity.activityType] = (activityTypeArtifactCount[activity.activityType] || 0) + artifactCount;
    
    for (const artifact of activity.artifacts) {
      allArtifacts.push({
        filename: artifact,
        heartbeatId: activity.heartbeatId,
        activityType: activity.activityType
      });
      
      // Extract file extension
      const ext = path.extname(artifact).toLowerCase() || '.txt';
      if (!fileTypes[ext]) {
        fileTypes[ext] = { count: 0, files: [] };
      }
      fileTypes[ext].count++;
      fileTypes[ext].files.push(artifact);
    }
  }
  
  // Sort artifacts by heartbeat ID (newest first) and take recent ones
  const sortedArtifacts = allArtifacts.sort((a, b) => b.heartbeatId.localeCompare(a.heartbeatId));
  const recentArtifacts = sortedArtifacts.slice(0, 5).map(artifact => ({
    filename: artifact.filename,
    heartbeatId: artifact.heartbeatId
  }));
  
  // Find most productive activity type
  let mostProductiveActivityType = 'なし';
  let maxArtifactCount = 0;
  for (const [type, count] of Object.entries(activityTypeArtifactCount)) {
    if (count > maxArtifactCount) {
      maxArtifactCount = count;
      mostProductiveActivityType = type;
    }
  }
  
  const artifactsPerActivity = activities.length > 0 ? allArtifacts.length / activities.length : 0;
  
  return {
    totalCount: allArtifacts.length,
    fileTypes,
    recentArtifacts,
    productivityTrend: {
      artifactsPerActivity: Math.round(artifactsPerActivity * 100) / 100,
      mostProductiveActivityType
    }
  };
}

export const checkThemeStatusTool = {
  name: 'check_theme_status',
  description: '指定されたテーマの現在の状態（進行中/終了済み、活動統計、成果物情報など）を分析・報告します。テーマの継続判断や活動パターンの把握に有用です。',
  input_schema: checkThemeStatusInputSchema,
  execute: async (args: z.infer<typeof checkThemeStatusInputSchema>) => {
    try {
      const { themeStartId, themeDirectoryPart, includeDetailedStats, recentActivityCount } = args;
      
      // Sanitize directory part
      const sanitizedDirectoryPart = path.basename(themeDirectoryPart);
      const themeDirectoryName = `${themeStartId}_${sanitizedDirectoryPart}`;
      const themeDirectoryPath = path.join('artifacts', themeDirectoryName);
      const historiesDirectoryPath = path.join(themeDirectoryPath, 'histories');
      
      // Check basic theme info
      const themeExists = await fs.pathExists(themeDirectoryPath);
      if (!themeExists) {
        return {
          content: [
            {
              type: 'text' as const,
              text: `❌ テーマが存在しません: ${themeDirectoryName}\n\n指定されたテーマディレクトリが見つかりませんでした。\nTHEME_START_ID: ${themeStartId}\nテーマ名: ${sanitizedDirectoryPart}`,
            },
          ],
        };
      }
      
      // Get theme basic info
      const startDate = parseHeartbeatIdToDate(themeStartId);
      const activeStatus = await checkThemeActiveStatus(themeStartId, sanitizedDirectoryPart);
      const endDate = activeStatus.endDate || new Date();
      const duration = calculateDuration(startDate, activeStatus.isActive ? undefined : activeStatus.endDate);
      
      const basicInfo: ThemeBasicInfo = {
        exists: true,
        themeDirectory: themeDirectoryName,
        startTimestamp: themeStartId,
        startDate,
        isActive: activeStatus.isActive,
        endTimestamp: activeStatus.endTimestamp,
        endDate: activeStatus.endDate,
        duration
      };
      
      // Parse activity logs
      let activityStats: ActivityStats;
      let artifactStats: ArtifactStats;
      
      if (await fs.pathExists(historiesDirectoryPath)) {
        const parseResult = await parseActivityLogDirectory(historiesDirectoryPath, { sortByTime: true });
        
        if (parseResult.failed.length > 0) {
          console.warn(`Warning: ${parseResult.failed.length} activity logs failed to parse`);
        }
        
        activityStats = analyzeActivityStats(parseResult.successful, recentActivityCount);
        artifactStats = analyzeArtifactStats(parseResult.successful);
      } else {
        // No activities yet
        activityStats = analyzeActivityStats([], recentActivityCount);
        artifactStats = analyzeArtifactStats([]);
      }
      
      // Generate response
      let responseText = '';
      
      if (includeDetailedStats) {
        // Detailed format
        responseText = `📊 テーマ状態レポート: ${sanitizedDirectoryPart} (${themeStartId})

🔄 基本情報:
  ✅ テーマ存在: はい
  ${basicInfo.isActive ? '🟢 状態: 進行中' : '🔴 状態: 終了済み'}
  📅 開始: ${startDate.toLocaleString('ja-JP')}
  ${!basicInfo.isActive && basicInfo.endDate ? `🏁 終了: ${basicInfo.endDate.toLocaleString('ja-JP')}` : ''}
  ⏱️ ${basicInfo.isActive ? '継続期間' : '総期間'}: ${duration.humanReadable}`;

        if (activityStats.totalCount > 0) {
          responseText += `

📈 活動統計 (総${activityStats.totalCount}件):
  🕐 最終活動: ${parseHeartbeatIdToDate(activityStats.lastActivity!).toLocaleString('ja-JP')} (${activityStats.timeSinceLastActivity!.humanReadable})
  📊 平均間隔: ${activityStats.frequencyAnalysis.averageInterval}分
  ${activityStats.frequencyAnalysis.isRegular ? '✅ 規則的な活動パターン' : '⚠️ 不規則な活動パターン'}
  
  種別内訳:`;
          
          for (const [type, stats] of Object.entries(activityStats.typeDistribution)) {
            const lastOccurrence = stats.lastOccurrence ? parseHeartbeatIdToDate(stats.lastOccurrence) : null;
            const timeAgo = lastOccurrence ? calculateDuration(lastOccurrence).humanReadable + '前' : '不明';
            responseText += `\n  - ${type}: ${stats.count}件 (${stats.percentage}%) - 最終: ${timeAgo}`;
          }
          
          responseText += `\n  
  📋 直近パターン (${activityStats.recentPattern.length}件):
  ${activityStats.recentPattern.map(p => p.activityType).join(' → ')}`;
        } else {
          responseText += `

📈 活動統計:
  ℹ️ まだ活動ログが記録されていません`;
        }

        if (artifactStats.totalCount > 0) {
          responseText += `

🎯 成果物 (総${artifactStats.totalCount}件):
  📄 ファイル種別: ${Object.entries(artifactStats.fileTypes).map(([ext, info]) => `${ext}(${info.count})`).join(', ')}
  🆕 最新成果物:`;
          
          for (const artifact of artifactStats.recentArtifacts.slice(0, 3)) {
            responseText += `\n    - ${artifact.filename} (${artifact.heartbeatId})`;
          }
          
          responseText += `\n  
  📊 生産性: 平均${artifactStats.productivityTrend.artifactsPerActivity}件/活動
  🏆 最も生産的: ${artifactStats.productivityTrend.mostProductiveActivityType}活動`;
        } else {
          responseText += `

🎯 成果物:
  ℹ️ まだ成果物が記録されていません`;
        }

        // Analysis and recommendations
        responseText += `

💡 分析・推奨:`;
        
        if (activityStats.totalCount === 0) {
          responseText += `\n  📝 テーマが開始されましたが、まだ活動が記録されていません`;
          responseText += `\n  💡 次回推奨: 思考活動でテーマの方向性を検討`;
        } else {
          // Activity balance analysis
          const typeCount = Object.keys(activityStats.typeDistribution).length;
          if (typeCount >= 3) {
            responseText += `\n  ✅ バランスの良い活動パターン (${typeCount}種類の活動)`;
          } else {
            responseText += `\n  ⚠️ 活動種別が少なめ (${typeCount}種類) - 多様な活動を推奨`;
          }
          
          // Frequency analysis
          if (activityStats.frequencyAnalysis.lastGap > 240) { // 4 hours
            responseText += `\n  ⏰ 最終活動から${activityStats.timeSinceLastActivity!.humanReadable}経過 - 活動再開を推奨`;
          } else if (activityStats.frequencyAnalysis.isRegular) {
            responseText += `\n  ✅ 定期的な活動継続`;
          }
          
          // Activity type recommendations
          const introspectionCount = activityStats.typeDistribution['内省']?.count || 0;
          const introspectionPercentage = activityStats.typeDistribution['内省']?.percentage || 0;
          if (introspectionPercentage < 15 && activityStats.totalCount >= 5) {
            responseText += `\n  💭 内省活動が少なめ (${introspectionPercentage}%) - 振り返りを推奨`;
          }
          
          // Productivity analysis
          if (artifactStats.productivityTrend.artifactsPerActivity > 0.5) {
            responseText += `\n  🎯 高い生産性 (${artifactStats.productivityTrend.artifactsPerActivity}件/活動)`;
          }
        }
        
      } else {
        // Simple format
        responseText = `📊 テーマ状態: ${sanitizedDirectoryPart} (${themeStartId})

🔄 状態: ${basicInfo.isActive ? '進行中' : '終了済み'} (${duration.humanReadable})
📝 活動: ${activityStats.totalCount}件${activityStats.lastActivity ? ` (最終: ${activityStats.timeSinceLastActivity!.humanReadable})` : ''}
🎯 成果物: ${artifactStats.totalCount}件`;
      }
      
      return {
        content: [
          {
            type: 'text' as const,
            text: responseText,
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