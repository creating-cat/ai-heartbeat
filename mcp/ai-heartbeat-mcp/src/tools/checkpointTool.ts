import { z } from 'zod';
import fs from 'fs-extra';
import path from 'path';
import { getLatestActivityLogInfo } from '../lib/logUtils';
import { convertTimestampToSeconds } from '../lib/timeUtils';
import { STATS_DIR } from '../lib/pathConstants';

const checkpointInputSchema = z.object({
  current_activity: z.string().min(1, '活動内容を記述してください').describe('簡潔な現在の活動内容（例: 「〇〇の調査中」）'),
});

async function getElapsedTimeMessage(currentHeartbeatId: string): Promise<string> {
  const latestLogInfo = await getLatestActivityLogInfo();
  if (!latestLogInfo) return '';

  const currentTime = convertTimestampToSeconds(currentHeartbeatId);
  const latestLogTime = convertTimestampToSeconds(latestLogInfo.heartbeatId);
  const elapsedSeconds = currentTime - latestLogTime;

  if (elapsedSeconds < 0) return ''; // 未来のログは無視

  const elapsedMinutes = Math.floor(elapsedSeconds / 60);
  let message = `\n最後の活動ログから約${elapsedMinutes}分が経過しています。`;

  const deepWorkDir = path.join(STATS_DIR, 'deep_work');
  const deepWorkFiles = (await fs.pathExists(deepWorkDir))
    ? await fs.readdir(deepWorkDir)
    : [];
  const hasActiveDeepWork = deepWorkFiles.some(
    (f) => f.endsWith('.txt') && !f.endsWith('.completed.txt') && !f.endsWith('.expired.txt')
  );

  if (!hasActiveDeepWork && elapsedMinutes >= 5) {
    message += `\n長時間の集中作業が見込まれる場合は、start_deep_workツールの使用を検討してください。`;
  }
  return message;
}

export const checkpointTool = {
  name: 'checkpoint',
  description: '活動ログを作成するほどではないが、意識的に活動を継続していることを示すためのチェックポイントを作成します。これにより、長時間処理中の無活動エラーを回避できます。',
  input_schema: checkpointInputSchema,
  execute: async (args: z.infer<typeof checkpointInputSchema>) => {
    try {
      const heartbeatIdPath = path.join(STATS_DIR, 'current_heartbeat_id.txt');
      if (!await fs.pathExists(heartbeatIdPath)) {
        throw new Error('ハートビートIDファイルが見つかりません: ' + heartbeatIdPath);
      }
      const heartbeatId = (await fs.readFile(heartbeatIdPath, 'utf-8')).trim();

      const checkpointDir = path.join(STATS_DIR, 'checkpoints');
      await fs.ensureDir(checkpointDir);
      const checkpointFile = path.join(checkpointDir, `${heartbeatId}.txt`);
      await fs.writeFile(checkpointFile, args.current_activity, 'utf-8');

      const elapsedTimeMessage = await getElapsedTimeMessage(heartbeatId);

      return {
        content: [{ type: 'text' as const, text: `チェックポイントを作成しました: ${checkpointFile}${elapsedTimeMessage}` }],
      };
    } catch (error) {
      return {
        content: [
          { type: 'text' as const, text: `エラーが発生しました: ${error instanceof Error ? error.message : String(error)}` },
        ],
      };
    }
  },
};