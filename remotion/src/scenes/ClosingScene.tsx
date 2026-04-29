import { AbsoluteFill, useCurrentFrame, useVideoConfig, spring, interpolate, Easing } from "remotion";
import { BrickWord } from "../components/BrickText";

const AGENTS = ["CLAUDE", "CODEX", "GEMINI", "CURSOR", "AIDER"];

export const ClosingScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 60,
      }}
    >
      <BrickWord text="WORKS WITH" cell={20} letterGap={12} startDelay={0} />

      <div
        style={{
          display: "flex",
          gap: 14,
          flexWrap: "wrap",
          justifyContent: "center",
          maxWidth: 1100,
        }}
      >
        {AGENTS.map((name, i) => {
          const appear = spring({
            frame: frame - 36 - i * 6,
            fps,
            config: { damping: 14, stiffness: 130 },
          });
          return (
            <div
              key={name}
              style={{
                fontFamily: "ui-monospace, 'JetBrains Mono', SF Mono, Menlo, monospace",
                fontSize: 22,
                fontWeight: 700,
                color: "#1a1614",
                background: "#f0e0d0",
                padding: "12px 22px",
                borderRadius: 6,
                letterSpacing: 2,
                transform: `scale(${appear})`,
                boxShadow: "0 8px 24px rgba(0,0,0,0.4), 0 0 0 1px rgba(224,130,99,0.3)",
              }}
            >
              {name}
            </div>
          );
        })}
      </div>

      <div
        style={{
          fontFamily: "ui-monospace, 'JetBrains Mono', monospace",
          fontSize: 22,
          color: "#9a8676",
          letterSpacing: 1,
          opacity: interpolate(frame, [60, 80], [0, 1], {
            extrapolateRight: "clamp",
            easing: Easing.out(Easing.cubic),
          }),
        }}
      >
        github.com/siddsdixit/nanobrain
      </div>
    </AbsoluteFill>
  );
};
