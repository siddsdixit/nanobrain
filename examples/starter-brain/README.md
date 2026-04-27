# Starter brain template

Drop these files into your private brain repo to bootstrap. Edit and personalize.

## Files

- `self.md` — your identity, voice, principles
- `goals.md` — quarterly + 1y + 5y goals
- `projects.md` — active threads (index)
- `people.md` — contacts (index)
- `learnings.md` — append-only insights
- `decisions.md` — decisions log
- `repos.md` — repo registry

## Usage

```bash
cp -R examples/starter-brain/* /path/to/your-brain/brain/
# Edit each file, replace placeholders with your content
git -C /path/to/your-brain add brain/ && git -C /path/to/your-brain commit -m "init brain"
```

Then on each machine: `~/nanobrain/install.sh /path/to/your-brain`.
