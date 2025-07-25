import fs from 'fs-extra';
import path from 'path';
import { glob } from 'glob';
import { ARTIFACTS_DIR } from './pathConstants';

interface LogInfo {
  heartbeatId: string;
  filePath: string;
}

export async function getLatestActivityLogInfo(): Promise<LogInfo | null> {
  if (!(await fs.pathExists(ARTIFACTS_DIR))) {
    return null;
  }

  const logFiles = await glob(`${ARTIFACTS_DIR}/**/histories/*.md`);

  if (logFiles.length === 0) {
    return null;
  }

  let latestLog: LogInfo | null = null;

  for (const filePath of logFiles) {
    const logFile = path.basename(filePath);
    const heartbeatId = logFile.replace('.md', '').split('_')[0];
    if (/^\d{14}$/.test(heartbeatId)) {
      if (!latestLog || heartbeatId > latestLog.heartbeatId) {
        latestLog = { heartbeatId, filePath };
      }
    }
  }

  return latestLog;
}