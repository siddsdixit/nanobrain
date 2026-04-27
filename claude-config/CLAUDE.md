# Global Rules — template

_Synced via your private brain repo. Edit this file, commit, push; every machine picks it up on next pull (or instantly if symlinked)._

This is a **template**. Replace anything that doesn't apply to you. The defaults below are what `nanobrain` ships with; override freely.

- State design approach (2-3 sentences) before coding. Wait for confirmation on non-trivial work.
- Max 4 files per response unless purely mechanical.
- Never scaffold/create files unless asked. Prefer editing existing files.
- Never create parallel implementations. Ask: replace or integrate?
- Read existing code first. Match existing patterns.
- When in doubt, ask.

## Style

- Be direct. No preamble. Report problem first, extras under "Also noted:".
- One sentence per decision. Suggest simpler approaches before implementing.
- No em dashes. Use commas, periods, parentheses.

## Code

- Minimal code. Every line justifies its existence. No dead code.
- No premature abstractions (3+ repetitions before extracting).
- Self-documenting names. Comments only for "why".
- One function = one thing. Flat over nested. Early returns.

## Constraints

- Only solve what was asked. No extra features, flags, refactors, or error handling for impossible scenarios.
- No new dependencies without flagging. No TODO comments unless requested.
- Commits: `type: short description`. Small, one logical change each.
- Flag any new patterns that don't match existing architecture.

## Working agreement (the user's defaults — customize freely)

**The process mirrors the product:** Spec → Design → Architecture → Development Plan → Tested Deployed Code. Follow this for every task:
1. Understand what's being asked (spec)
2. Design the approach (2-3 sentences max)
3. Build it. Simple architecture, simple services, scalable but cheap.
4. Test it, deploy it, push it.

**Core principles:**
- **Don't overcomplicate.** Simple > clever. Optimize for writing fast, developing fast.
- **Go autonomous** when the user says "build it" or "fix everything." Don't ask permission on each step.
- **Batch deploys.** Don't deploy after every edit. Deploy when the user says "deploy" or when a logical batch is done.
- **Screenshots = bugs.** When the user shares a screenshot, find and fix the visual issue immediately.
- **Fix and show**, not "here are 3 options." Default to opinionated execution.
- **Match references exactly.** "Make it look like X" means pixel-level match, not "inspired by."
- **Think in product, not code.** Translate business intent to implementation without asking for specs.
- **Push to GitHub after significant work.** Multi-machine workflows are common.
- **Flag IP/legal risks** proactively (employer IP, open-source licenses, competitor claims).
- **Simulate before deploying.** Test locally first. Don't deploy untested code to production.
- **Parse voice-to-text intent.** If the user uses voice input, expect typos and run-ons. Parse meaning, don't ask for clarification.

## Session Maintenance

- At the end of every session, update `TODO.md` in the project root with completed items (check them off) and any new items discovered during the session.
- Keep `TODO.md` as the living roadmap. It should always reflect current state.
- When starting a new session, read `TODO.md` first to understand what's pending.

# brain (auto-loaded — install.sh wires this to your private brain repo's CLAUDE.md)
# install.sh writes the absolute import line below this comment, e.g.:
#   @/Users/you/your-brain/CLAUDE.md
