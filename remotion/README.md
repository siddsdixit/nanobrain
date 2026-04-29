# remotion/

Programmatic video for the README hero. React + Remotion. Renders to MP4 (high quality) and GIF (for GitHub embed).

## One-time setup

```bash
cd remotion
npm install
```

## Render

```bash
# MP4 only (fast):
npm run build

# MP4 + GIF (the GIF lands in ../assets/demo.gif, ready for the README):
npm run build:gif
```

Output:
- `out/demo.mp4` — H.264, ~17 seconds, 1280×720
- `../assets/demo.gif` — 1100px wide, 20fps, palette-quantized for size

## Iterate live

```bash
npm start         # opens the Remotion studio at http://localhost:3000
```

## Edit

- `src/NanobrainDemo.tsx` — top-level composition, scene durations
- `src/scenes/*.tsx` — one file per command/output pair
- `src/components/Terminal.tsx` — the macOS-window-chrome wrapper
- `src/components/Title.tsx`, `ClosingScene.tsx` — bookends

## Why Remotion

VHS works for CLI tools when ttyd cooperates. On this Mac it doesn't. Remotion runs entirely in headless Chromium that Remotion downloads and manages. Always renders. Always looks the same.
