---
name: brain
---

# /brain — gateway

`/brain` is the single entry point. The first word of the input picks the action:

| First word | What happens |
|---|---|
| `sync` / `pull` / `resync` | `git -C $HOME/brain pull --rebase` to fetch latest brain content + machinery from GitHub |
| `update` / `install` / `upgrade` | git pull + re-run `$HOME/brain/code/install.sh` so new skills/hooks land |
| `status` / `health` | Diagnostics: last commit, last evolve, sizes of brain files, hook wiring check |
| `save` | Run the **brain-save** skill (force-save the rest of the input) |
| `compact` | Run the **brain-compact** skill |
| `evolve` / `improve` | Run the **brain-evolve** skill |
| `checkpoint` / `flush` | Run the **brain-checkpoint** skill (force-capture current session, bypass throttle) |
| `ingest <source>` | Run `code/sources/<source>/ingest.sh` (or follow `ingest.md` if no script). Pulls raw → `data/<source>/INBOX.md` |
| `distill <source>` | Follow `code/sources/<source>/distill.md`. Extract signal from INBOX → `brain/`. Commit. |
| `path` / `paths` | Print the canonical file paths for quick reference |
| anything else | Treat the whole input as a **query** against the corpus (default behavior below) |

If the input is a question or no recognized first-word, fall through to **query mode**.

---

## Sub-command handlers

### `sync` / `pull` / `resync`

```bash
cd $HOME/brain && git pull --rebase --autostash
```

Report: number of new commits, list of changed files. If conflicts, abort and show them.

### `update` / `install` / `upgrade`

```bash
cd $HOME/brain && git pull --rebase --autostash && $HOME/brain/code/install.sh
```

Report what changed (file names) and confirm install ran cleanly.

### `status` / `health`

Run these checks (small, fast):

```bash
cd $HOME/brain
git log -1 --pretty=format:'%h %ad %s' --date=short
git log -1 --grep='^evolve' --pretty=format:'last evolve: %ad %s' --date=short
wc -l brain/*.md
ls -la ~/.claude/skills/brain* ~/.claude/CLAUDE.md
test -x $HOME/brain/code/hooks/capture.sh && echo "hook executable: yes" || echo "hook executable: NO"
tail -5 $HOME/brain/data/_logs/capture.log 2>/dev/null  # recent capture runs
test -f $HOME/brain/.capture.lock && echo "warning: capture lock present (PID $(cat $HOME/brain/.capture.lock))"
```

Output a 7-10 line summary: latest commit, last evolve, file sizes, skills present, hook wiring, last 5 capture runs (ok / skip / warn), and any stale lock.

### `save <text>`

Invoke the **brain-save** skill protocol on the rest of the input.

### `compact`

Invoke **brain-compact**.

### `evolve` / `improve`

Invoke **brain-evolve**.

### `checkpoint` / `flush`

Invoke **brain-checkpoint**. Bypass the throttle, force-capture this session immediately. Use when wrapping up a chunk of work in a long-running session.

### `ingest <source>`

```bash
SCRIPT=$HOME/brain/code/sources/<source>/ingest.sh
if [ -x "$SCRIPT" ]; then
  bash "$SCRIPT"
else
  # Follow $HOME/brain/code/sources/<source>/ingest.md manually
  cat $HOME/brain/code/sources/<source>/ingest.md
fi
```

Report: number of new entries appended to `data/<source>/INBOX.md`, new watermark.

### `distill <source>`

Read `code/sources/<source>/distill.md` and follow it exactly. Extract new entries from `data/<source>/INBOX.md` since the distill watermark, route signal to `brain/<category>.md`, mirror to `brain/raw.md`, commit, push. Stay silent if nothing new to distill.

### `path` / `paths`

Print canonical paths:

```
repo:    $HOME/brain
brain:   $HOME/brain/brain/{self,goals,projects,people,learnings,decisions,raw}.md
hooks:   $HOME/brain/code/hooks/{capture.sh,STOP.md}
skills:  $HOME/brain/code/skills/{brain,brain-save,brain-compact,brain-evolve}/
config:  $HOME/brain/claude-config/{CLAUDE.md,settings.json}
github:  https://github.com/<your-brain-repo>
```

---

## Query mode (default)

If nothing routes, treat input as a question against the corpus.

### Steps

1. **Read the corpus.** In order:
   - `$HOME/brain/CONTEXT.md`
   - `$HOME/brain/brain/self.md`
   - `$HOME/brain/brain/goals.md`
   - `$HOME/brain/brain/projects.md`
   - `$HOME/brain/brain/people.md`
   - `$HOME/brain/brain/learnings.md`
   - `$HOME/brain/brain/decisions.md`
   - `$HOME/brain/ROADMAP.md` only if question touches future plans

   **Never read `$HOME/brain/brain/raw.md`** unless the user explicitly asks for firehose history. Even then use `grep` or `tail`, never full read. raw.md is the uncompacted backup, will be huge, will burn tokens.

2. **Answer using only the corpus.** No invention. If not covered, say so.

3. **Cite the source file.** Format: `(brain/decisions.md, 2026-04-26)`.

4. **Be concise.** The user's voice: no em dashes, short sentences. One paragraph or tight bullets. No preamble.

5. **Exploratory questions** ("what should I work on?", "what am I forgetting?"): surface 2-3 relevant items with citations, let the user pick. Don't decide for them.

### Suggest follow-ups when warranted

- If the answer reveals a gap, ask: "Want me to `/brain save` that?"
- If a brain file is over ~500 lines or has obvious staleness, mention `/brain compact` once at the end.
- If the brain hasn't evolved in 7+ days, mention `/brain evolve` once.

## Out of scope

- Don't read `~/.claude/projects/*/memory/` (session-scoped, not brain-canonical).
- Don't fetch from web or GitHub API.
- Don't reason about employer-proprietary data the brain doesn't contain.
