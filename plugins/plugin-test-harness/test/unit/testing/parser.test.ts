import { parseTest, parseTestFile } from '../../../src/testing/parser.js';
import { PTHError } from '../../../src/shared/errors.js';

describe('parseTest', () => {
  it('parses a minimal MCP single-tool test', () => {
    const yaml = `
name: "get_info returns version"
mode: mcp
tool: ha_get_info
input: {}
expect:
  success: true
  output_contains: "version"
`;
    const test = parseTest(yaml);
    expect(test.name).toBe('get_info returns version');
    expect(test.mode).toBe('mcp');
    expect(test.type).toBe('single');
    expect(test.tool).toBe('ha_get_info');
    expect(test.expect.success).toBe(true);
  });

  it('parses a plugin hook-script test', () => {
    const yaml = `
name: "write guard blocks Write"
mode: plugin
type: hook-script
script: hooks/scripts/write-guard.sh
stdin:
  tool_name: "Write"
  tool_input:
    file_path: "/tmp/test.ts"
expect:
  exit_code: 2
  stdout_contains: "block"
`;
    const test = parseTest(yaml);
    expect(test.mode).toBe('plugin');
    expect(test.type).toBe('hook-script');
    expect(test.script).toBe('hooks/scripts/write-guard.sh');
    expect(test.expect.exit_code).toBe(2);
  });

  it('throws on missing required field name', () => {
    expect(() => parseTest('mode: mcp\ntool: foo')).toThrow(PTHError);
  });
});
