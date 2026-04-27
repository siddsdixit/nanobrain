# Contributing to nanobrain

Thanks for considering a contribution. nanobrain is the open-source framework powering personal context corpora — your private content stays in your private repo.

## Quickstart for contributors

```bash
gh repo fork siddsdixit/nanobrain --clone
cd nanobrain
# Make changes
git commit -m "<type>: <short description>"
gh pr create
```

## What we accept

### Source integrations (highest leverage)

Adding a new ingest pipeline (Slack, Notion, Linear, etc.) is the most valuable contribution. Pattern:

```bash
cp -R code/sources/_TEMPLATE code/sources/<your-source>
# Edit README.md, ingest.md, distill.md
# Test with a small INBOX
```

See `code/sources/README.md` and `code/sources/_TEMPLATE/`.

### Skills

New `/brain-*` skills under `code/skills/<name>/`. Must:
- Be a single markdown file with Anthropic-standard frontmatter (`name`, `description`).
- Respect `code/SAFETY.md` invariants (no firehose reads, no secret exposure, etc.).
- Match nanobrain's voice in examples (no em dashes, short imperative sentences).

### Agent templates

Add reference agents to `code/agents/_TEMPLATE.md` derivatives — but ONLY templates. Personal/instantiated agents stay in your private brain.

### MCP server tools

Implement stub functions in `code/mcp-server/index.js`. Tool signatures are LOCKED (see `code/mcp-server/README.md`). Don't change signatures; iterate implementations.

### Documentation

Improve `docs/ARCHITECTURE.md`, `docs/GETTING-STARTED.md`, `docs/VISION.md`, or per-folder READMEs. PRs welcome.

### ADRs

Architectural changes require an ADR in `docs/adr/`. Use the template structure (Context / Decision / Consequences / Alternatives / Related).

## What we don't accept

- **Vendor-locked code.** No proprietary SaaS dependencies. Markdown + git + (optional) MCP only.
- **Personal content.** Don't include your own brain. Use `examples/starter-brain/` for shareable templates.
- **Schema-breaking changes** to frontmatter fields. Adding optional fields is OK; removing/renaming is forbidden (S24).
- **Compromised safety invariants.** S1–S29 + M1–M5 in `code/SAFETY.md` are non-negotiable. PRs that weaken them will be rejected.

## Code style

- Bash: posix-compatible where possible, macOS bash 3.2 compatible (no `mapfile`, no `[[ ]]` in scripts).
- JavaScript (MCP): ESM, no TypeScript, minimal dependencies.
- Markdown: short imperative sentences, no em dashes, ATX headings.

## Pull request etiquette

- One logical change per PR.
- Include a one-line "why" in the PR description.
- Reference any ADR(s) the change relates to.
- If adding a new file type or directory: include an ADR.

## License

By contributing, you agree your contribution is licensed under MIT.

## Code of conduct

Be kind. Take feedback gracefully. Ship.
