# brain-init

First-run wizard. Two questions:

1. work email (blank to skip = solo personal user)
2. personal email

Writes `$BRAIN_DIR/brain/_contexts.yaml` with one or two contexts plus minimal resolvers (gmail by sender domain, claude by project path glob).

Run: `bash code/skills/brain-init/wizard.sh [--brain-dir DIR] [--work EMAIL] [--personal EMAIL]`
