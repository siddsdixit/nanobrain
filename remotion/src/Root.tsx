import { Composition } from "remotion";
import { NanobrainDemo, DEMO_DURATION_FRAMES, FPS } from "./NanobrainDemo";

export const Root = () => {
  return (
    <Composition
      id="NanobrainDemo"
      component={NanobrainDemo}
      durationInFrames={DEMO_DURATION_FRAMES}
      fps={FPS}
      width={1280}
      height={720}
    />
  );
};
