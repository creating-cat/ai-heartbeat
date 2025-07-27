// Time utility functions for AI Heartbeat System

import fs from 'fs-extra';
import path from 'path';
import { CHECKPOINTS_DIR } from './pathConstants';

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

/**
 * 経過時間を人間が読みやすい形式に変換
 */
export function formatElapsedTime(elapsedSeconds: number): string {
  if (elapsedSeconds < 60) {
    return `約${elapsedSeconds}秒`;
  }
  
  const elapsedMinutes = Math.floor(elapsedSeconds / 60);
  if (elapsedMinutes < 60) {
    return `約${elapsedMinutes}分`;
  }
  
  const elapsedHours = Math.floor(elapsedMinutes / 60);
  const remainingMinutes = elapsedMinutes % 60;
  if (remainingMinutes === 0) {
    return `約${elapsedHours}時間`;
  }
  return `約${elapsedHours}時間${remainingMinutes}分`;
}

/**
 * チェックポイント情報の型定義
 */
export interface CheckpointInfo {
  heartbeatId: string;
  message: string;
  timestamp: number;
}

/**
 * 最新のチェックポイント情報を取得
 */
export async function getLatestCheckpointInfo(): Promise<CheckpointInfo | null> {
  try {
    if (!await fs.pathExists(CHECKPOINTS_DIR)) {
      return null;
    }

    const files = await fs.readdir(CHECKPOINTS_DIR);
    const checkpointFiles = files
      .filter(f => f.endsWith('.txt'))
      .map(f => f.replace('.txt', ''))
      .filter(f => /^\d{14}$/.test(f))
      .sort()
      .reverse();

    if (checkpointFiles.length === 0) {
      return null;
    }

    const latestHeartbeatId = checkpointFiles[0];
    const checkpointFile = path.join(CHECKPOINTS_DIR, `${latestHeartbeatId}.txt`);
    const message = await fs.readFile(checkpointFile, 'utf-8');

    return {
      heartbeatId: latestHeartbeatId,
      message: message.trim(),
      timestamp: convertTimestampToSeconds(latestHeartbeatId)
    };
  } catch (error) {
    return null;
  }
}

