---
name: brain-save
---

# /brain-save

Use when something happens mid-session that's worth keeping in the brain right now: a real decision, a hard-earned insight, a project-status change, a new collaborator, a shift in priorities, or a voice/style correction that should persist.

## Steps

1. Identify what's worth saving. Be ruthless. If it would be obvious from a future `git log`, skip it. Only save what's non-obvious or strategic.

2. Categorize as one of: `self`, `goals`, `projects`, `people`, `learnings`, `decisions`.

3. Format the entry to match the file's existing style:
   - `learnings.md` and `decisions.md`: prefix with `### YYYY-MM-DD — short title`
   - Others: prose or bullets, terse, the user's voice (no em dashes, short sentences).

4. Append to `$HOME/brain/brain/<category>.md` (use Edit or Bash append).

5. **Mandatory:** also append to `$HOME/brain/brain/raw.md` via shell only. The mirror rule is non-negotiable: if it lands in `brain/`, it lands in `raw.md`. **Never Read or Edit raw.md.** Shell-append blind:
   ```bash
   printf '\n\n### %s — %s — %s\n\n%s\n' "$(date +%Y-%m-%d\ %H:%M)" "<category>" "<title>" "<entry>" >> $HOME/brain/brain/raw.md
   ```

6. Commit and push:
   ```bash
   cd $HOME/brain
   git add brain/
   git commit -m "save: <category> — <short title>"
   git push
   ```

## Voice rules

- No em dashes.
- Short sentences. One idea each.
- Imperative voice.
- No preamble.

## What NOT to save

- Ephemeral session state (current task, in-progress work).
- Anything reconstructable from git history of working repos.
- Things already in CLAUDE.md or other framework docs.
- Routine debugging steps.

If unsure, ask the user: "save this as a learning or skip?"
