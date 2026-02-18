export enum PTHErrorCode {
  NO_ACTIVE_SESSION = 'NO_ACTIVE_SESSION',
  SESSION_ALREADY_ACTIVE = 'SESSION_ALREADY_ACTIVE',
  BUILD_FAILED = 'BUILD_FAILED',
  GIT_ERROR = 'GIT_ERROR',
  PLUGIN_NOT_FOUND = 'PLUGIN_NOT_FOUND',
  INVALID_TEST = 'INVALID_TEST',
  RELOAD_FAILED = 'RELOAD_FAILED',
  CACHE_SYNC_FAILED = 'CACHE_SYNC_FAILED',
}

export class PTHError extends Error {
  readonly code: PTHErrorCode;
  readonly context?: Record<string, unknown>;

  constructor(code: PTHErrorCode, message: string, context?: Record<string, unknown>) {
    super(message);
    this.name = 'PTHError';
    this.code = code;
    this.context = context;
  }
}
