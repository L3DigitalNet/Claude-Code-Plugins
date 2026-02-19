import { getLog, parseTrailers } from '../session/git.js';
import type { FixRecord } from './types.js';

export async function getFixHistory(worktreePath: string): Promise<FixRecord[]> {
  const log = await getLog(worktreePath, { maxCount: 100 });
  const records: FixRecord[] = [];

  // Parse git log output: each entry is "HASH SUBJECT\nBODY\n"
  const entries = log.split('\n\n').filter(e => e.trim());
  for (const entry of entries) {
    const lines = entry.trim().split('\n');
    const firstLine = lines[0];
    const hashAndSubject = firstLine.match(/^([a-f0-9]+)\s+(.+)$/);
    if (!hashAndSubject) continue;

    const body = lines.slice(1).join('\n');
    const trailers = parseTrailers(body);

    // Only include PTH fix commits (those with PTH trailers)
    if (Object.keys(trailers).length === 0) continue;

    records.push({
      commitHash: hashAndSubject[1],
      commitTitle: hashAndSubject[2],
      trailers,
      filesChanged: trailers['PTH-Files']?.split(',').map(f => f.trim()) ?? [],
      timestamp: new Date().toISOString(), // approximate — git log format doesn't include timestamp
    });
  }
  return records;
}
