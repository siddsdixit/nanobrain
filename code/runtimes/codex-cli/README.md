# Codex CLI runtime

OpenAI's Codex CLI runs to completion, prints conversation to stdout. The generic `runtimes/wrap.sh` handles capture cleanly.

## Install

```bash
# In ~/.zshrc or ~/.bashrc
alias codex='$HOME/nanobrain/code/runtimes/wrap.sh codex'
```

## Read side

Codex honors `AGENTS.md` per the [agents.md](https://agents.md) spec. The `AGENTS.md` shipped at the brain repo root will be loaded automatically when you run `codex` in a directory under your brain repo.

For Codex sessions in any other directory, drop a one-line `AGENTS.md` symlink at the project root pointing to your brain's `AGENTS.md`:

```bash
ln -s $HOME/my-brain/AGENTS.md ./AGENTS.md
```

## Capture verification

```bash
codex --version
tail -3 $HOME/brain/data/_logs/capture.log
```
