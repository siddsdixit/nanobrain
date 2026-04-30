import { AbsoluteFill, useCurrentFrame, interpolate, Easing } from "remotion";

const CORAL = "#E08263";
const INK = "#f0e0d0";
const INK_DIM = "#9a8676";
const INK_MUTE = "#7a6a5e";

const VENDORS = ["Claude Memory", "ChatGPT Memory", "Gemini Memory"];

export const HookScene = () => {
  const frame = useCurrentFrame();

  // Question fades in, holds, then a damning red strike-through.
  const qFade = interpolate(frame, [0, 14], [0, 1], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const qY = interpolate(frame, [0, 14], [10, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });

  const vendorFade = interpolate(frame, [28, 44], [0, 1], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });

  // The damning verdict line.
  const verdictFade = interpolate(frame, [70, 86], [0, 1], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });

  // Strike-through across all vendor cards (left-to-right wipe).
  const strikeProgress = interpolate(frame, [86, 110], [0, 1], { extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) });

  const exitFade = interpolate(frame, [120, 135], [1, 0], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 36,
        opacity: exitFade,
        padding: "0 60px",
      }}
    >
      <div
        style={{
          fontFamily: "-apple-system, BlinkMacSystemFont, Inter, system-ui, sans-serif",
          fontSize: 64,
          fontWeight: 700,
          letterSpacing: -2,
          color: INK,
          textAlign: "center",
          opacity: qFade,
          transform: `translateY(${qY}px)`,
          maxWidth: 1040,
          lineHeight: 1.05,
        }}
      >
        Where does your AI memory<br />
        <span style={{ color: INK_DIM }}>actually live?</span>
      </div>

      <div style={{ display: "flex", gap: 20, opacity: vendorFade, position: "relative" }}>
        {VENDORS.map((v) => (
          <div
            key={v}
            style={{
              fontFamily: "ui-monospace, JetBrains Mono, monospace",
              fontSize: 24,
              color: INK_MUTE,
              background: "rgba(240,224,208,0.04)",
              border: "1px solid rgba(240,224,208,0.14)",
              borderRadius: 12,
              padding: "18px 32px",
              fontWeight: 600,
            }}
          >
            🔒 {v}
          </div>
        ))}
        {/* Red strike line wipes across all three */}
        <div
          style={{
            position: "absolute",
            left: 0,
            top: "50%",
            height: 3,
            width: `${strikeProgress * 100}%`,
            background: "#d4543a",
            transform: "translateY(-50%) rotate(-2deg)",
            transformOrigin: "left center",
            boxShadow: "0 0 12px rgba(212,84,58,0.6)",
            borderRadius: 2,
          }}
        />
      </div>

      <div
        style={{
          fontFamily: "-apple-system, BlinkMacSystemFont, Inter, system-ui, sans-serif",
          fontSize: 36,
          fontWeight: 600,
          color: INK_DIM,
          textAlign: "center",
          opacity: verdictFade,
          letterSpacing: -0.6,
        }}
      >
        Three silos. <span style={{ color: CORAL, fontWeight: 700 }}>Zero portability.</span>
      </div>
    </AbsoluteFill>
  );
};
