---
name: brain-checkpoint
description: Force a capture bypassing the throttle. Runs capture.sh with FORCE_CAPTURE=1.
---

# /brain-checkpoint

Sets `FORCE_CAPTURE=1`, builds a synthetic Stop payload, and invokes `code/hooks/capture.sh`.

## Usage

```
checkpoint.sh
```

## Env

- `BRAIN_DIR` (default `$HOME/brain`)
- `NANOBRAIN_DIR` (default `$HOME/Documents/nanobrain-v2`)
- `NANOBRAIN_CAPTURE_STUB` -- path to script invoked instead of `code/hooks/capture.sh`. Used by tests to verify env passing.
