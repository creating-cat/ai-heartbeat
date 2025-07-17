import * as fs from 'fs-extra';

// Default configuration values
const DEFAULT_TIMESTAMP_ANOMALY_THRESHOLD = 900; // 15 minutes in seconds

// Load heartbeat configuration
async function loadTimestampThreshold() {
  try {
    const configPath = 'heartbeat.conf';
    if (await fs.pathExists(configPath)) {
      const configContent = await fs.readFile(configPath, 'utf-8');
      const match = configContent.match(/TIMESTAMP_ANOMALY_THRESHOLD=(\d+)/);
      if (match) {
        return parseInt(match[1], 10);
      }
    }
  } catch (error) {
    // Configuration file not found or error reading, use default
  }
  return DEFAULT_TIMESTAMP_ANOMALY_THRESHOLD;
}

export async function checkTimeDeviation(heartbeatId: string): Promise<string | null> {
  const threshold = await loadTimestampThreshold();
  const now = new Date();

  // ハートビートIDから日時を解析
  const year = parseInt(heartbeatId.substring(0, 4));
  const month = parseInt(heartbeatId.substring(4, 6)) - 1; // 0-based
  const day = parseInt(heartbeatId.substring(6, 8));
  const hour = parseInt(heartbeatId.substring(8, 10));
  const minute = parseInt(heartbeatId.substring(10, 12));
  const second = parseInt(heartbeatId.substring(12, 14));

  const heartbeatTime = new Date(year, month, day, hour, minute, second);
  const diffSeconds = Math.abs(now.getTime() - heartbeatTime.getTime()) / 1000;

  // 閾値の一定割合で段階的警告（heartbeat.shエラー前の早期警告）
  const infoThreshold = threshold * 0.5; // 50%で情報
  const warningThreshold = threshold * 0.75; // 75%で警告
  const criticalThreshold = threshold * 0.9; // 90%で重大

  if (diffSeconds > infoThreshold) {
    const diffMinutes = Math.round(diffSeconds / 60);
    let diffText: string;
    if (diffMinutes >= 60) {
      const hours = Math.floor(diffMinutes / 60);
      const minutes = diffMinutes % 60;
      diffText = minutes > 0 ? `${hours}時間${minutes}分` : `${hours}時間`;
    } else {
      diffText = `${diffMinutes}分`;
    }

    // 警告レベルを決定
    const warningLevel =
      diffSeconds > criticalThreshold
        ? '重大'
        : diffSeconds > warningThreshold
          ? '警告'
          : '情報';

    return `${warningLevel}: ハートビートIDの時刻と現在時刻に ${diffText} の乖離があります。`;
  }

  return null;
}

