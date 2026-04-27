// MCP smoke client. Spawns the server over stdio, exercises every tool,
// emits machine-readable lines smoke.sh can grep for. Exit non-zero on error.

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

function parseToolText(res) {
  // Tools return { content: [{ type: "text", text: "<json>" }] }
  const txt = res?.content?.[0]?.text ?? "{}";
  try { return JSON.parse(txt); } catch { return {}; }
}

try {
  await client.connect(transport);

  const tools = await client.listTools();
  console.log("TOOLS:", tools.tools.map((t) => t.name).join(", "));

  // brain_status
  const status = parseToolText(await client.callTool({ name: "brain_status", arguments: {} }));
  console.log("STATUS:", JSON.stringify(status).slice(0, 500));

  // brain_search "jane"
  const search = parseToolText(await client.callTool({ name: "brain_search", arguments: { query: "jane" } }));
  const foundJane = (search.results ?? []).some((r) =>
    /jane/i.test(JSON.stringify(r))
  );
  console.log(`SEARCH_HIT_JANE:${foundJane}`);
  console.log("SEARCH_FIRST:", JSON.stringify(search.results?.[0] ?? {}).slice(0, 300));

  // brain_list_by_type person
  const list = parseToolText(await client.callTool({ name: "brain_list_by_type", arguments: { type: "person" } }));
  const hasJane = (list.items ?? []).some((it) => it.slug === "jane-doe");
  console.log(`LIST_PERSON_HAS_JANE:${hasJane}`);
  console.log("LIST_PERSON:", JSON.stringify(list).slice(0, 300));

  // brain_get_entity person/jane-doe
  const ent = parseToolText(await client.callTool({ name: "brain_get_entity", arguments: { type: "person", slug: "jane-doe" } }));
  console.log(`ENTITY_JANE_NAME:${ent.frontmatter?.name ?? "<missing>"}`);
  console.log("ENTITY_BODY:", (ent.body ?? "").slice(0, 200).replace(/\n/g, " "));

  // brain_query_graph (graceful if no _graph.md)
  const graph = parseToolText(await client.callTool({ name: "brain_query_graph", arguments: { query: "jane" } }));
  console.log("GRAPH:", JSON.stringify(graph).slice(0, 200));

  await client.close();
  process.exit(0);
} catch (e) {
  console.error("MCP error:", e?.message ?? e);
  process.exit(1);
}
