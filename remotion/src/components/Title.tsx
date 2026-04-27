import { AbsoluteFill, useCurrentFrame, interpolate, Easing, spring, useVideoConfig } from "remotion";

export const Title = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleScale = spring({ frame, fps, config: { damping: 14, stiffness: 90 } });
  const subFade = interpolate(frame, [10, 24], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const exitFade = interpolate(frame, [50, 60], [1, 0], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 24,
        opacity: exitFade,
      }}
    >
      <div
        style={{
          fontSize: 92,
          fontWeight: 700,
          color: "#f0f6fc",
          letterSpacing: -2,
          transform: `scale(${titleScale})`,
        }}
      >
        nanobrain
      </div>
      <div
        style={{
          fontSize: 26,
          color: "#7d8590",
          opacity: subFade,
          letterSpacing: 0.6,
        }}
      >
        the second brain that travels with you across every AI
      </div>
    </AbsoluteFill>
  );
};
