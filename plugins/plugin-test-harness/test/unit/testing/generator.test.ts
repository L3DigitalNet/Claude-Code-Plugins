// test/unit/testing/generator.test.ts
import path from 'path';
import { fileURLToPath } from 'url';
import { generateMcpTests } from '../../../src/testing/generator.js';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FIXTURES = path.join(__dirname, '../../fixtures');

describe('generateMcpTests', () => {
  it('generates at least one test per tool from schema', async () => {
    const tests = await generateMcpTests({
      pluginPath: path.join(FIXTURES, 'sample-mcp-plugin'),
      toolSchemas: [
        {
          name: 'echo_message',
          description: 'Echoes a message back',
          inputSchema: {
            type: 'object',
            properties: { message: { type: 'string' } },
            required: ['message'],
          },
        },
      ],
    });

    expect(tests.length).toBeGreaterThanOrEqual(1);
    expect(tests[0].mode).toBe('mcp');
    expect(tests[0].tool).toBe('echo_message');
    expect(tests[0].generated_from).toBe('schema');
  });

  it('generates two tests per tool when required fields exist (valid + missing-required)', async () => {
    const tests = await generateMcpTests({
      pluginPath: path.join(FIXTURES, 'sample-mcp-plugin'),
      toolSchemas: [
        {
          name: 'echo_message',
          description: 'Echoes a message',
          inputSchema: {
            type: 'object',
            properties: { message: { type: 'string' } },
            required: ['message'],
          },
        },
      ],
    });

    expect(tests).toHaveLength(2);
    expect(tests[0].expect.success).toBe(true);
    expect(tests[1].expect.success).toBe(false);
    expect(tests[1].name).toContain('missing required field');
  });

  it('generates one test per tool when no required fields exist', async () => {
    const tests = await generateMcpTests({
      pluginPath: path.join(FIXTURES, 'sample-mcp-plugin'),
      toolSchemas: [
        {
          name: 'list_items',
          description: 'Lists all items',
          inputSchema: {
            type: 'object',
            properties: { filter: { type: 'string' } },
            // no required fields
          },
        },
      ],
    });

    expect(tests).toHaveLength(1);
    expect(tests[0].tool).toBe('list_items');
  });

  it('returns empty array for empty toolSchemas', async () => {
    const tests = await generateMcpTests({
      pluginPath: path.join(FIXTURES, 'sample-mcp-plugin'),
      toolSchemas: [],
    });
    expect(tests).toHaveLength(0);
  });
});
