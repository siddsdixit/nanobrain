# Gemini CLI runtime

Google's Gemini CLI runs interactively or one-shot. Both modes work with the generic wrapper.

## Install

```bash
# In ~/.zshrc or ~/.bashrc
alias gemini='$HOME/nanobrain/code/runtimes/wrap.sh gemini'
```

## Read side

Gemini CLI reads `GEMINI.md` at the project root. The `GEMINI.md` shipped at the brain repo root is what loads.

```bash
ln -s $HOME/my-brain/GEMINI.md ./GEMINI.md
```

## Tips

Gemini CLI prints branding and timing data to stderr by default. Capture is unaffected (we tee both streams), but if you want a cleaner transcript:

```bash
alias gemini='$HOME/nanobrain/code/runtimes/wrap.sh gemini --quiet'
```

## Capture verification

```bash
gemini --version
tail -3 $HOME/brain/data/_logs/capture.log
```
