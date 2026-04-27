#!/usr/bin/env node
// nanobrain MCP server — exposes the brain as native tools.
// Tool signatures are LOCKED per ADR-0014 / ADR-0015. Implementations iterate.

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import * as fs from "fs/promises";
import * as path from "path";

const BRAIN_DIR = process.env.BRAIN_DIR ?? `${process.env.HOME}/brain`;
const CORPUS_INDEXES = ["self", "goals", "projects", "people", "learnings", "decisions", "repos"];
const ENTITY_TYPES = ["person", "project", "decision", "concept"];

const server = new Server(
  { name: "nanobrain", version: "0.2.0" },
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
            type: { type: "string", enum: ENTITY_TYPES },
            sensitivity: { type: "string", enum: ["public", "personal", "confidential"] },
          },
        },
        limit: { type: "number", description: "Max results (default 10)" },
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
        type: { type: "string", enum: ENTITY_TYPES },
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
        type: { type: "string", enum: ENTITY_TYPES },
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
    description: "Filter brain/_graph.md entries by a query string.",
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
// Helpers
// ──────────────────────────────────────────────────────────────────────────

function parseFrontmatter(text) {
  // Minimal YAML: handles `key: value` and `key: [a, b]` flat style.
  // Brain files use a small, fixed schema; full YAML parsing is overkill.
  if (!text.startsWith("---\n")) return { frontmatter: {}, body: text };
  const end = text.indexOf("\n---\n", 4);
  if (end === -1) return { frontmatter: {}, body: text };
  const yaml = text.slice(4, end);
  const body = text.slice(end + 5);
  const frontmatter = {};
  for (const line of yaml.split("\n")) {
    const m = line.match(/^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$/);
    if (!m) continue;
    let val = m[2].trim();
    if (val.startsWith("[") && val.endsWith("]")) {
      val = val.slice(1, -1).split(",").map((s) => s.trim().replace(/^["']|["']$/g, "")).filter(Boolean);
    } else {
      val = val.replace(/^["']|["']$/g, "");
    }
    frontmatter[m[1]] = val;
  }
  return { frontmatter, body };
}

async function safeReadFile(p) {
  try { return await fs.readFile(p, "utf8"); } catch { return null; }
}

async function safeReaddir(p) {
  try { return await fs.readdir(p); } catch { return []; }
}

function ok(payload) {
  return { content: [{ type: "text", text: JSON.stringify(payload, null, 2) }] };
}
function err(message) {
  return { content: [{ type: "text", text: JSON.stringify({ error: message }, null, 2) }], isError: true };
}

// Walk every queryable file in the corpus. Skips raw.md, interactions.md, data/.
async function listCorpusFiles() {
  const files = [];
  for (const idx of CORPUS_INDEXES) {
    const p = path.join(BRAIN_DIR, "brain", `${idx}.md`);
    files.push(p);
  }
  for (const t of ENTITY_TYPES) {
    const dir = path.join(BRAIN_DIR, "brain", t);
    for (const name of await safeReaddir(dir)) {
      if (name.endsWith(".md") && name !== "README.md") files.push(path.join(dir, name));
    }
  }
  return files;
}

function snippet(body, query, ctx = 80) {
  const idx = body.toLowerCase().indexOf(query.toLowerCase());
  if (idx === -1) return body.slice(0, ctx * 2);
  const start = Math.max(0, idx - ctx);
  const end = Math.min(body.length, idx + query.length + ctx);
  return (start > 0 ? "…" : "") + body.slice(start, end) + (end < body.length ? "…" : "");
}

// ──────────────────────────────────────────────────────────────────────────
// Tool implementations
// ──────────────────────────────────────────────────────────────────────────

async function brainSearch({ query, filter = {}, limit = 10 }) {
  if (!query) return err("query is required");
  const q = query.toLowerCase();
  const results = [];
  for (const filePath of await listCorpusFiles()) {
    const content = await safeReadFile(filePath);
    if (!content) continue;

    // Type filter: brain/<type>/<slug>.md
    if (filter.type) {
      const rel = path.relative(path.join(BRAIN_DIR, "brain"), filePath);
      const segs = rel.split(path.sep);
      if (segs[0] !== filter.type) continue;
    }

    const { frontmatter, body } = parseFrontmatter(content);
    if (filter.sensitivity && frontmatter.sensitivity !== filter.sensitivity) continue;

    const lc = body.toLowerCase();
    if (!lc.includes(q)) continue;

    // Score: count of matches, with a bonus for matching the title
    const count = (lc.match(new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g")) || []).length;
    const titleBonus = frontmatter.name?.toLowerCase().includes(q) ? 5 : 0;
    results.push({
      path: path.relative(BRAIN_DIR, filePath),
      score: count + titleBonus,
      snippet: snippet(body, query),
      frontmatter,
    });
  }
  results.sort((a, b) => b.score - a.score);
  return ok({ query, count: results.length, results: results.slice(0, limit) });
}

async function brainGetEntity({ type, slug }) {
  if (!ENTITY_TYPES.includes(type)) return err(`type must be one of ${ENTITY_TYPES.join(", ")}`);
  const filePath = path.join(BRAIN_DIR, "brain", type, `${slug}.md`);
  const content = await safeReadFile(filePath);
  if (!content) return err(`not found: ${type}/${slug}.md`);
  const { frontmatter, body } = parseFrontmatter(content);

  // Backlinks from _graph.md (if present)
  const backlinks = await readBacklinks(slug);

  return ok({ path: path.relative(BRAIN_DIR, filePath), frontmatter, body, backlinks });
}

async function brainListByType({ type, filter = {} }) {
  if (!ENTITY_TYPES.includes(type)) return err(`type must be one of ${ENTITY_TYPES.join(", ")}`);
  const dir = path.join(BRAIN_DIR, "brain", type);
  const files = await safeReaddir(dir);
  const items = [];
  for (const name of files) {
    if (!name.endsWith(".md") || name === "README.md") continue;
    const slug = name.replace(/\.md$/, "");
    const content = await safeReadFile(path.join(dir, name));
    const { frontmatter } = content ? parseFrontmatter(content) : { frontmatter: {} };
    if (filter.status && frontmatter.status !== filter.status) continue;
    items.push({ slug, frontmatter });
  }
  return ok({ type, count: items.length, items });
}

async function readBacklinks(slug) {
  const graphPath = path.join(BRAIN_DIR, "brain", "_graph.md");
  const content = await safeReadFile(graphPath);
  if (!content) return [];
  // _graph.md format: sections per entity, with file:line references.
  // Find the section for `slug` (case-insensitive).
  const lines = content.split("\n");
  const backlinks = [];
  let inSection = false;
  const heading = new RegExp(`^##+\\s.*\\b${slug}\\b`, "i");
  for (const line of lines) {
    if (line.match(/^##+\s/)) inSection = heading.test(line);
    else if (inSection && line.trim().startsWith("-")) backlinks.push(line.trim().slice(1).trim());
  }
  return backlinks;
}

async function brainRelationships({ slug }) {
  if (!slug) return err("slug is required");
  const backlinks = await readBacklinks(slug);
  return ok({ slug, incoming: backlinks, outgoing: [], note: "outgoing edges require entity-file scan; not yet implemented" });
}

async function brainQueryGraph({ query }) {
  if (!query) return err("query is required");
  const graphPath = path.join(BRAIN_DIR, "brain", "_graph.md");
  const content = await safeReadFile(graphPath);
  if (!content) return ok({ query, matches: [], note: "_graph.md not found; run /brain-graph build" });
  const q = query.toLowerCase();
  const matches = content.split("\n").filter((line) => line.toLowerCase().includes(q));
  return ok({ query, count: matches.length, matches: matches.slice(0, 50) });
}

async function brainAddToInbox({ source, content, metadata }) {
  if (!source || !content) return err("source and content are required");
  const inboxDir = path.join(BRAIN_DIR, "data", source);
  const inboxPath = path.join(inboxDir, "INBOX.md");
  await fs.mkdir(inboxDir, { recursive: true });
  const ts = new Date().toISOString().replace("T", " ").slice(0, 16);
  const metaLine = metadata ? `\n_meta: ${JSON.stringify(metadata)}_\n` : "";
  const block = `\n\n### ${ts} — ${source} — via MCP\n${metaLine}\n${content}\n`;
  await fs.appendFile(inboxPath, block);
  return ok({ path: path.relative(BRAIN_DIR, inboxPath), success: true, ts });
}

async function brainStatus() {
  const out = { brain_dir: BRAIN_DIR };

  // Hash file presence
  const hashFile = path.join(BRAIN_DIR, "BRAIN_HASH.txt");
  out.hash_file = (await safeReadFile(hashFile)) ? "present" : "missing";

  // Index file sizes
  out.indexes = {};
  for (const idx of CORPUS_INDEXES) {
    const p = path.join(BRAIN_DIR, "brain", `${idx}.md`);
    const c = await safeReadFile(p);
    out.indexes[idx] = c ? `${c.length} bytes` : "missing";
  }

  // Per-entity counts
  out.entities = {};
  for (const t of ENTITY_TYPES) {
    const files = (await safeReaddir(path.join(BRAIN_DIR, "brain", t)))
      .filter((n) => n.endsWith(".md") && n !== "README.md");
    out.entities[t] = files.length;
  }

  // Pending inboxes
  out.inboxes = {};
  for (const name of await safeReaddir(path.join(BRAIN_DIR, "data"))) {
    if (name.startsWith("_")) continue;
    const inboxPath = path.join(BRAIN_DIR, "data", name, "INBOX.md");
    const c = await safeReadFile(inboxPath);
    if (c) out.inboxes[name] = `${c.length} bytes`;
  }

  return ok(out);
}

// ──────────────────────────────────────────────────────────────────────────
// Wiring
// ──────────────────────────────────────────────────────────────────────────

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;
  try {
    switch (name) {
      case "brain_search":         return await brainSearch(args ?? {});
      case "brain_get_entity":     return await brainGetEntity(args ?? {});
      case "brain_list_by_type":   return await brainListByType(args ?? {});
      case "brain_relationships":  return await brainRelationships(args ?? {});
      case "brain_query_graph":    return await brainQueryGraph(args ?? {});
      case "brain_add_to_inbox":   return await brainAddToInbox(args ?? {});
      case "brain_status":         return await brainStatus();
      default:                     return err(`unknown tool: ${name}`);
    }
  } catch (e) {
    return err(e?.message ?? String(e));
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
console.error(`[nanobrain MCP] running. BRAIN_DIR=${BRAIN_DIR}`);
