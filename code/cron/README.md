# code/cron/ — sleep cycle launchd templates

Per ADR-0016 T10: weekly `/brain-compact` (REM) and monthly `/brain-evolve` (deep sleep).

## Install (one-time, on each Mac)

```bash
cp $HOME/brain/code/cron/com.nanobrain.compact.plist ~/Library/LaunchAgents/
cp $HOME/brain/code/cron/com.nanobrain.evolve.plist  ~/Library/LaunchAgents/

launchctl load ~/Library/LaunchAgents/com.nanobrain.compact.plist
launchctl load ~/Library/LaunchAgents/com.nanobrain.evolve.plist
```

## Verify

```bash
launchctl list | grep nanobrain
# expected: com.nanobrain.compact and com.nanobrain.evolve listed
```

## Schedule

- **com.nanobrain.compact** — every Sunday 02:00 local time. Runs `/brain-compact`.
- **com.nanobrain.evolve** — 1st of each month at 03:00. Runs `/brain-evolve`.

Tweak times by editing the plist before installing.

## Logs

- stdout: `/tmp/nanobrain-{compact,evolve}.out`
- stderr: `/tmp/nanobrain-{compact,evolve}.err`
- Internal capture log: `$HOME/brain/data/_logs/{compact,evolve}.log`

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.nanobrain.compact.plist
launchctl unload ~/Library/LaunchAgents/com.nanobrain.evolve.plist
rm ~/Library/LaunchAgents/com.nanobrain.compact.plist
rm ~/Library/LaunchAgents/com.nanobrain.evolve.plist
```

## Why launchd, not cron

macOS native; survives reboots; reliable when laptop is asleep at scheduled time (will run when next awake).

## Linked

- ADR-0016 T10 sleep cycles
- `code/skills/brain-compact/SKILL.md`
- `code/skills/brain-evolve/SKILL.md`
