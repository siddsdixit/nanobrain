import { AbsoluteFill, Sequence } from "remotion";
import { Terminal } from "./components/Terminal";
import { Title } from "./components/Title";
import { Scanlines, Vignette, GridBackground } from "./components/Scanlines";
import { StatusScene } from "./scenes/StatusScene";
import { WhoScene } from "./scenes/WhoScene";
import { ListScene } from "./scenes/ListScene";
import { ShowScene } from "./scenes/ShowScene";
import { ClosingScene } from "./scenes/ClosingScene";

export const FPS = 30;

// Scene durations in frames. Total ≈ 22s.
const SCENES = {
  title: 90,    // 3.0s — brick-style brand slam-in
  status: 90,   // 3.0s
  who: 130,    // 4.3s
  list: 90,    // 3.0s
  show: 150,   // 5.0s — Sid's bio is rich, viewers need time to read
  closing: 110,// 3.7s — WORKS WITH panel
};

export const DEMO_DURATION_FRAMES =
  SCENES.title + SCENES.status + SCENES.who + SCENES.list + SCENES.show + SCENES.closing;

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

      <Sequence from={at("title")} durationInFrames={SCENES.title}>
        <Title />
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
