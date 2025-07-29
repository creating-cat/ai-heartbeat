import { z } from 'zod';
import fs from 'fs-extra';
import path from 'path';
import { getLatestActivityLogInfo } from '../lib/logUtils';
import { getCurrentTimestamp, getFileModificationTime, formatElapsedTime, getLatestCheckpointInfo } from '../lib/timeUtils';
import { STATS_DIR, CHECKPOINTS_DIR } from '../lib/pathConstants';

const checkpointInputSchema = z.object({
  message: z.string().min(1, 'メッセージを記述してください').describe('このチェックポイントの状況を表すメッセージ。作業の開始・完了・進捗・現在の活動内容など（例: 「データベース設計開始」「分析完了」「複雑な問題の調査中」）'),
});

async function getElapsedTimeMessage(currentHeartbeatId: string): Promise<string> {
  const currentTime = getCurrentTimestamp(); // 実際の現在時刻を使用
  let message = '';

  // 最後の活動ログからの経過時間
  const latestLogInfo = await getLatestActivityLogInfo();
  if (latestLogInfo) {
    const latestLogTime = await getFileModificationTime(latestLogInfo.filePath);
    const elapsedSeconds = currentTime - latestLogTime;

    if (elapsedSeconds > 0) { // 0秒の場合は表示しない
      message += `\n最後の活動ログから${formatElapsedTime(elapsedSeconds)}が経過しています。`;
    }
  }

  // 前回チェックポイントからの経過時間
  try {
    const latestCheckpoint = await getLatestCheckpointInfo(currentHeartbeatId);
    if (latestCheckpoint) {
      const checkpointFile = path.join(CHECKPOINTS_DIR, `${latestCheckpoint.heartbeatId}.txt`);
      const checkpointTime = await getFileModificationTime(checkpointFile);
      const elapsedSeconds = currentTime - checkpointTime;

      if (elapsedSeconds > 30) { // 30秒以上経過した場合のみ表示
        message += `\n前回のチェックポイントから${formatElapsedTime(elapsedSeconds)}が経過しています。`;
        message += `\n前回のメッセージ: ${latestCheckpoint.message}`;
      } else if (elapsedSeconds > 0) {
        message += `\n最近チェックポイントを作成しました。`;
      } else {
        message += `\n時刻計算に異常があります（前回チェックポイント: ${latestCheckpoint.heartbeatId}）。`;
      }
    } else {
      message += `\n初回のチェックポイントです。`;
    }
  } catch (error) {
    message += `\n前回のチェックポイント情報の取得に失敗しました。`;
  }

  // Deep Work推奨メッセージ
  const deepWorkDir = path.join(STATS_DIR, 'deep_work');
  const deepWorkFiles = (await fs.pathExists(deepWorkDir))
    ? await fs.readdir(deepWorkDir)
    : [];
  const hasActiveDeepWork = deepWorkFiles.some(
    (f) => f.endsWith('.txt') && !f.endsWith('.completed.txt') && !f.endsWith('.expired.txt')
  );

  if (!hasActiveDeepWork && latestLogInfo) {
    const latestLogTime = await getFileModificationTime(latestLogInfo.filePath);
    const elapsedSeconds = currentTime - latestLogTime;
    const elapsedMinutes = Math.floor(elapsedSeconds / 60);

    if (elapsedMinutes >= 5) {
      message += `\n\n長時間の集中作業が見込まれる場合は、start_deep_workツールの使用を検討してください。`;
    }
  }

  return message;
}

export const checkpointTool = {
  name: 'checkpoint',
  description: '活動の継続を示すチェックポイントを作成します。処理時間の測定、作業の区切り、長時間処理中の活動証明に使用できます。これにより無活動エラーを回避し、作業効率の分析も可能になります。',
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
      await fs.writeFile(checkpointFile, args.message, 'utf-8');

      const elapsedTimeMessage = await getElapsedTimeMessage(heartbeatId);

      return {
        content: [{
          type: 'text' as const,
          text: `チェックポイントを作成しました\nハートビートID: ${heartbeatId}\nファイル: ${checkpointFile}${elapsedTimeMessage}`
        }],
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