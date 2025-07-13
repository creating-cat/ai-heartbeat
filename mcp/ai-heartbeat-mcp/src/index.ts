/**
 * AI Heartbeat MCP - Entry Point
 */

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { thinkingLogTool } from './tools/thinkingLogTool.js';

// Create MCP server
const server = new McpServer({
  name: 'ai-heartbeat-mcp',
  version: '0.1.0',
  description: 'Model Context Protocol tools for AI Heartbeat System',
});

// Register thinking log tool
server.tool(
  thinkingLogTool.name,
  thinkingLogTool.description,
  thinkingLogTool.input_schema.shape,
  thinkingLogTool.execute
);

// Start server
async function startServer(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('AI Heartbeat MCP Server started');
}

// Start if this file is run directly
if (require.main === module) {
  startServer().catch((error) => {
    console.error('Failed to start MCP server:', error);
    process.exit(1);
  });
}

export { server, startServer };