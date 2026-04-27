---
name: brain-hash
description: Compute and verify integrity hash of the brain corpus. Detects corruption (T15, S16). Run as part of /brain-compact or manually.
---

# /brain-hash

Integrity audit. Computes a SHA-256 hash of all brain content (excluding firehoses + auto-generated files) and writes it to `BRAIN_HASH.txt`. On verification, compares current hash to stored. Mismatch = corruption alarm.

## Build (regenerate hash)

```bash
bash $HOME/brain/code/skills/brain-hash/build.sh
```

## Verify

```bash
bash $HOME/brain/code/skills/brain-hash/build.sh --verify
```

Exit 0 = match. Exit 1 = mismatch (alarm).

## What gets hashed

All files in `brain/` EXCEPT:
- `raw.md`, `interactions.md` (firehoses, change every capture)
- `_graph.md` (auto-generated, regenerated on compaction)
- `archive/` (rotated history)

That is: hash represents the **stable, distilled corpus** at compaction time.

## When to run

- **As part of `/brain-compact`** (weekly) — establish a new hash baseline.
- **At session start** (optional) — verify nothing changed unexpectedly between sessions.
- **Before sharing any brain content** (e.g., copying brain/self.md to ChatGPT) — confirm integrity.

## Linked

- ADR-0013 (T15 detectable corruption)
- `code/SAFETY.md` invariant S16
