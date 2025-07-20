// Time utility functions for AI Heartbeat System

/**
 * YYYYMMDDHHMMSS形式のタイムスタンプをUnix秒に変換
 */
export function convertTimestampToSeconds(timestamp: string): number {
  if (!/^\d{14}$/.test(timestamp)) {
    throw new Error(`Invalid timestamp format: ${timestamp}. Expected YYYYMMDDHHMMSS format.`);
  }

  const year = parseInt(timestamp.substring(0, 4));
  const month = parseInt(timestamp.substring(4, 6)) - 1; // 0-based
  const day = parseInt(timestamp.substring(6, 8));
  const hour = parseInt(timestamp.substring(8, 10));
  const minute = parseInt(timestamp.substring(10, 12));
  const second = parseInt(timestamp.substring(12, 14));

  const date = new Date(year, month, day, hour, minute, second);
  return Math.floor(date.getTime() / 1000);
}

