/**
 * Activity Log Creation Tool
 */

import { z } from 'zod';
import * as fs from 'fs-extra';
import * as path from 'path';

import { getCurrentTimestamp, getFileModificationTime, formatElapsedTime, getLatestCheckpointInfo } from '../lib/timeUtils';
import { resolveThemePath } from '../lib/themeUtils';
import { getLatestActivityLogInfo } from '../lib/logUtils';
import { EXTENDED_PROCESSING_DIR, STATS_DIR } from '../lib/pathConstants';

// 未来ハートビートID検証（未来は即エラー）



// Zod schema for activity log input (サブテーマ対応版)
export const activityLogInputSchema = z.object({
  activityType: z.enum(['観測', '思考', '創造', '内省', 'テーマ開始', 'テーマ終了', '回復', 'その他'])
    .describe("実行した活動の種別。'観測', '思考', '創造', '内省', 'テーマ開始', 'テーマ終了', '回復', 'その他' のいずれかである必要があります。"),
  activityContent: z.array(z.string()).describe('活動内容の簡潔な説明のリスト。'),
  artifacts: z.array(z.string()).optional().default([]).describe('作成または修正したファイルのパスのリスト。'),
  evaluation: z.string().optional().default('').describe('自己評価や備考。'),
  themeStartId: z.string()
    .regex(/^\d{14}$/, 'THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .describe('テーマ開始時のハートビートID'),
  themeDirectoryPart: z.string()
    .describe('テーマディレクトリ名の一部。THEME_START_IDと組み合わせて "{THEME_START_ID}_{themeDirectoryPart}" の形式でテーマディレクトリが特定されます'),

  // 🆕 サブテーマ対応の新規フィールド
  parentThemeStartId: z.string()
    .regex(/^\d{14}$/, 'PARENT_THEME_START_IDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります')
    .optional()
    .describe('サブテーマの場合、親テーマのTHEME_START_IDを指定。nullまたは未指定の場合はルートテーマとして扱われます'),
  parentThemeDirectoryPart: z.string()
    .optional()
    .describe('サブテーマの場合、親テーマのディレクトリ部分を指定。parentThemeStartIdが指定された場合は必須'),
});



// Helper functions

/**
 * 成果物ファイルの存在チェック
 * @param artifacts 成果物ファイルパスの配列
 * @returns 検証結果とメッセージ
 */
async function validateArtifacts(artifacts: string[]): Promise<{
  hasIssues: boolean;
  existingFiles: string[];
  missingFiles: string[];
  validationMessage: string;
}> {
  if (artifacts.length === 0) {
    return {
      hasIssues: false,
      existingFiles: [],
      missingFiles: [],
      validationMessage: ''
    };
  }

  const existingFiles: string[] = [];
  const missingFiles: string[] = [];

  for (const artifact of artifacts) {
    try {
      // パスの正規化（セキュリティ対策）
      const normalizedPath = path.normalize(artifact);

      // パストラバーサル攻撃の防止（上位ディレクトリへの移動を禁止）
      if (normalizedPath.includes('..') || path.isAbsolute(normalizedPath)) {
        missingFiles.push(`${artifact} (相対パスのみ許可されています)`);
        continue;
      }

      if (await fs.pathExists(normalizedPath)) {
        existingFiles.push(artifact);
      } else {
        missingFiles.push(artifact);
      }
    } catch (error) {
      missingFiles.push(`${artifact} (ファイルアクセスエラー)`);
    }
  }

  const hasIssues = missingFiles.length > 0;
  let validationMessage = '';

  if (hasIssues) {
    validationMessage = `以下のファイルが存在しません:\n`;
    missingFiles.forEach(file => {
      validationMessage += `- ${file}\n`;
    });
    validationMessage += `\n対処方法:\n`;
    validationMessage += `1. ファイルパスが正しいか確認してください\n`;
    validationMessage += `2. ファイルが実際に作成されているか確認してください\n`;
    validationMessage += `3. 必要に応じてファイルを作成してから再実行してください\n`;
    validationMessage += `4. 作成していないファイルは成果物から除外してください`;
  }

  return {
    hasIssues,
    existingFiles,
    missingFiles,
    validationMessage
  };
}

/**
 * 未来ハートビートIDの検証
 * @param heartbeatId YYYYMMDDHHMMSS形式のハートビートID
 * @throws Error 未来のハートビートIDが許容範囲を超えている場合
 */

/**
 * 前回活動ログとチェックポイントからの経過時間メッセージを生成
 */
async function generateTimeAnalysisMessage(heartbeatId: string): Promise<string> {
  const currentTime = getCurrentTimestamp(); // 実際の現在時刻を使用
  let timeMessages: string[] = [];

  // 前回活動ログからの経過時間
  try {
    const latestLogInfo = await getLatestActivityLogInfo();
    if (latestLogInfo) {
      const latestLogTime = await getFileModificationTime(latestLogInfo.filePath);
      const elapsedSeconds = currentTime - latestLogTime;
      if (elapsedSeconds > 0) { // 0秒の場合は表示しない
        timeMessages.push(`前回の活動ログから${formatElapsedTime(elapsedSeconds)}が経過しています。`);
      }
    }
  } catch (error) {
    // エラーは無視して続行
  }

  // 前回チェックポイントからの経過時間
  try {
    const latestCheckpoint = await getLatestCheckpointInfo();
    if (latestCheckpoint) {
      const checkpointFile = path.join(STATS_DIR, 'checkpoints', `${latestCheckpoint.heartbeatId}.txt`);
      const checkpointTime = await getFileModificationTime(checkpointFile);
      const elapsedSeconds = currentTime - checkpointTime;
      if (elapsedSeconds > 0) { // 0秒の場合は表示しない
        timeMessages.push(`前回のチェックポイントから${formatElapsedTime(elapsedSeconds)}が経過しています。`);

        // チェックポイントの内容も表示
        timeMessages.push(`最後のチェックポイント: ${latestCheckpoint.message}`);
      }
    }
  } catch (error) {
    // エラーは無視して続行
  }

  return timeMessages.length > 0 ? timeMessages.join('\n') : '';
}



function generateActivityLogMarkdown(args: z.infer<typeof activityLogInputSchema>): string {
  const lines: string[] = [];

  // Title
  lines.push(`# 活動ログ`);
  lines.push('');

  // サブテーマ情報（サブテーマの場合のみ）
  if (args.parentThemeStartId && args.parentThemeDirectoryPart) {
    lines.push('## テーマ情報');
    lines.push(`**現在のテーマ**: ${args.themeStartId}_${args.themeDirectoryPart} (サブテーマ)`);
    lines.push(`**親テーマ**: ${args.parentThemeStartId}_${args.parentThemeDirectoryPart}`);
    lines.push('');
  }

  // Activity type
  lines.push('## 活動種別');
  lines.push(args.activityType);
  lines.push('');

  // Activity content
  lines.push('## 活動内容');
  if (args.activityContent.length > 0) {
    args.activityContent.forEach(content => {
      lines.push(`- ${content}`);
    });
  } else {
    lines.push('具体的な活動内容なし');
  }
  lines.push('');

  // Artifacts
  lines.push('## 成果物、関連ファイル');
  if (args.artifacts && args.artifacts.length > 0) {
    // 検証を通過したファイルのみが記録される（全て存在することが保証済み）
    args.artifacts.forEach(artifact => {
      lines.push(`- ${artifact}`);
    });
  } else {
    lines.push('なし');
  }
  lines.push('');

  // Evaluation
  lines.push('## 自己評価、備考');
  if (args.evaluation && args.evaluation.trim()) {
    lines.push(args.evaluation);
  } else {
    lines.push('特記事項なし');
  }
  lines.push('');

  return lines.join('\n');
}

function getActivityLogFilePath(
  themeStartId: string,
  themeDirectoryPart: string,
  heartbeatId: string,
  sequence?: number,
  parentThemeStartId?: string,
  parentThemeDirectoryPart?: string
): string {
  // テーマディレクトリパスを解決
  const themeDirectoryPath = resolveThemePath(
    themeStartId,
    themeDirectoryPart,
    parentThemeStartId,
    parentThemeDirectoryPart
  );

  // ファイル名生成
  const filename = sequence ? `${heartbeatId}_${sequence.toString().padStart(2, '0')}.md` : `${heartbeatId}.md`;

  return path.join(themeDirectoryPath, 'histories', filename);
}

async function findAvailableSequence(
  themeStartId: string,
  themeDirectoryPart: string,
  heartbeatId: string,
  parentThemeStartId?: string,
  parentThemeDirectoryPart?: string
): Promise<{ sequence: number | null; warning: string | null }> {
  const basePath = getActivityLogFilePath(
    themeStartId,
    themeDirectoryPart,
    heartbeatId,
    undefined,
    parentThemeStartId,
    parentThemeDirectoryPart
  );

  // 基本ファイルが存在しない場合は連番なしで作成
  if (!await fs.pathExists(basePath)) {
    return { sequence: null, warning: null };
  }

  // 連番ファイルをチェック（ファイル重複回避のため連番生成ロジックは維持）
  for (let i = 1; i <= 99; i++) {
    const sequencePath = getActivityLogFilePath(
      themeStartId,
      themeDirectoryPart,
      heartbeatId,
      i,
      parentThemeStartId,
      parentThemeDirectoryPart
    );
    if (!await fs.pathExists(sequencePath)) {
      // 連番警告は削除し、時間ベース警告に統一
      return {
        sequence: i,
        warning: null  // 連番警告を削除
      };
    }
  }

  // 99個まで埋まっている場合はエラー
  throw new Error(`ハートビートID ${heartbeatId} の活動ログの連番が上限（99）に達しました。`);
}

export const activityLogTool = {
  name: 'create_activity_log',
  description: 'AI心臓システム用の、標準形式の活動ログを作成します。ハートビートIDはシステムから自動取得されます。サブテーマにも対応しており、parentThemeStartIdを指定することでサブテーマの活動ログとして作成されます。時間ベース制御により、適切な時間内で自然な思考フローに基づく連続活動を支援します。論理的に連続した処理や効率的な活動フローの場合、同一ハートビート内での複数活動が許可されており、その際は自動で連番ファイルが作成されます。活動サイクル開始から5分経過で経過時間通知、10分経過で活動分割推奨が表示されます。長時間処理が必要な場合は事前にstart_deep_workツールで宣言してください。',
  input_schema: activityLogInputSchema,
  execute: async (args: z.infer<typeof activityLogInputSchema>) => {
    try {
      // ハートビートIDをシステムから取得
      const heartbeatIdPath = path.join(STATS_DIR, 'current_heartbeat_id.txt');
      if (!await fs.pathExists(heartbeatIdPath)) {
        throw new Error('ハートビートIDファイルが見つかりません: ' + heartbeatIdPath);
      }
      const heartbeatId = (await fs.readFile(heartbeatIdPath, 'utf-8')).trim();
      if (!/^\d{14}$/.test(heartbeatId)) {
        throw new Error('無効なハートビートID形式です: ' + heartbeatId);
      }

      // バリデーション
      if (args.parentThemeStartId && !args.parentThemeDirectoryPart) {
        throw new Error('parentThemeStartIdが指定された場合、parentThemeDirectoryPartも必須です');
      }

      if (args.parentThemeDirectoryPart && !args.parentThemeStartId) {
        throw new Error('parentThemeDirectoryPartが指定された場合、parentThemeStartIdも必須です');
      }

      // 成果物ファイルの存在チェック
      const artifactValidation = await validateArtifacts(args.artifacts || []);
      if (artifactValidation.hasIssues) {
        // 存在しないファイルがある場合はエラーで停止
        throw new Error(`成果物ファイルの検証に失敗しました:\n${artifactValidation.validationMessage}\n\n指定されたファイルが実際に存在することを確認してから、再度活動ログの作成を実行してください。`);
      }

      // Generate markdown content
      let markdownContent = generateActivityLogMarkdown(args);
      markdownContent = markdownContent.replace('# 活動ログ', `# 活動ログ：${heartbeatId}`);

      // Sanitize directory part to prevent directory traversal
      const sanitizedDirectoryPart = path.basename(args.themeDirectoryPart);
      const sanitizedParentDirectoryPart = args.parentThemeDirectoryPart ?
        path.basename(args.parentThemeDirectoryPart) : undefined;

      // テーマディレクトリパスを構築
      const themeDirectoryPath = resolveThemePath(
        args.themeStartId,
        sanitizedDirectoryPart,
        args.parentThemeStartId,
        sanitizedParentDirectoryPart
      );

      // テーマディレクトリの存在確認
      if (!await fs.pathExists(themeDirectoryPath)) {
        const themeType = args.parentThemeStartId ? 'サブテーマ' : 'テーマ';
        throw new Error(`${themeType}ディレクトリが存在しません: ${themeDirectoryPath}`);
      }

      // Check for duplicates and find available sequence
      const { sequence, warning } = await findAvailableSequence(args.themeStartId, sanitizedDirectoryPart, heartbeatId, args.parentThemeStartId, sanitizedParentDirectoryPart);

      const filePath = getActivityLogFilePath(
        args.themeStartId,
        sanitizedDirectoryPart,
        heartbeatId,
        sequence ?? undefined,
        args.parentThemeStartId,
        sanitizedParentDirectoryPart
      );



      // Generate time analysis message
      const timeAnalysisMessage = await generateTimeAnalysisMessage(heartbeatId);

      // Ensure directory exists
      await fs.ensureDir(path.dirname(filePath));

      // Write file
      await fs.writeFile(filePath, markdownContent, 'utf-8');

      // 深い作業宣言ファイルの完了処理
      const deepWorkDir = path.join(STATS_DIR, 'deep_work');
      let extendedProcessingMessage = '';
      if (await fs.pathExists(deepWorkDir)) {
        const files = await fs.readdir(deepWorkDir);
        // Find ALL active (not completed or expired) deep work declarations
        const activeDeepWorkFiles = files.filter(f => f.endsWith('.txt') && !f.endsWith('.completed.txt') && !f.endsWith('.expired.txt'));

        if (activeDeepWorkFiles.length > 0) {
          const completedFiles = [];
          const deepWorkDurations = [];

          for (const activeFile of activeDeepWorkFiles) {
            const originalPath = path.join(deepWorkDir, activeFile);
            const completedPath = originalPath.replace(/\.txt$/, '.completed.txt');

            // 深い作業の開始時刻を取得（ファイル作成時刻から）
            const deepWorkHeartbeatId = activeFile.replace('.txt', '');
            if (/^\d{14}$/.test(deepWorkHeartbeatId)) {
              try {
                const startTime = await getFileModificationTime(originalPath);
                const currentTime = getCurrentTimestamp();
                const elapsedSeconds = currentTime - startTime;

                if (elapsedSeconds >= 0) {
                  deepWorkDurations.push(`${activeFile}: ${formatElapsedTime(elapsedSeconds)}`);
                } else {
                  deepWorkDurations.push(`${activeFile}: 時間計算エラー`);
                }
              } catch (error) {
                deepWorkDurations.push(`${activeFile}: 時間計算エラー`);
              }
            } else {
              deepWorkDurations.push(`${activeFile}: 無効な形式`);
            }

            await fs.rename(originalPath, completedPath);
            completedFiles.push(activeFile);
          }

          if (deepWorkDurations.length > 0) {
            extendedProcessingMessage = `\n深い作業宣言を完了しました:\n${deepWorkDurations.map(d => `- ${d}`).join('\n')}`;
          } else {
            extendedProcessingMessage = `\n深い作業宣言（${completedFiles.join(', ')}）を完了しました。`;
          }
        }
      }

      // Prepare response message
      const themeType = args.parentThemeStartId ? 'サブテーマ' : 'テーマ';
      let responseText = `活動ログを作成しました: ${filePath}`;
      responseText += `\nハートビートID: ${heartbeatId}`;

      if (args.parentThemeStartId) {
        responseText += `\n${themeType}: ${sanitizedDirectoryPart} (${args.themeStartId})`;
        responseText += `\n親テーマ: ${sanitizedParentDirectoryPart} (${args.parentThemeStartId})`;
      } else {
        responseText += `\n${themeType}: ${sanitizedDirectoryPart} (${args.themeStartId})`;
      }

      if (warning) {
        responseText += `\n警告: ${warning}`;
      }

      // Sanitization warning
      if (sanitizedDirectoryPart !== args.themeDirectoryPart) {
        responseText += `\n警告: ディレクトリ名を「${args.themeDirectoryPart}」から「${sanitizedDirectoryPart}」に修正しました`;
      }

      if (sanitizedParentDirectoryPart && args.parentThemeDirectoryPart &&
        sanitizedParentDirectoryPart !== args.parentThemeDirectoryPart) {
        responseText += `\n警告: 親ディレクトリ名を「${args.parentThemeDirectoryPart}」から「${sanitizedParentDirectoryPart}」に修正しました`;
      }

      // 時間分析メッセージを追加
      if (timeAnalysisMessage) {
        responseText += `\n\n${timeAnalysisMessage}`;
      }



      // 長時間処理宣言の完了メッセージを追加
      if (extendedProcessingMessage) {
        responseText += extendedProcessingMessage;
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