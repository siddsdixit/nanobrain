# Security

## Reporting a vulnerability

Open a [private security advisory](https://github.com/siddsdixit/nanobrain/security/advisories/new) on GitHub. Do not open a public issue for vulnerabilities.

We aim to acknowledge within 72 hours and ship a fix within 30 days for confirmed issues. If a fix requires a breaking change, we will coordinate disclosure.

## Threat model

nanobrain is a local tool that processes your own data. The realistic threat surface:

- **Secret leakage in commits.** `code/lib/redact.sh` strips known token formats (OpenAI `sk-`, AWS `AKIA`, GitHub `ghp_`, Slack `xoxb-`, JWT bearers, `api_key=`, `password=`) before any LLM call or persistent write. CI tests this on every PR. Best-effort only — `/brain-redact` is the last-resort scrub.
- **Hook execution.** The Stop / SessionEnd / PreCompact hooks are sub-50ms file appends. They never invoke an LLM and never run untrusted input. Distill happens later in an idle-gated drainer, isolated from the user's hot path.
- **MCP read surface.** Agents reading the brain go through `read_brain_file`, which refuses firehoses (`raw.md`, `INBOX.md`) by default and enforces context filters via `_contexts.yaml`.
- **Source isolation.** Each source ingests into `data/<source>/INBOX.md` and never writes outside its own directory. Distill is the only path from INBOX to `brain/`.

## Out of scope

- LLM prompt-injection in distilled content. The brain is your own data; treat distilled output as untrusted input to downstream agents (it is).
- Anything that requires `sudo`. nanobrain never asks for it.
- Sensitive data classes (HIPAA, GDPR-class). Do not point this at sensitive sources. `_contexts.yaml` lets you scope which sources are ingested.

## Hardening recommendations

- Run on disk encryption (FileVault / LUKS).
- Keep your brain repo private.
- If using `--gh-repo`, default visibility is `--private`. Override only with `--public`.
- Review `data/<source>/INBOX.md` before first distill — confirm the redact ran.
