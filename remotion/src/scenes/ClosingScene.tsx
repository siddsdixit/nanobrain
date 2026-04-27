import { AbsoluteFill, useCurrentFrame, interpolate, Easing, spring, useVideoConfig } from "remotion";

export const ClosingScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const line1 = spring({ frame, fps, config: { damping: 14, stiffness: 100 } });
  const line2 = interpolate(frame, [16, 36], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 18,
      }}
    >
      <div
        style={{
          fontSize: 44,
          fontWeight: 700,
          color: "#f0f6fc",
          letterSpacing: -0.5,
          transform: `scale(${line1})`,
        }}
      >
        Markdown + git. Vendor-neutral.
      </div>
      <div
        style={{
          fontSize: 22,
          color: "#7d8590",
          opacity: line2,
        }}
      >
        github.com/siddsdixit/nanobrain
      </div>
    </AbsoluteFill>
  );
};
