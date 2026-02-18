import fs from 'fs';

const debugEnabled = !!process.env['PTH_DEBUG'];
const logFile = process.env['PTH_LOG_FILE'];

export function debug(message: string, data?: unknown): void {
  if (!debugEnabled) return;
  const line = `[PTH DEBUG] ${new Date().toISOString()} ${message}${data !== undefined ? ' ' + JSON.stringify(data) : ''}`;
  process.stderr.write(line + '\n');
  if (logFile) {
    fs.appendFileSync(logFile, line + '\n');
  }
}

export function info(message: string): void {
  process.stderr.write(`[PTH] ${message}\n`);
}

export function warn(message: string): void {
  process.stderr.write(`[PTH WARN] ${message}\n`);
}
