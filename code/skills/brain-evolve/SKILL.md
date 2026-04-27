---
name: brain-evolve
---

# /brain-evolve

The brain looks at itself, learns from the last week of captures, and improves its own machinery. ONE improvement per run. Always a git commit.

## When to run

- **Weekly** by default (e.g. every Sunday).
- **On demand** when the user notices the capture is missing things, being noisy, or a skill is unclear.
- **After a `/brain-compact`** to lock in any new patterns surfaced during compaction.

## Steps

### 1. Survey activity (no big reads)

```bash
# What's been captured recently — tail only, never full read
tail -300 $HOME/brain/brain/raw.md
git -C $HOME/brain log --since="7 days ago" --pretty=format:"%h %s" --stat
ls -la $HOME/brain/code/skills/ $HOME/brain/code/hooks/
wc -l $HOME/brain/brain/*.md
```

Read in full (small files):
- `$HOME/brain/code/hooks/STOP.md`
- `$HOME/brain/code/hooks/capture.sh`
- Each `$HOME/brain/code/skills/*/SKILL.md`

### 2. Find one pattern worth improving

Look for ANY one of:
- **Captures repeatedly missing a category** → STOP.md needs a sharper rule.
- **Captures that should have been combined** → STOP.md needs a "merge if same topic" rule.
- **A skill whose instructions the user had to correct** → SKILL.md is unclear.
- **Recurring insight type that lacks a home** → propose a new category file.
- **A bash command that failed in a hook log** → fix capture.sh.
- **A repeated learning that should be promoted to self.md or operating-principles** → propose self.md edit.
- **Token-burn risk** → add a "skip / shell-only" rule somewhere.
- **A workflow the user runs constantly that should be a new skill** → propose a new SKILL.md.

If nothing local surfaces, **look at adjacent agent runtimes** for cross-pollination before giving up:

```bash
# Skills, hooks, prompts already proven in your other agent runtimes
ls ~/.openclaw/skills/ 2>/dev/null
```

Look at any `SOUL.md`, `IDENTITY.md`, `HEARTBEAT.md`, `AGENTS.md` patterns proven in adjacent runtimes. If one of those would tighten the brain's protocol or fill a gap, port the idea. Cite the source path in the commit message.

If still nothing surfaces, exit silently with `evolve: nothing to change this week`. Don't manufacture changes.

### 3. Propose ONE change

Make exactly one targeted change. Allowed edit surfaces:
- `code/hooks/STOP.md`
- `code/hooks/capture.sh`
- `code/skills/*/SKILL.md`
- `code/install.sh`
- `claude-config/CLAUDE.md`
- `claude-config/settings.json`
- `README.md` / `CONTEXT.md` / `ROADMAP.md`
- `brain/self.md` (only for promoting a recurring principle, never bulk edits)

NOT allowed:
- `brain/raw.md` (immutable history)
- `brain/learnings.md`, `brain/decisions.md`, `brain/projects.md`, `brain/goals.md`, `brain/people.md` (those are captured content, not machinery)
- `brain/archive/*`

### 4. Show the diff to the user before committing

```bash
git -C $HOME/brain diff
```

If the user approves (or in autonomous mode, if the change is small and bounded), commit:

```bash
cd $HOME/brain
git add <only-the-files-changed>
git -c user.email=you@example.com -c user.name="Your Name" \
  commit -m "evolve: <YYYY-MM-DD> — <one-line what+why>"
git push
```

Always also append the change reason to raw.md (shell-append, never Read):

```bash
printf '\n\n### %s — evolve — %s\n\n%s\n' "$(date +%Y-%m-%d\ %H:%M)" "<title>" "<reasoning>" >> $HOME/brain/brain/raw.md
git -C $HOME/brain add brain/raw.md
git -C $HOME/brain commit --amend --no-edit
git -C $HOME/brain push --force-with-lease
```

### 5. Report

One line. What changed and why. Example: "Tightened STOP.md to merge captures that touch the same project within 30 minutes; was creating duplicate projects.md entries."

## Hard rules

**Read `code/SAFETY.md` before proposing any edit. Refuse to weaken any S* invariant.**

- **One change per run.** Self-improvement compounds; sprawling edits cause drift.
- **Every change is a commit.** Every commit is reversible. `git revert <sha>` if it makes things worse.
- **Never edit captured brain content** (`brain/learnings.md`, `decisions.md`, `projects.md`, `goals.md`, `people.md`, `interactions.md`, `raw.md`). Those are user-and-hook-owned. (S3, S4, M4)
- **Never delete files.** Move to `archive/` or rename. Deletion loses history. (S4)
- **Never modify the recursion guard** (`NANOBRAIN_CAPTURING` in capture.sh, `stop_hook_active` check). Load-bearing safety. (S1)
- **Never raise token budget rules.** Always lower or hold. (S6)
- **Never add a step that reads `raw.md`, `interactions.md`, or `data/**/INBOX.md` in full.** (S2)
- **No new dependencies** without explicitly flagging to the user first.
- **Match the user's voice.** No em dashes. Short sentences. Imperative.

## Validation before commit (S* compliance check)

After staging any change but before committing, verify:

```bash
# S1 — recursion guard intact
grep -q 'NANOBRAIN_CAPTURING' $HOME/brain/code/hooks/capture.sh || { echo "S1 broken"; exit 1; }
grep -q 'stop_hook_active' $HOME/brain/code/hooks/capture.sh || { echo "S1 broken"; exit 1; }

# Brain files all present
for f in self goals projects people learnings decisions raw interactions repos; do
  test -f $HOME/brain/brain/$f.md || { echo "missing brain/$f.md"; exit 1; }
done

# install.sh executable + has skill loop
test -x $HOME/brain/code/install.sh || { echo "install.sh not executable"; exit 1; }
grep -q 'for SKILL in' $HOME/brain/code/install.sh || { echo "install.sh skill loop missing"; exit 1; }
```

If any check fails, abort. Restore from `code/_backup/` (created before risky edits per M5) or `git checkout HEAD -- <file>`.

## Safety

If anything looks suspicious in the diff (binary content, removed safety guards, expanded scope), abort and report instead of committing. Tell the user what you would have done and why you stopped.

## Auto-rollback

If the next session's hook fails or produces broken captures, and the most recent commit on `main` is an `evolve:` commit, suggest: `git revert <sha>` to undo the last evolution.
