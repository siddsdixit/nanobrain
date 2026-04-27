#!/usr/bin/env node
// nanobrain MCP server — exposes the brain as native tools.
// Tool signatures are LOCKED per ADR-0014 / ADR-0015. Implementations iterate.
//
// Status: SKELETON. Tools return placeholder data. Replace stubs with real
// filesystem queries while keeping signatures unchanged.

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import * as fs from "fs/promises";
import * as path from "path";


const server = new Server(
  { name: "nanobrain", version: "0.1.0" },
  { capabilities: { tools: {} } }
);

// ──────────────────────────────────────────────────────────────────────────
// Tool definitions (LOCKED — do not change signatures)
// ──────────────────────────────────────────────────────────────────────────

const TOOLS = [
  {
    name: "brain_search",
    description:
      "Search the brain corpus. Reads brain/{self,goals,projects,people,learnings,decisions,repos}.md and brain/{person,project,decision,concept}/*.md. Never reads raw.md or data/.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Search query" },
        filter: {
          type: "object",
          properties: {
            type: { type: "string", enum: ["person", "project", "decision", "concept"] },
            status: { type: "string", enum: ["active", "archived", "done", "paused"] },
            sensitivity: { type: "string", enum: ["public", "personal", "confidential"] },
            source: { type: "string" },
          },
        },
      },
      required: ["query"],
    },
  },
  {
    name: "brain_get_entity",
    description: "Read a single per-entity file. Returns frontmatter + body + backlinks.",
    inputSchema: {
      type: "object",
      properties: {
        type: { type: "string", enum: ["person", "project", "decision", "concept"] },
        slug: { type: "string", description: "kebab-case slug" },
      },
      required: ["type", "slug"],
    },
  },
  {
    name: "brain_list_by_type",
    description: "Enumerate entities of a type (e.g., all active projects).",
    inputSchema: {
      type: "object",
      properties: {
        type: { type: "string", enum: ["person", "project", "decision", "concept"] },
        filter: {
          type: "object",
          properties: {
            status: { type: "string" },
          },
        },
      },
      required: ["type"],
    },
  },
  {
    name: "brain_relationships",
    description: "What links to / from this entity. Reads brain/_graph.md.",
    inputSchema: {
      type: "object",
      properties: {
        slug: { type: "string" },
      },
      required: ["slug"],
    },
  },
  {
    name: "brain_query_graph",
    description: "Graph queries (e.g., 'all decisions related to project-x').",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string" },
      },
      required: ["query"],
    },
  },
  {
    name: "brain_add_to_inbox",
    description:
      "Append to data/<source>/INBOX.md. The ONLY write tool. Append-only, shell-equivalent.",
    inputSchema: {
      type: "object",
      properties: {
        source: { type: "string", description: "Source slug (e.g., 'slack', 'gmail')" },
        content: { type: "string" },
        metadata: { type: "object" },
      },
      required: ["source", "content"],
    },
  },
  {
    name: "brain_status",
    description: "Diagnostics: vault health, last capture, hash match, pending inboxes.",
    inputSchema: { type: "object", properties: {} },
  },
];

// ──────────────────────────────────────────────────────────────────────────
// Tool handlers (STUBS — implement against filesystem)
// ──────────────────────────────────────────────────────────────────────────

server.setRequestHandler({ method: "tools/list" }, async () => ({ tools: TOOLS }));

server.setRequestHandler({ method: "tools/call" }, async (req) => {
  const { name, arguments: args } = req.params;
  switch (name) {
    case "brain_search":
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                stub: true,
                query: args.query,
                filter: args.filter || null,
                results: [],
                note: "TODO: implement grep across brain/*.md and per-entity folders. Skip raw.md, interactions.md, data/.",
              },
              null,
              2
            ),
          },
        ],
      };

    case "brain_get_entity":
      return await getEntityStub(args.type, args.slug);

    case "brain_list_by_type":
      return await listByTypeStub(args.type, args.filter);

    case "brain_relationships":
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                stub: true,
                slug: args.slug,
                incoming: [],
                outgoing: [],
                note: "TODO: parse brain/_graph.md and return incoming/outgoing wikilinks.",
              },
              null,
              2
            ),
          },
        ],
      };

    case "brain_query_graph":
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                stub: true,
                query: args.query,
                nodes: [],
                edges: [],
                note: "TODO: implement graph query over _graph.md.",
              },
              null,
              2
            ),
          },
        ],
      };

    case "brain_add_to_inbox":
      return await addToInboxStub(args.source, args.content, args.metadata);

    case "brain_status":
      return await statusStub();

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
});

// ──────────────────────────────────────────────────────────────────────────
// Stub implementations (replace these incrementally)
// ──────────────────────────────────────────────────────────────────────────

async function getEntityStub(type, slug) {
  const filePath = path.join(BRAIN_DIR, "brain", type, `${slug}.md`);
  try {
    const body = await fs.readFile(filePath, "utf8");
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({ path: filePath, body, backlinks: "TODO from _graph.md" }, null, 2),
        },
      ],
    };
  } catch (e) {
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({ error: `not found: ${type}/${slug}`, path: filePath }, null, 2),
        },
      ],
    };
  }
}

async function listByTypeStub(type, filter) {
  const dir = path.join(BRAIN_DIR, "brain", type);
  try {
    const files = await fs.readdir(dir);
    const items = files
      .filter((f) => f.endsWith(".md") && f !== "README.md")
      .map((f) => ({ slug: f.replace(/\.md$/, "") }));
    return {
      content: [{ type: "text", text: JSON.stringify({ type, count: items.length, items }, null, 2) }],
    };
  } catch (e) {
    return {
      content: [{ type: "text", text: JSON.stringify({ error: e.message }, null, 2) }],
    };
  }
}

async function addToInboxStub(source, content, metadata) {
  const inboxDir = path.join(BRAIN_DIR, "data", source);
  const inboxPath = path.join(inboxDir, "INBOX.md");
  await fs.mkdir(inboxDir, { recursive: true });
  const ts = new Date().toISOString().replace("T", " ").slice(0, 16);
  const block = `\n\n### ${ts} — ${source} — via MCP\n\n${content}\n`;
  await fs.appendFile(inboxPath, block);
  return {
    content: [{ type: "text", text: JSON.stringify({ path: inboxPath, success: true, ts }, null, 2) }],
  };
}

async function statusStub() {
  const hashFile = path.join(BRAIN_DIR, "BRAIN_HASH.txt");
  let hashOk = "unknown";
  try {
    await fs.stat(hashFile);
    hashOk = "present";
  } catch {
    hashOk = "missing";
  }
  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(
          {
            brain_dir: BRAIN_DIR,
            hash_file: hashOk,
            note: "TODO: real status — last commit, last capture, hash verify, pending inboxes",
          },
          null,
          2
        ),
      },
    ],
  };
}

// ──────────────────────────────────────────────────────────────────────────
// Boot
// ──────────────────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
console.error(`[nanobrain MCP] running. BRAIN_DIR=${BRAIN_DIR}`);
