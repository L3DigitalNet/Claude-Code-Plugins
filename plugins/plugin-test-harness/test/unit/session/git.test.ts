import { buildCommitMessage, parseTrailers, generateSessionBranch } from '../../../src/session/git.js';

describe('buildCommitMessage', () => {
  it('produces a commit message with PTH trailers', () => {
    const msg = buildCommitMessage('fix: handle missing group', {
      'PTH-Test': 'create_user_nonexistent_group',
      'PTH-Category': 'runtime-exception',
      'PTH-Files': 'src/tools/user-management.ts',
      'PTH-Iteration': '3',
    });
    expect(msg).toContain('fix: handle missing group');
    expect(msg).toContain('PTH-Test: create_user_nonexistent_group');
    expect(msg).toContain('PTH-Category: runtime-exception');
  });
});

describe('parseTrailers', () => {
  it('extracts trailer key-value pairs from commit message', () => {
    const body = `fix: something\n\nPTH-Test: my_test\nPTH-Iteration: 5`;
    const trailers = parseTrailers(body);
    expect(trailers['PTH-Test']).toBe('my_test');
    expect(trailers['PTH-Iteration']).toBe('5');
  });

  it('returns empty object for message with no trailers', () => {
    expect(parseTrailers('fix: no trailers here')).toEqual({});
  });
});

describe('generateSessionBranch', () => {
  it('produces a branch name with plugin name, date, and hash', () => {
    const branch = generateSessionBranch('my-plugin');
    expect(branch).toMatch(/^pth\/my-plugin-\d{4}-\d{2}-\d{2}-[a-f0-9]{6}$/);
  });
});
