import { AbsoluteFill, useCurrentFrame, useVideoConfig, spring, interpolate, Easing } from "remotion";
import { loadFont as loadBungee } from "@remotion/google-fonts/BungeeInline";
import { loadFont as loadBungeePlain } from "@remotion/google-fonts/Bungee";

const { fontFamily: BUNGEE_INLINE } = loadBungee();
const { fontFamily: BUNGEE } = loadBungeePlain();

const LETTERS = "NANOBRAIN".split("");
const CORAL = "#FF8A70";
const CORAL_GLOW = "rgba(255, 138, 112, 0.55)";

export const Title = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const exitFade = interpolate(frame, [78, 90], [1, 0], { extrapolateRight: "clamp" });
  const subFade = interpolate(frame, [55, 75], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  // Slow pulse on the wordmark glow
  const pulse = 0.85 + 0.15 * Math.sin(frame / 8);

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 28,
        opacity: exitFade,
      }}
    >
      <div
        style={{
          display: "flex",
          gap: 4,
          fontFamily: BUNGEE_INLINE,
          fontSize: 138,
          color: CORAL,
          textShadow: `0 0 60px ${CORAL_GLOW}, 0 0 25px ${CORAL_GLOW}`,
          letterSpacing: 2,
          filter: `drop-shadow(0 0 30px rgba(255,138,112,${0.4 * pulse}))`,
        }}
      >
        {LETTERS.map((letter, i) => {
          const drop = spring({
            frame: frame - i * 4,
            fps,
            config: { damping: 11, stiffness: 110, mass: 1.1 },
            from: -260,
            to: 0,
          });
          const tilt = spring({
            frame: frame - i * 4,
            fps,
            config: { damping: 10, stiffness: 120 },
            from: -8,
            to: 0,
          });
          return (
            <span
              key={i}
              style={{
                display: "inline-block",
                transform: `translateY(${drop}px) rotate(${tilt}deg)`,
              }}
            >
              {letter}
            </span>
          );
        })}
      </div>

      <div
        style={{
          fontFamily: BUNGEE,
          fontSize: 22,
          color: "#9aa4b1",
          opacity: subFade,
          letterSpacing: 4,
        }}
      >
        SECOND BRAIN · MARKDOWN · VENDOR-NEUTRAL
      </div>
    </AbsoluteFill>
  );
};
