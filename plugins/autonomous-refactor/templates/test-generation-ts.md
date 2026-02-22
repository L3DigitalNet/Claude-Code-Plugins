# Test Generation Instructions — TypeScript

<!-- Loaded by agents/test-generator.md when language == "typescript".
     Defines the test structure, coverage requirements, and file conventions
     the agent must follow when generating the baseline test suite. -->

## Framework

Use **Vitest** (`import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'`).
Do NOT use Jest-specific imports. Vitest is Jest-compatible but prefer its native API.

## File Naming

Write the test file to: `.claude/state/refactor-tests/<original-basename>.test.ts`

Example: target is `src/auth/validator.ts` → test file is `.claude/state/refactor-tests/validator.test.ts`

## Coverage Requirements

For every **exported** function, class, and method:

1. **Happy path** — normal input, expected output
2. **Boundary conditions** — empty string, empty array, zero, negative numbers, `null`, `undefined`
3. **Error throwing** — confirm the function throws (or doesn't throw) on invalid input
4. **Type coercion edge cases** — inputs that look valid but may trigger unexpected behavior (e.g., `NaN`, `Infinity`, `""` vs `null`)

Do NOT test private/unexported symbols.

## Mocking Rules

- Mock ALL external I/O: file system (`fs`), network (`fetch`, axios, etc.), database calls
- Use `vi.mock('<module>')` at file level; reset with `vi.resetAllMocks()` in `beforeEach`
- Do NOT mock functions from the target module itself — test their real behavior
- If the target imports other project modules, mock only those that perform I/O; import the rest normally

## Structure Template

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { <exportedSymbols> } from '<relative-path-to-target>'

// Mock external dependencies
vi.mock('<external-module>', () => ({
  <symbol>: vi.fn(),
}))

describe('<FunctionOrClassName>', () => {
  beforeEach(() => {
    vi.resetAllMocks()
  })

  describe('happy path', () => {
    it('returns expected value for valid input', () => {
      // arrange, act, assert
    })
  })

  describe('edge cases', () => {
    it('handles empty input', () => { ... })
    it('handles null input', () => { ... })
  })

  describe('error handling', () => {
    it('throws on invalid input', () => {
      expect(() => fn(invalidInput)).toThrow()
    })
  })
})
```

## Self-Verification

After writing the test file, run: `bash <PLUGIN_ROOT>/scripts/run-tests.sh --test-file <test-file>`

If tests fail: diagnose whether the failure is in the test code (fix it) or the source code (report it — do NOT change the source).

Retry up to 3 times before reporting an unresolvable baseline failure.

## Output Contract

Return exactly:
```
## Test-Generator Results
Test file: <path>
Passed: N | Failed: 0
Exported symbols covered: [list of symbol names]
```

If baseline cannot reach green after 3 retries:
```
## Test-Generator Results
BASELINE FAILURE — cannot reach green
Failing tests: [list]
Reason: <diagnosis>
```
