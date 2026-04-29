---
name: brain-hash
description: Compute or verify a SHA-256 integrity hash of the stable brain corpus.
---

# /brain-hash

Stable corpus = `brain/**/*.md` excluding `raw.md`, `interactions.md`, `_graph.md`, and `archive/`.

## Usage

```
hash.sh build        # writes BRAIN_HASH.txt
hash.sh verify       # exits 0 if matches baseline, 1 otherwise
```

Honors `BRAIN_DIR` env (default `$HOME/brain`).

## Portability

Uses `shasum -a 256` if present (macOS), else `sha256sum` (Linux).
