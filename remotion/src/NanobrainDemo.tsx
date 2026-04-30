import { AbsoluteFill, Sequence } from "remotion";
import { Terminal } from "./components/Terminal";
import { Scanlines, Vignette, GridBackground } from "./components/Scanlines";
import { HeroScene } from "./scenes/HeroScene";
import { StatusScene } from "./scenes/StatusScene";
import { WhoScene } from "./scenes/WhoScene";
import { ListScene } from "./scenes/ListScene";
import { ShowScene } from "./scenes/ShowScene";
import { ClosingScene } from "./scenes/ClosingScene";

export const FPS = 30;

// Scene durations in frames. Total ≈ 26s.
// Hero recreates the nanobrain.app landing page in motion: tag → brand
// → tagline → lede → CTAs → install command → meta line. Then terminal demos.
const SCENES = {
  hero: 220,    // 7.3s — full hero showcase
  status: 90,   // 3.0s
  who: 130,    // 4.3s
  list: 90,    // 3.0s
  show: 150,   // 5.0s — bio scene
  closing: 130,// 4.3s — brand sign-off + agents + URL
};

export const DEMO_DURATION_FRAMES =
  SCENES.hero + SCENES.status + SCENES.who + SCENES.list + SCENES.show + SCENES.closing;

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

      <Sequence from={at("hero")} durationInFrames={SCENES.hero}>
        <HeroScene />
      </Sequence>
      <Sequence from={at("status")} durationInFrames={SCENES.status}>
        <Terminal>
          <StatusScene />
        </Terminal>
      </Sequence>
      <Sequence from={at("who")} durationInFrames={SCENES.who}>
        <Terminal>
          <WhoScene />
        </Terminal>
      </Sequence>
      <Sequence from={at("list")} durationInFrames={SCENES.list}>
        <Terminal>
          <ListScene />
        </Terminal>
      </Sequence>
      <Sequence from={at("show")} durationInFrames={SCENES.show}>
        <Terminal>
          <ShowScene />
        </Terminal>
      </Sequence>
      <Sequence from={at("closing")} durationInFrames={SCENES.closing}>
        <ClosingScene />
      </Sequence>

      <Vignette />
      <Scanlines />
    </AbsoluteFill>
  );
};
