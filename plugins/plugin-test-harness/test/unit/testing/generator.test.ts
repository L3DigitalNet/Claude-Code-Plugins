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
});
