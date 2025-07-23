/**
 * Get Heartbeat Elapsed Time Tool
 * ハートビート開始からの経過時間を取得し、段階的な警告・通知を提供するツール
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';
import { convertTimestampToSeconds } from '../lib/timeUtils';
import { EXTENDED_PROCESSING_DIR } from '../lib/pathConstants';

// 処理時間制御の設定（create_activity_logと統一）
const PROCESSING_TIME_CONFIG = {
  infoThreshold: 300,    // 5分で情報通知
  warningThreshold: 600, // 10分で警告（heartbeat.shのエラーレベルと統一）
};

// Zod schema for input
export const getHeartbeatElapsedTimeInputSchema = z.object({
  heartbeatId: z.string()
    .regex(/^\d{14}$/, 'ハートビートIDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります。')
    .describe('YYYYMMDDHHMMSS形式のハートビートID。このIDから開始時刻を解析し、現在時刻との差分を計算します。'),
});

// Output interface (設計仕様に従ったシンプルな形式)
interface GetHeartbeatElapsedTimeOutput {
  elapsedSeconds: number;
  elapsedFormatted: string;
  warningMessage: string | null;
}

/**
 * 未来ハートビートIDの検証
 * @param heartbeatId YYYYMMDDHHMMSS形式のハートビートID
 * @throws Error 未来のハートビートIDの場合
 */
function validateHeartbeatIdTiming(heartbeatId: string): void {
  try {
    const heartbeatTime = convertTimestampToSeconds(heartbeatId);
    const currentTime = Math.floor(Date.now() / 1000);
    const timeDiff = heartbeatTime - currentTime;
    
    // 未来のタイムスタンプは即座にエラー
    if (timeDiff > 0) {
      const futureMinutes = Math.floor(timeDiff / 60);
      const futureSeconds = timeDiff % 60;
      const timeDescription = futureMinutes > 0 
        ? `${futureMinutes}分${futureSeconds}秒`
        : `${futureSeconds}秒`;
      
      throw new Error(
        `未来のハートビートIDは使用できません。\n` +
        `指定されたID（${heartbeatId}）は現在時刻より${timeDescription}未来です。\n` +
        `ハートビートIDは現在時刻またはそれ以前の時刻を使用してください。`
      );
    }
  } catch (error) {
    // convertTimestampToSecondsでエラーが発生した場合は、そのエラーを再スロー
    if (error instanceof Error && error.message.includes('Invalid timestamp format')) {
      throw error;
    }
    // 未来時刻検証エラーの場合もそのまま再スロー
    throw error;
  }
}

/**
 * 経過時間をフォーマット（設計仕様に従った形式）
 */
function formatElapsedTime(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;
  
  if (minutes === 0) {
    return `${remainingSeconds}秒`;
  } else if (remainingSeconds === 0) {
    return `${minutes}分`;
  } else {
    return `${minutes}分${remainingSeconds}秒`;
  }
}

/**
 * 警告メッセージ生成（create_activity_logと完全に同じロジック）
 */
async function generateWarningMessage(heartbeatId: string): Promise<string | null> {
  try {
    const heartbeatTime = convertTimestampToSeconds(heartbeatId);
    const currentTime = Math.floor(Date.now() / 1000);
    const elapsedSeconds = currentTime - heartbeatTime;
    const elapsedMinutes = Math.floor(elapsedSeconds / 60);
    
    // 長時間処理宣言の確認
    const declarationFile = path.join(EXTENDED_PROCESSING_DIR, 'current.conf');
    const hasDeclaration = await fs.pathExists(declarationFile);
    
    if (hasDeclaration) {
      // 宣言中は通常の警告を抑制し、宣言状態を通知
      return `長時間処理宣言中: 宣言により警告が緩和されています。`;
    }
    
    // 通常の警告処理（create_activity_logと統一）
    if (elapsedSeconds >= PROCESSING_TIME_CONFIG.warningThreshold) { // 10分
      return `活動分割推奨: ハートビート開始から${elapsedMinutes}分が経過しています。「小さな一歩」の原則に従い、活動を区切ることを推奨します。`;
    } else if (elapsedSeconds >= PROCESSING_TIME_CONFIG.infoThreshold) { // 5分
      return `経過時間通知: ハートビート開始から${elapsedMinutes}分が経過しています。`;
    }
    
    return null;
  } catch (error) {
    // タイムスタンプ変換エラーの場合は警告を出さない
    return null;
  }
}


export const getHeartbeatElapsedTimeTool = {
  name: 'get_heartbeat_elapsed_time',
  description: 'ハートビート開始からの経過時間を取得し、create_activity_logツールと統一された警告システムを提供します。5分で情報通知、10分で警告が表示されます。長時間処理宣言がある場合は警告が緩和されます。AIの自己認識向上と適切なタイミングでの活動区切り判断を支援します。',
  input_schema: getHeartbeatElapsedTimeInputSchema,
  execute: async (args: z.infer<typeof getHeartbeatElapsedTimeInputSchema>) => {
    try {
      // 未来ハートビートID検証（最優先で実行）
      validateHeartbeatIdTiming(args.heartbeatId);

      // 時刻計算
      const heartbeatTime = convertTimestampToSeconds(args.heartbeatId);
      const currentTime = Math.floor(Date.now() / 1000);
      const elapsedSeconds = currentTime - heartbeatTime;

      // 警告メッセージ生成（create_activity_logと統一）
      const warningMessage = await generateWarningMessage(args.heartbeatId);

      // レスポンス構築（設計仕様に従ったシンプルな形式）
      const result: GetHeartbeatElapsedTimeOutput = {
        elapsedSeconds,
        elapsedFormatted: formatElapsedTime(elapsedSeconds),
        warningMessage,
      };

      // JSON形式でレスポンス（設計仕様通り）
      const responseText = JSON.stringify(result, null, 2);

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