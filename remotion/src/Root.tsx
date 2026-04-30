import { Composition } from "remotion";
import { NanobrainDemo, DEMO_DURATION_FRAMES, FPS } from "./NanobrainDemo";

export const Root = () => {
  return (
    <>
      {/* Default 16:9 — for the README hero, GitHub embed, generic web. */}
      <Composition
        id="NanobrainDemo"
        component={NanobrainDemo}
        durationInFrames={DEMO_DURATION_FRAMES}
        fps={FPS}
        width={1280}
        height={720}
      />

      {/* 1:1 square — optimized for LinkedIn / Twitter feed (38% more
          screen real estate on mobile than 16:9). Same content, taller
          framing handled inside scenes which use AbsoluteFill + flex
          column centered, so they recenter automatically. */}
      <Composition
        id="NanobrainDemoSquare"
        component={NanobrainDemo}
        durationInFrames={DEMO_DURATION_FRAMES}
        fps={FPS}
        width={1080}
        height={1080}
      />
    </>
  );
};
