// Minimal MCP smoke client. Spawns the server over stdio, lists tools,
// calls brain_status, prints results to stdout. Exit non-zero on any error.

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const serverPath = process.argv[2];
if (!serverPath) {
  console.error("usage: node mcp-client.mjs <path-to-mcp-server/index.js>");
  process.exit(2);
}

const transport = new StdioClientTransport({
  command: "node",
  args: [serverPath],
  env: { ...process.env, BRAIN_DIR: process.env.BRAIN_DIR ?? process.cwd() },
});

const client = new Client({ name: "nanobrain-smoke", version: "0.0.1" }, { capabilities: {} });

try {
  await client.connect(transport);

  const tools = await client.listTools();
  console.log("TOOLS:", tools.tools.map((t) => t.name).join(", "));

  const status = await client.callTool({ name: "brain_status", arguments: {} });
  console.log("STATUS_RESPONSE:", JSON.stringify(status).slice(0, 400));

  const list = await client.callTool({ name: "brain_list_by_type", arguments: { type: "person" } });
  console.log("LIST_RESPONSE:", JSON.stringify(list).slice(0, 400));

  await client.close();
  process.exit(0);
} catch (err) {
  console.error("MCP error:", err?.message ?? err);
  process.exit(1);
}
