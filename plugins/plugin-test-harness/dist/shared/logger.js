import fs from 'fs';
const debugEnabled = !!process.env['PTH_DEBUG'];
const logFile = process.env['PTH_LOG_FILE'];
export function debug(message, data) {
    if (!debugEnabled)
        return;
    const line = `[PTH DEBUG] ${new Date().toISOString()} ${message}${data !== undefined ? ' ' + JSON.stringify(data) : ''}`;
    process.stderr.write(line + '\n');
    if (logFile) {
        fs.appendFileSync(logFile, line + '\n');
    }
}
export function info(message) {
    process.stderr.write(`[PTH] ${message}\n`);
}
export function warn(message) {
    process.stderr.write(`[PTH WARN] ${message}\n`);
}
//# sourceMappingURL=logger.js.map