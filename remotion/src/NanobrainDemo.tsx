import { AbsoluteFill, Sequence } from "remotion";
import { Terminal } from "./components/Terminal";
import { Scanlines, Vignette, GridBackground } from "./components/Scanlines";
import { HookScene } from "./scenes/HookScene";
import { HeroScene } from "./scenes/HeroScene";
import { SourcesScene } from "./scenes/SourcesScene";
import { DistillScene } from "./scenes/DistillScene";
import { WhoScene } from "./scenes/WhoScene";
import { ShowScene } from "./scenes/ShowScene";
import { SpawnEvolveScene } from "./scenes/SpawnEvolveScene";
import { UniversalScene } from "./scenes/UniversalScene";
import { ForeverScene } from "./scenes/ForeverScene";

export const FPS = 30;

// Narrative arc — every scene answers "why does this matter".
//   1. HOOK     "your AI sessions live in 3 vendor silos"
//   2. HERO     "nanoBrain — the second brain that thinks like you"
//   3. CAPTURE  "5 sources → invisible 50ms hook → INBOX"
//   4. DISTILL  "INBOX → brain/{decisions, people, projects, learnings}.md
//                 in your voice"
//   5. QUERY    "/brain who is X" — connected answer with backlinks
//   6. CONTEXT  "/brain show <person>" — full bio from corpus
//   7. SPAWN+EVOLVE  "spawn agents · compact weekly · evolve monthly"
//   8. UNIVERSAL "Claude / Codex / Cursor / Gemini / Aider — one brain"
//   9. FOREVER  "cat brain/self.md works in 50 years" → CTA
const SCENES = {
  hook:        140,  // 4.7s
  hero:        220,  // 7.3s
  sources:     220,  // 7.3s — 5 sources flowing through hook to INBOX
  distill:     230,  // 7.7s — brain/*.md files growing in your voice
  who:         140,  // 4.7s — /brain who is X (terminal)
  show:        150,  // 5.0s — /brain show (terminal)
  spawnEvolve: 220,  // 7.3s — spawn / compact / evolve panels
  universal:   190,  // 6.3s — one brain, every agent constellation
  forever:     185,  // 6.2s — cat brain/self.md + brand sign-off + CTA
};

export const DEMO_DURATION_FRAMES =
  SCENES.hook +
  SCENES.hero +
  SCENES.sources +
  SCENES.distill +
  SCENES.who +
  SCENES.show +
  SCENES.spawnEvolve +
  SCENES.universal +
  SCENES.forever;

export const NanobrainDemo = () => {
  let from = 0;
  const at = (key: keyof typeof SCENES) => {
    const start = from;
    from += SCENES[key];
    return start;
  };

  return (
    <AbsoluteFill
      style={{
        fontFamily:
          "ui-monospace, 'JetBrains Mono', 'Fira Code', SF Mono, Menlo, Consolas, monospace",
      }}
    >
      <GridBackground />

      <Sequence from={at("hook")} durationInFrames={SCENES.hook}>
        <HookScene />
      </Sequence>
      <Sequence from={at("hero")} durationInFrames={SCENES.hero}>
        <HeroScene />
      </Sequence>
      <Sequence from={at("sources")} durationInFrames={SCENES.sources}>
        <SourcesScene />
      </Sequence>
      <Sequence from={at("distill")} durationInFrames={SCENES.distill}>
        <DistillScene />
      </Sequence>
      <Sequence from={at("who")} durationInFrames={SCENES.who}>
        <Terminal>
          <WhoScene />
        </Terminal>
      </Sequence>
      <Sequence from={at("show")} durationInFrames={SCENES.show}>
        <Terminal>
          <ShowScene />
        </Terminal>
      </Sequence>
      <Sequence from={at("spawnEvolve")} durationInFrames={SCENES.spawnEvolve}>
        <SpawnEvolveScene />
      </Sequence>
      <Sequence from={at("universal")} durationInFrames={SCENES.universal}>
        <UniversalScene />
      </Sequence>
      <Sequence from={at("forever")} durationInFrames={SCENES.forever}>
        <ForeverScene />
      </Sequence>

      <Vignette />
      <Scanlines />
    </AbsoluteFill>
  );
};
