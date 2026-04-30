import { AbsoluteFill, useCurrentFrame, useVideoConfig, spring, interpolate, Easing } from "remotion";

const CORAL = "#E08263";
const CORAL_DEEP = "#C66A4E";
const INK = "#f0e0d0";
const INK_DIM = "#9a8676";

const AGENTS = ["claude", "codex", "cursor", "gemini", "aider"];

const MiniGlyph = ({ size = 56 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
    <defs>
      <linearGradient id="closingGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stopColor={CORAL} stopOpacity="0.95" />
        <stop offset="100%" stopColor={CORAL_DEEP} stopOpacity="1" />
      </linearGradient>
    </defs>
    <g stroke="url(#closingGrad)" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round" fill="none">
      <path d="M22 12c-5.2 0-9 3.8-9 8.8 0 1.6.4 3.2 1.2 4.4-1.8 1.4-3.2 3.8-3.2 6.4 0 3.2 2 6 4.8 7.2-.4 1-.6 2.2-.6 3.4 0 5 4 8.8 9 8.8 2 0 4-.6 5.4-1.8 1.2 1.2 3 1.8 4.8 1.8 1.8 0 3.6-.6 4.8-1.8 1.4 1.2 3.4 1.8 5.4 1.8 5 0 9-3.8 9-8.8 0-1.2-.2-2.4-.6-3.4 2.8-1.2 4.8-4 4.8-7.2 0-2.6-1.4-5-3.2-6.4.8-1.2 1.2-2.8 1.2-4.4 0-5-3.8-8.8-9-8.8-2 0-4 .6-5.4 1.8-1.2-1.2-3-1.8-4.8-1.8-1.8 0-3.6.6-4.8 1.8C26 12.6 24 12 22 12Z" />
      <path d="M32 14v36" />
      <path d="M22 24h5M22 32h6M22 40h5" />
      <path d="M42 24h-5M42 32h-6M42 40h-5" />
    </g>
  </svg>
);

export const ClosingScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const brandSpring = spring({
    frame: frame - 4,
    fps,
    config: { damping: 18, stiffness: 120 },
  });
  const brandScale = interpolate(brandSpring, [0, 1], [0.85, 1], { extrapolateRight: "clamp" });
  const brandOpacity = interpolate(brandSpring, [0, 0.6], [0, 1], { extrapolateRight: "clamp" });

  const worksLabelFade = interpolate(frame, [22, 40], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  const urlFade = interpolate(frame, [80, 100], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 44,
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 16,
          transform: `scale(${brandScale})`,
          opacity: brandOpacity,
          filter: `drop-shadow(0 0 32px rgba(224,130,99,${0.22 * brandOpacity}))`,
        }}
      >
        <MiniGlyph size={64} />
        <div
          style={{
            fontFamily:
              "-apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', system-ui, sans-serif",
            fontSize: 78,
            fontWeight: 800,
            letterSpacing: -3,
            lineHeight: 1,
            color: INK,
          }}
        >
          nano
          <span
            style={{
              background: `linear-gradient(180deg, ${CORAL} 0%, ${CORAL_DEEP} 100%)`,
              WebkitBackgroundClip: "text",
              backgroundClip: "text",
              WebkitTextFillColor: "transparent",
              fontWeight: 800,
            }}
          >
            Brain
          </span>
        </div>
      </div>

      <div
        style={{
          fontFamily: "ui-monospace, 'JetBrains Mono', SF Mono, Menlo, monospace",
          fontSize: 14,
          color: INK_DIM,
          letterSpacing: 4,
          textTransform: "uppercase",
          opacity: worksLabelFade,
        }}
      >
        Read by every AI agent
      </div>

      <div
        style={{
          display: "flex",
          gap: 12,
          flexWrap: "wrap",
          justifyContent: "center",
          maxWidth: 1100,
        }}
      >
        {AGENTS.map((name, i) => {
          const appear = spring({
            frame: frame - 36 - i * 5,
            fps,
            config: { damping: 14, stiffness: 130 },
          });
          return (
            <div
              key={name}
              style={{
                fontFamily: "ui-monospace, 'JetBrains Mono', SF Mono, Menlo, monospace",
                fontSize: 18,
                fontWeight: 600,
                color: INK,
                background: "rgba(240,224,208,0.06)",
                border: "1px solid rgba(224,130,99,0.35)",
                padding: "10px 22px",
                borderRadius: 999,
                letterSpacing: 1.5,
                transform: `scale(${appear})`,
                opacity: appear,
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
          color: INK_DIM,
          letterSpacing: 1,
          opacity: urlFade,
          marginTop: 12,
        }}
      >
        <span style={{ color: CORAL, marginRight: 12 }}>→</span>
        nanobrain.app
      </div>
    </AbsoluteFill>
  );
};
