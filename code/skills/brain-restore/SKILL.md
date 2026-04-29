# brain-restore

Safe git wrapper. Lists tags + the last 20 commits, asks for a selection (sha or tag), and creates a `restore/<short-sha>` branch checked out at that point.

**Refuses** `--hard`, `--force`, `--reset`. There is no destructive path.

Run: `bash code/skills/brain-restore/restore.sh [--brain-dir DIR] [--target SHA_OR_TAG]`
