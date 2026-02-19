import { run } from '../shared/exec.js';
import { parseTrailers } from '../session/git.js';
import type { FixRecord } from './types.js';

// ASCII Record Separator (0x1e) — used via git's %xHH escape in the format string.
// This avoids embedding a NUL byte in a process argument (which POSIX forbids).
// The string below is the decoded form used for splitting stdout.
const COMMIT_PREFIX = '\x1eCOMMIT\x1e';

export async function getFixHistory(worktreePath: string): Promise<FixRecord[]> {
  // Format: RS+COMMIT+RS <hash> <subject>\n<ISO-date>\n<body>
  // %x1e = ASCII Record Separator (safe to pass as a process argument via git's %xHH escape)
  // %h = short hash (matches commitAll return), %aI = author ISO date, %b = body
  const result = await run(
    'git',
    ['log', '--format=%x1eCOMMIT%x1e%h %s%n%aI%n%b', '-n100'],
    { cwd: worktreePath }
  );

  const records: FixRecord[] = [];

  // Split on the unique prefix to get per-commit chunks
  const chunks = result.stdout.split(COMMIT_PREFIX).filter(c => c.trim());

  for (const chunk of chunks) {
    const lines = chunk.split('\n');

    // First line: "<hash> <subject>"
    const firstLine = lines[0]?.trim() ?? '';
    const m = firstLine.match(/^([a-f0-9]+) (.+)$/);
    if (!m) continue;

    // Second line: ISO date
    const timestamp = lines[1]?.trim() ?? new Date().toISOString();

    // Remaining lines: body (may include blank lines and PTH trailers)
    const body = lines.slice(2).join('\n');
    const trailers = parseTrailers(body);

    // Skip commits with no PTH trailers
    if (Object.keys(trailers).length === 0) continue;

    records.push({
      commitHash: m[1],
      commitTitle: m[2],
      trailers,
      filesChanged: trailers['PTH-Files']?.split(',').map(f => f.trim()) ?? [],
      timestamp,
    });
  }

  return records;
}
