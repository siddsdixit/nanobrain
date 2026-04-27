import { AbsoluteFill, useCurrentFrame, useVideoConfig, spring, interpolate, Easing } from "remotion";
import { loadFont as loadBungee } from "@remotion/google-fonts/Bungee";

const { fontFamily: BUNGEE } = loadBungee();

const AGENTS = ["CLAUDE", "CODEX", "GEMINI", "CURSOR", "AIDER"];
const CORAL = "#FF8A70";
const CORAL_GLOW = "rgba(255, 138, 112, 0.45)";

export const ClosingScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const headerScale = spring({
    frame,
    fps,
    config: { damping: 14, stiffness: 110 },
  });

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 36,
      }}
    >
      <div
        style={{
          fontFamily: BUNGEE,
          fontSize: 72,
          color: CORAL,
          letterSpacing: 4,
          transform: `scale(${headerScale})`,
          textShadow: `0 0 40px ${CORAL_GLOW}`,
        }}
      >
        WORKS WITH
      </div>

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
            frame: frame - 18 - i * 6,
            fps,
            config: { damping: 14, stiffness: 130 },
          });
          return (
            <div
              key={name}
              style={{
                fontFamily: BUNGEE,
                fontSize: 28,
                color: "#0f1419",
                background: "#e6edf3",
                padding: "14px 24px",
                borderRadius: 8,
                letterSpacing: 2,
                transform: `scale(${appear})`,
                boxShadow: "0 8px 24px rgba(0,0,0,0.4)",
              }}
            >
              {name}
            </div>
          );
        })}
      </div>

      <div
        style={{
          marginTop: 30,
          fontFamily: "ui-monospace, 'JetBrains Mono', monospace",
          fontSize: 22,
          color: "#9aa4b1",
          letterSpacing: 1,
          opacity: interpolate(frame, [50, 70], [0, 1], {
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
