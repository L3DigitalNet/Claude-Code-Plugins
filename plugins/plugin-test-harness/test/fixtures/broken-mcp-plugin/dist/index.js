import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { ListToolsRequestSchema, CallToolRequestSchema } from '@modelcontextprotocol/sdk/types.js';
const server = new Server({ name: 'broken-mcp-plugin', version: '1.0.0' }, { capabilities: { tools: {} } });
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
    const r = (text) => ({ content: [{ type: 'text', text }] });
    if (name === 'echo')
        return r(args.message);
    if (name === 'reverse_string') {
        // BUG 1: accesses .wrongField which doesn't exist — returns empty string instead of reversed input
        const a = args;
        return r(String(a['wrongField'] ?? '').split('').reverse().join(''));
    }
    if (name === 'divide') {
        const { a, b } = args;
        // BUG 2: no zero-division guard — returns Infinity or NaN instead of throwing
        return r(String(a / b));
    }
    if (name === 'get_status') {
        // BUG 3: returns empty string instead of JSON status object
        return r('');
    }
    throw new Error(`Unknown tool: ${name}`);
});
const transport = new StdioServerTransport();
await server.connect(transport);
