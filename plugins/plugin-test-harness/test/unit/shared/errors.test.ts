import { PTHError, PTHErrorCode } from '../../../src/shared/errors.js';

describe('PTHError', () => {
  it('creates error with code and message', () => {
    const err = new PTHError(PTHErrorCode.NO_ACTIVE_SESSION, 'No session active');
    expect(err.code).toBe(PTHErrorCode.NO_ACTIVE_SESSION);
    expect(err.message).toBe('No session active');
    expect(err instanceof Error).toBe(true);
  });

  it('includes optional context', () => {
    const err = new PTHError(PTHErrorCode.BUILD_FAILED, 'Build failed', { output: 'error text' });
    expect(err.context).toEqual({ output: 'error text' });
  });
});
