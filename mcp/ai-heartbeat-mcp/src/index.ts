/**
 * AI Heartbeat MCP - Entry Point
 */

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { thinkingLogTool } from './tools/thinkingLogTool';
import { themeLogTool } from './tools/themeLogTool';
import { itemProcessorTool } from './tools/itemProcessorTool';
import { webSearchStatsTool } from './tools/webSearchStatsTool';

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

// Register theme log tool
server.tool(
  themeLogTool.name,
  themeLogTool.description,
  themeLogTool.input_schema.shape,
  themeLogTool.execute
);

// Register item processor tool
server.tool(
  itemProcessorTool.name,
  itemProcessorTool.description,
  itemProcessorTool.input_schema.shape,
  itemProcessorTool.execute,
);

// Register web search stats tool
server.tool(
  webSearchStatsTool.name,
  webSearchStatsTool.description,
  webSearchStatsTool.input_schema.shape,
  webSearchStatsTool.execute,
);

// Start server with stdio transport
const transport = new StdioServerTransport();
server.connect(transport).then(() => {
  // console.error('AI Heartbeat MCP Server started');
}).catch(error => {
  console.error('MCP Server failed to start:', error);
});

export { server };