/**
 * AI Heartbeat MCP - Entry Point
 */

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { activityLogTool } from './tools/activityLogTool';
import { themeLogTool } from './tools/themeLogTool';
import { itemProcessorTool } from './tools/itemProcessorTool';
import { reportToolUsageTool } from './tools/reportToolUsageTool';
import { createThemeExpertContextTool } from './tools/createThemeExpertContextTool';
import { getLatestActivityLogTool } from './tools/getLatestActivityLogTool';
import { checkThemeStatusTool } from './tools/checkThemeStatusTool';
import { listThemeArtifactsTool } from './tools/listThemeArtifactsTool';
import { getLatestThemeContextTool } from './tools/getLatestThemeContextTool';
import { declareExtendedProcessingTool } from './tools/declareExtendedProcessingTool';
import { getHeartbeatElapsedTimeTool } from './tools/getHeartbeatElapsedTimeTool';

// Create MCP server
const server = new McpServer({
  name: 'ai-heartbeat-mcp',
  version: '0.1.0',
  description: 'Model Context Protocol tools for AI Heartbeat System',
});

// Register activity log tool
server.tool(
  activityLogTool.name,
  activityLogTool.description,
  activityLogTool.input_schema.shape,
  activityLogTool.execute
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

// Register report tool usage tool
server.tool(
  reportToolUsageTool.name,
  reportToolUsageTool.description,
  reportToolUsageTool.input_schema.shape,
  reportToolUsageTool.execute,
);

// Register create theme expert context tool
server.tool(
  createThemeExpertContextTool.name,
  createThemeExpertContextTool.description,
  createThemeExpertContextTool.input_schema.shape,
  createThemeExpertContextTool.execute
);

// Register get latest activity log tool
server.tool(
  getLatestActivityLogTool.name,
  getLatestActivityLogTool.description,
  getLatestActivityLogTool.input_schema.shape,
  getLatestActivityLogTool.execute
);

// Register check theme status tool
server.tool(
  checkThemeStatusTool.name,
  checkThemeStatusTool.description,
  checkThemeStatusTool.input_schema.shape,
  checkThemeStatusTool.execute
);

// Register list theme artifacts tool
server.tool(
  listThemeArtifactsTool.name,
  listThemeArtifactsTool.description,
  listThemeArtifactsTool.input_schema.shape,
  listThemeArtifactsTool.execute
);

// Register get latest theme context tool
server.tool(
  getLatestThemeContextTool.name,
  getLatestThemeContextTool.description,
  getLatestThemeContextTool.input_schema.shape,
  getLatestThemeContextTool.execute
);

// Register declare extended processing tool
server.tool(
  declareExtendedProcessingTool.name,
  declareExtendedProcessingTool.description,
  declareExtendedProcessingTool.input_schema.shape,
  declareExtendedProcessingTool.execute
);

// Register get heartbeat elapsed time tool
server.tool(
  getHeartbeatElapsedTimeTool.name,
  getHeartbeatElapsedTimeTool.description,
  getHeartbeatElapsedTimeTool.input_schema.shape,
  getHeartbeatElapsedTimeTool.execute
);

// Start server with stdio transport
const transport = new StdioServerTransport();
server.connect(transport).then(() => {
  // console.error('AI Heartbeat MCP Server started');
}).catch(error => {
  console.error('MCP Server failed to start:', error);
});

export { server };