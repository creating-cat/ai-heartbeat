/**
 * Path Constants for AI Works Directory Structure
 * Centralized path management for the ai-works migration
 */

export const AI_WORKS_DIR = '.';
export const ARTIFACTS_DIR = `${AI_WORKS_DIR}/artifacts`;
export const STATS_DIR = `${AI_WORKS_DIR}/stats`;
export const THEMEBOX_DIR = `${AI_WORKS_DIR}/themebox`;
export const FEEDBACKBOX_DIR = `${AI_WORKS_DIR}/feedbackbox`;
export const PROJECTS_DIR = `${AI_WORKS_DIR}/projects`;

// Specific subdirectories
export const THEME_HISTORIES_DIR = `${ARTIFACTS_DIR}/theme_histories`;
export const COOLDOWN_DIR = `${STATS_DIR}/cooldown`;
export const LOCK_DIR = `${STATS_DIR}/lock`;
export const EXTENDED_PROCESSING_DIR = `${STATS_DIR}/deep_work`;
export const CHECKPOINTS_DIR = `${STATS_DIR}/checkpoints`;