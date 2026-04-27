---
type: concept
status: active
sensitivity: public
---

# Markdown as substrate

The bet that underlies nanobrain: plain markdown + git scales further than vector DBs and SaaS PKM tools.

## Why it works

- **Greppable forever.** No schema migrations.
- **Inheritable.** `cat brain/self.md` works in 50 years.
- **Multi-agent.** Every LLM tool reads markdown.
- **Diffable.** Git is the time machine.

## Why it might not work

- Search at scale (>100 MB) needs an index, not grep.
- Cross-file relationships need a graph layer (we use `[[wikilinks]]` + `_graph.md`).
- Privacy at the file level is binary — no row-level controls.

## Related

- [[2026-04-12 — markdown ages better than schemas]]
- [[2026-03-04 — switch from Notion to nanobrain]]
