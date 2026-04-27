# Distill protocol — <source>

Triggered by `/brain distill <source>` or weekly cron. Reads new entries from `data/<source>/INBOX.md` and routes signal into `brain/`.

## Steps

1. **Read the watermark.** `data/<source>/.distill-watermark` tracks the last-distilled position.

2. **Tail new entries only.**
   ```bash
   awk -v cut="$(cat $HOME/brain/data/<source>/.distill-watermark 2>/dev/null || echo '0000-00-00')" \
     '/^### / && $0 > "### "cut {flag=1} flag' $HOME/brain/data/<source>/INBOX.md
   ```
   Never `cat` the whole file (S2).

3. **For each new entry, classify and route to:**
   - `brain/interactions.md` — if a person was mentioned (always)
   - `brain/people.md` — if it's a NEW person (add a line in the right bucket)
   - `brain/people/<slug>.md` — if recurring (3+ interactions or open commitment)
   - `brain/learnings.md` — if it surfaces an insight worth saving (`### YYYY-MM-DD — title`)
   - `brain/decisions.md` — if it's a material decision with rationale
   - `brain/projects.md` — if it's a status change for an active project
   - `brain/goals.md` — if it shifts a current or future goal

4. **Mirror to `brain/raw.md`** (cross-source firehose) for every distilled signal.

5. **Update watermark.** Write the latest entry's timestamp to `.distill-watermark`.

6. **Commit:**
   ```bash
   cd $HOME/brain
   git add brain/ data/<source>/.distill-watermark
   git -c user.email=you@example.com -c user.name="Your Name" \
     commit -m "distill <source>: <YYYY-MM-DD> — <one-line summary>"
   git push
   ```

## Hard rules

- **Be conservative.** Better to miss a small signal than to pollute `brain/` with noise.
- **Compactness.** Each `brain/` entry should be 1-3 lines. Distill, don't transcribe.
- **No secrets.** Re-apply the privacy filters from `ingest.md` defensively.
- **Match the user's voice.** No em dashes. Short sentences. Imperative.

## Source-specific extraction

<list the patterns specific to this source>
- e.g. for slack: `@<user>` mentions = people; `commit:|TODO:|@channel:` = action items.
- e.g. for granola: `## Action items` block = open commitments; `## Decisions` = decisions.md routes.
- e.g. for repos: `feat:|fix:|chore:` commits + branch names = projects.md status updates.
