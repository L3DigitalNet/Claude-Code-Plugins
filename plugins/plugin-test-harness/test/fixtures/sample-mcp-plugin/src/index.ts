import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { ListToolsRequestSchema, CallToolRequestSchema } from '@modelcontextprotocol/sdk/types.js';

const server = new Server(
  { name: 'sample-mcp-plugin', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    { name: 'echo', description: 'Echo a message back', inputSchema: { type: 'object', properties: { message: { type: 'string' } }, required: ['message'] } },
    { name: 'reverse_string', description: 'Reverse a string', inputSchema: { type: 'object', properties: { input: { type: 'string' } }, required: ['input'] } },
    { name: 'divide', description: 'Divide two numbers', inputSchema: { type: 'object', properties: { a: { type: 'number' }, b: { type: 'number' } }, required: ['a', 'b'] } },
    { name: 'get_status', description: 'Get server status', inputSchema: { type: 'object', properties: {} } },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;
  const r = (text: string) => ({ content: [{ type: 'text' as const, text }] });

  if (name === 'echo') return r((args as { message: string }).message);
  if (name === 'reverse_string') return r((args as { input: string }).input.split('').reverse().join(''));
  if (name === 'divide') {
    const { a, b } = args as { a: number; b: number };
    if (b === 0) throw new Error('Division by zero');
    return r(String(a / b));
  }
  if (name === 'get_status') return r(JSON.stringify({ status: 'ok', version: '1.0.0', tools: 4 }));
  throw new Error(`Unknown tool: ${name}`);
});

const transport = new StdioServerTransport();
await server.connect(transport);
