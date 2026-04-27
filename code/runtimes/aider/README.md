# Aider runtime

Aider is interactive (REPL-style). The wrapper captures the full session transcript on exit (when you `/exit` or close the REPL).

## Install

```bash
# In ~/.zshrc or ~/.bashrc
alias aider='$HOME/nanobrain/code/runtimes/wrap.sh aider'
```

## Read side

Aider honors `AGENTS.md`. Same symlink pattern as Codex.

## Tips

- Aider's own `/save` command writes to its chat history; our wrapper captures the full session output. They don't conflict.
- For long aider sessions, use `/brain-checkpoint` from a parallel Claude Code window to flush state mid-session. Aider's transcript gets captured at exit.

## Capture verification

```bash
aider --version
tail -3 $HOME/brain/data/_logs/capture.log
```
