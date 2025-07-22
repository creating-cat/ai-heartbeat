/**
 * Activity Log Parser Library
 * Common utilities for parsing and analyzing activity log files
 */

import * as fs from 'fs-extra';
import * as path from 'path';

// Types and interfaces
export interface ActivityLogInfo {
  heartbeatId: string;
  activityType: string;
  activityContent: string[];
  artifacts: string[];
  evaluation: string;
  timestamp: Date;
  filename: string;
  sequence: number | null;
}

export interface FileNameInfo {
  heartbeatId: string;
  sequence: number | null;
  timestamp: Date;
  filename: string;
}

export interface ParsedActivityType {
  baseType: string;
  rawText: string;
}

export interface ValidationResult {
  isValid: boolean;
  errors: string[];
  warnings: string[];
}

// Core parsing functions

/**
 * Parse heartbeat ID to Date object
 */
export function parseHeartbeatIdToDate(heartbeatId: string): Date {
  if (!/^\d{14}$/.test(heartbeatId)) {
    throw new Error(`Invalid heartbeat ID format: ${heartbeatId}`);
  }
  
  const year = parseInt(heartbeatId.substring(0, 4));
  const month = parseInt(heartbeatId.substring(4, 6)) - 1; // 0-based
  const day = parseInt(heartbeatId.substring(6, 8));
  const hour = parseInt(heartbeatId.substring(8, 10));
  const minute = parseInt(heartbeatId.substring(10, 12));
  const second = parseInt(heartbeatId.substring(12, 14));
  
  return new Date(year, month, day, hour, minute, second);
}

/**
 * Parse activity log filename to extract metadata
 */
export function parseActivityLogFileName(filename: string): FileNameInfo | null {
  // Basic format: 20250115143000.md
  const basicMatch = filename.match(/^(\d{14})\.md$/);
  if (basicMatch) {
    const heartbeatId = basicMatch[1];
    return {
      heartbeatId,
      sequence: null,
      timestamp: parseHeartbeatIdToDate(heartbeatId),
      filename
    };
  }
  
  // Sequence format: 20250115143000_01.md
  const sequenceMatch = filename.match(/^(\d{14})_(\d{2})\.md$/);
  if (sequenceMatch) {
    const heartbeatId = sequenceMatch[1];
    return {
      heartbeatId,
      sequence: parseInt(sequenceMatch[2], 10),
      timestamp: parseHeartbeatIdToDate(heartbeatId),
      filename
    };
  }
  
  return null;
}

/**
 * Extract a specific section from markdown content
 */
export function extractSection(lines: string[], sectionHeader: string): string {
  const startIndex = lines.findIndex(line => line.trim() === sectionHeader);
  if (startIndex === -1) return '';
  
  // Find next section (line starting with ##)
  const endIndex = lines.findIndex((line, index) => 
    index > startIndex && line.trim().startsWith('## ')
  );
  
  const sectionLines = endIndex === -1 
    ? lines.slice(startIndex + 1)  // Last section
    : lines.slice(startIndex + 1, endIndex);
  
  return sectionLines
    .map(line => line.trim())
    .filter(line => line.length > 0)
    .join('\n');
}

/**
 * Extract list items from a markdown section
 */
export function extractListItems(lines: string[], sectionHeader: string): string[] {
  const sectionContent = extractSection(lines, sectionHeader);
  if (!sectionContent) return [];
  
  return sectionContent
    .split('\n')
    .filter(line => line.startsWith('- '))
    .map(line => line.substring(2).trim())
    .filter(item => item.length > 0 && item !== 'なし');
}

/**
 * Parse activity type
 */
export function parseActivityType(activityTypeText: string): ParsedActivityType {
  if (!activityTypeText) {
    return {
      baseType: 'その他',
      rawText: activityTypeText
    };
  }
  
  // Extract base type (everything before parentheses, or the whole text if no parentheses)
  const baseTypeMatch = activityTypeText.match(/^([^(]+)/);
  const baseType = baseTypeMatch?.[1]?.trim() || activityTypeText.trim() || 'その他';
  
  return {
    baseType,
    rawText: activityTypeText
  };
}

/**
 * Validate activity log structure
 */
export function validateActivityLogStructure(content: string): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];
  
  // Check required sections
  const requiredSections = [
    '# ハートビートログ：',
    '## 活動種別',
    '## 活動内容',
    '## 成果物、関連ファイル',
    '## 自己評価、備考'
  ];
  
  for (const section of requiredSections) {
    if (!content.includes(section)) {
      errors.push(`必須セクションが見つかりません: ${section}`);
    }
  }
  
  // Validate heartbeat ID format
  const heartbeatIdMatch = content.match(/# ハートビートログ：(\d{14})/);
  if (!heartbeatIdMatch) {
    errors.push('ハートビートIDが正しい形式ではありません');
  }
  
  // Validate activity type
  const validActivityTypes = ['観測', '思考', '創造', '内省', 'テーマ開始', 'テーマ終了', '回復', 'その他'];
  const lines = content.split('\n');
  const activityTypeSection = extractSection(lines, '## 活動種別');
  const { baseType } = parseActivityType(activityTypeSection);
  
  if (!validActivityTypes.includes(baseType)) {
    warnings.push(`未知の活動種別: ${baseType}`);
  }
  
  return {
    isValid: errors.length === 0,
    errors,
    warnings
  };
}

/**
 * Parse complete activity log file
 */
export async function parseActivityLogFile(filePath: string): Promise<ActivityLogInfo> {
  const filename = path.basename(filePath);
  const fileInfo = parseActivityLogFileName(filename);
  
  if (!fileInfo) {
    throw new Error(`Invalid activity log filename: ${filename}`);
  }
  
  // Read file content
  const content = await fs.readFile(filePath, 'utf-8');
  
  // Validate structure
  const validation = validateActivityLogStructure(content);
  if (!validation.isValid) {
    throw new Error(`Invalid activity log structure: ${validation.errors.join(', ')}`);
  }
  
  const lines = content.split('\n');
  
  // Extract heartbeat ID from content (double-check with filename)
  const heartbeatIdMatch = content.match(/# ハートビートログ：(\d{14})/);
  const contentHeartbeatId = heartbeatIdMatch?.[1];
  
  if (contentHeartbeatId && contentHeartbeatId !== fileInfo.heartbeatId) {
    throw new Error(`Heartbeat ID mismatch: filename(${fileInfo.heartbeatId}) vs content(${contentHeartbeatId})`);
  }
  
  // Extract activity type
  const activityTypeSection = extractSection(lines, '## 活動種別');
  const { baseType: activityType } = parseActivityType(activityTypeSection);
  
  // Extract activity content
  const activityContent = extractListItems(lines, '## 活動内容');
  
  // Extract artifacts
  const artifacts = extractListItems(lines, '## 成果物、関連ファイル');
  
  // Extract evaluation
  const evaluation = extractSection(lines, '## 自己評価、備考');
  
  return {
    heartbeatId: fileInfo.heartbeatId,
    activityType,
    activityContent,
    artifacts,
    evaluation,
    timestamp: fileInfo.timestamp,
    filename: fileInfo.filename,
    sequence: fileInfo.sequence
  };
}

/**
 * Parse multiple activity log files in a directory
 */
export async function parseActivityLogDirectory(
  historiesDir: string,
  options: {
    sortByTime?: boolean;
    includeInvalid?: boolean;
  } = {}
): Promise<{
  successful: ActivityLogInfo[];
  failed: Array<{ filename: string; error: string; }>;
  warnings: Array<{ filename: string; warnings: string[]; }>;
}> {
  
  const result = {
    successful: [] as ActivityLogInfo[],
    failed: [] as Array<{ filename: string; error: string; }>,
    warnings: [] as Array<{ filename: string; warnings: string[]; }>
  };
  
  // Check if directory exists
  if (!await fs.pathExists(historiesDir)) {
    throw new Error(`Histories directory does not exist: ${historiesDir}`);
  }
  
  // Read directory
  const files = await fs.readdir(historiesDir);
  
  // Filter activity log files
  const activityFiles = files
    .filter(file => file.endsWith('.md'))
    .filter(file => parseActivityLogFileName(file) !== null);
  
  // Process files
  for (const file of activityFiles) {
    const filePath = path.join(historiesDir, file);
    
    try {
      const activityInfo = await parseActivityLogFile(filePath);
      result.successful.push(activityInfo);
      
      // Check for warnings
      const content = await fs.readFile(filePath, 'utf-8');
      const validation = validateActivityLogStructure(content);
      if (validation.warnings.length > 0) {
        result.warnings.push({
          filename: file,
          warnings: validation.warnings
        });
      }
      
    } catch (error) {
      result.failed.push({
        filename: file,
        error: error instanceof Error ? error.message : String(error)
      });
    }
  }
  
  // Sort by time if requested
  if (options.sortByTime) {
    result.successful.sort((a, b) => {
      const timeComparison = b.timestamp.getTime() - a.timestamp.getTime(); // Newest first
      if (timeComparison !== 0) return timeComparison;
      
      // If same timestamp, sort by sequence (higher sequence = newer)
      const seqA = a.sequence ?? 0;
      const seqB = b.sequence ?? 0;
      return seqB - seqA;
    });
  }
  
  return result;
}