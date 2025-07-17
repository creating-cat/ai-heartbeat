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

// JSON output format
interface ThemeStatusJson {
  is_active: boolean;
  theme_name?: string;
  theme_directory_part?: string;
  theme_start_id?: string;
  theme_end_id?: string;
  last_activity_type?: string;
  last_activity_timestamp?: string;
  detailed_stats: {
    total_activities: number;
    total_artifacts: number;
    activity_distribution: { [key: string]: number };
    duration_hours: number;
    time_since_last_activity_hours?: number;
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
 * Get theme information from theme history files
 */
async function getThemeInfoFromHistory(themeStartId: string, themeDirectoryPart: string): Promise<{
  themeName?: string;
  themeEndId?: string;
  isActive: boolean;
}> {
  try {
    const themeHistoriesDir = path.join('artifacts', 'theme_histories');
    
    if (!await fs.pathExists(themeHistoriesDir)) {
      return { isActive: false };
    }
    
    const files = await fs.readdir(themeHistoriesDir);
    
    // Look for start file
    const startFileName = `${themeStartId}_start_${themeDirectoryPart}.md`;
    const startFile = files.find(f => f === startFileName);
    
    let themeName: string | undefined;
    if (startFile) {
      const startContent = await fs.readFile(path.join(themeHistoriesDir, startFile), 'utf-8');
      const nameMatch = startContent.match(/^# テーマ開始: (.+)$/m);
      if (nameMatch) {
        themeName = nameMatch[1];
      }
    }
    
    // Look for end file
    const endFilePattern = new RegExp(`^(\\d{14})_end_${themeDirectoryPart}\\.md$`);
    const endFile = files.find(f => endFilePattern.test(f));
    
    if (endFile) {
      const endMatch = endFile.match(endFilePattern);
      const themeEndId = endMatch ? endMatch[1] : undefined;
      return {
        themeName,
        themeEndId,
        isActive: false
      };
    }
    
    return {
      themeName,
      isActive: true
    };
  } catch (error) {
    return { isActive: false };
  }
}

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

// Function to generate JSON output
function generateJsonOutput(
  themeStartId: string,
  themeDirectoryPart: string,
  themeInfo: { themeName?: string; themeEndId?: string; isActive: boolean },
  basicInfo: ThemeBasicInfo,
  activityStats: ActivityStats,
  artifactStats: ArtifactStats
): ThemeStatusJson {
  const result: ThemeStatusJson = {
    is_active: themeInfo.isActive,
    detailed_stats: {
      total_activities: activityStats.totalCount,
      total_artifacts: artifactStats.totalCount,
      activity_distribution: Object.fromEntries(
        Object.entries(activityStats.typeDistribution).map(([key, value]) => [key, value.count])
      ),
      duration_hours: basicInfo.duration.totalHours
    }
  };
  
  if (themeInfo.isActive) {
    result.theme_name = themeInfo.themeName;
    result.theme_directory_part = themeDirectoryPart;
    result.theme_start_id = themeStartId;
    
    if (activityStats.lastActivity) {
      result.last_activity_timestamp = activityStats.lastActivity;
      
      // Extract activity type from the most recent activity
      if (activityStats.recentPattern.length > 0) {
        result.last_activity_type = activityStats.recentPattern[0].activityType;
      }
    }
  } else if (themeInfo.themeEndId) {
    result.theme_end_id = themeInfo.themeEndId;
  }
  
  if (activityStats.timeSinceLastActivity) {
    result.detailed_stats.time_since_last_activity_hours = activityStats.timeSinceLastActivity.hours + (activityStats.timeSinceLastActivity.minutes / 60);
  }
  
  return result;
}

export const checkThemeStatusTool = {
  name: 'check_theme_status',
  description: `指定されたテーマの現在の状態と統計情報をJSON形式で分析・返却します。

返却されるJSONフィールド:
- is_active (boolean): テーマが現在アクティブ（進行中）かどうか
- theme_name (string, optional): テーマの正式名称（is_activeがtrueの場合）
- theme_directory_part (string, optional): ディレクトリ名の一部（is_activeがtrueの場合）
- theme_start_id (string, optional): テーマ開始時のハートビートID（is_activeがtrueの場合）
- theme_end_id (string, optional): テーマ終了時のハートビートID（is_activeがfalseかつ終了済みの場合）
- last_activity_type (string, optional): 最後に記録された活動の種別（is_activeがtrueの場合）
- last_activity_timestamp (string, optional): 最後の活動のタイムスタンプ（is_activeがtrueの場合）
- detailed_stats (object): 詳細統計情報
  - total_activities (number): 総活動数
  - total_artifacts (number): 総成果物数
  - activity_distribution (object): 活動種別ごとの件数
  - duration_hours (number): テーマの継続時間（時間単位）
  - time_since_last_activity_hours (number, optional): 最終活動からの経過時間（時間単位）

テーマの進捗状況や完了度を客観的に評価するために使用します。`,
  input_schema: checkThemeStatusInputSchema,
  execute: async (args: z.infer<typeof checkThemeStatusInputSchema>) => {
    try {
      const { themeStartId, themeDirectoryPart } = args;
      
      // Sanitize directory part
      const sanitizedDirectoryPart = path.basename(themeDirectoryPart);
      const themeDirectoryName = `${themeStartId}_${sanitizedDirectoryPart}`;
      const themeDirectoryPath = path.join('artifacts', themeDirectoryName);
      const historiesDirectoryPath = path.join(themeDirectoryPath, 'histories');
      
      // Get theme information from history files
      const themeInfo = await getThemeInfoFromHistory(themeStartId, sanitizedDirectoryPart);
      
      // Check basic theme info
      const themeExists = await fs.pathExists(themeDirectoryPath);
      if (!themeExists) {
        return {
          content: [
            {
              type: 'text' as const,
              text: JSON.stringify({
                is_active: false,
                error: 'Theme directory not found',
                theme_start_id: themeStartId,
                theme_directory_part: sanitizedDirectoryPart,
                detailed_stats: {
                  total_activities: 0,
                  total_artifacts: 0,
                  activity_distribution: {},
                  duration_hours: 0
                }
              }, null, 2),
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
        
        activityStats = analyzeActivityStats(parseResult.successful, 10);
        artifactStats = analyzeArtifactStats(parseResult.successful);
      } else {
        // No activities yet
        activityStats = analyzeActivityStats([], 10);
        artifactStats = analyzeArtifactStats([]);
      }
      
      // Generate JSON output
      const jsonOutput = generateJsonOutput(
        themeStartId,
        sanitizedDirectoryPart,
        themeInfo,
        basicInfo,
        activityStats,
        artifactStats
      );
      
      return {
        content: [
          {
            type: 'text' as const,
            text: JSON.stringify(jsonOutput, null, 2),
          },
        ],
      };
      
    } catch (error) {
      return {
        content: [
          {
            type: 'text' as const,
            text: JSON.stringify({
              is_active: false,
              error: error instanceof Error ? error.message : String(error),
              detailed_stats: {
                total_activities: 0,
                total_artifacts: 0,
                activity_distribution: {},
                duration_hours: 0
              }
            }, null, 2),
          },
        ],
      };
    }
  },
} as const;