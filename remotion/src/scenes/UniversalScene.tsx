import { AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate, spring, Easing } from "remotion";

const CORAL = "#E08263";
const CORAL_DEEP = "#C66A4E";
const INK = "#f0e0d0";
const INK_DIM = "#9a8676";
const INK_MUTE = "#7a6a5e";

const AGENTS = [
  { name: "Claude Code", x: -300, y: -140 },
  { name: "Codex CLI",   x:  300, y: -140 },
  { name: "Cursor",      x: -360, y:   30 },
  { name: "Gemini",      x:  360, y:   30 },
  { name: "Aider",       x:    0, y: -240 },
];

// Brain glyph (mini).
const Glyph = ({ size }: { size: number }) => (
  <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
    <defs>
      <linearGradient id="uniGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stopColor={CORAL} stopOpacity="0.95" />
        <stop offset="100%" stopColor={CORAL_DEEP} stopOpacity="1" />
      </linearGradient>
    </defs>
    <g stroke="url(#uniGrad)" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round" fill="none">
      <path d="M22 12c-5.2 0-9 3.8-9 8.8 0 1.6.4 3.2 1.2 4.4-1.8 1.4-3.2 3.8-3.2 6.4 0 3.2 2 6 4.8 7.2-.4 1-.6 2.2-.6 3.4 0 5 4 8.8 9 8.8 2 0 4-.6 5.4-1.8 1.2 1.2 3 1.8 4.8 1.8 1.8 0 3.6-.6 4.8-1.8 1.4 1.2 3.4 1.8 5.4 1.8 5 0 9-3.8 9-8.8 0-1.2-.2-2.4-.6-3.4 2.8-1.2 4.8-4 4.8-7.2 0-2.6-1.4-5-3.2-6.4.8-1.2 1.2-2.8 1.2-4.4 0-5-3.8-8.8-9-8.8-2 0-4 .6-5.4 1.8-1.2-1.2-3-1.8-4.8-1.8-1.8 0-3.6.6-4.8 1.8C26 12.6 24 12 22 12Z" />
      <path d="M32 14v36" />
      <path d="M22 24h5M22 32h6M22 40h5" />
      <path d="M42 24h-5M42 32h-6M42 40h-5" />
    </g>
  </svg>
);

export const UniversalScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleFade = interpolate(frame, [0, 14], [0, 1], { extrapolateRight: "clamp" });
  const exitFade = interpolate(frame, [165, 180], [1, 0], { extrapolateRight: "clamp" });

  // Center brain reveal.
  const brainSpring = spring({ frame: frame - 14, fps, config: { damping: 16, stiffness: 110 } });
  const brainScale = interpolate(brainSpring, [0, 1], [0.5, 1]);
  const brainOpacity = interpolate(brainSpring, [0, 0.6], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 30,
        opacity: exitFade,
      }}
    >
      {/* Title */}
      <div style={{ textAlign: "center", opacity: titleFade }}>
        <div
          style={{
            fontFamily: "-apple-system, Inter, system-ui, sans-serif",
            fontSize: 56,
            fontWeight: 800,
            letterSpacing: -1.8,
            color: INK,
            lineHeight: 1.05,
          }}
        >
          One brain. Every agent.
        </div>
        <div
          style={{
            fontFamily: "-apple-system, Inter, system-ui, sans-serif",
            fontSize: 28,
            fontWeight: 500,
            color: INK_DIM,
            marginTop: 14,
            letterSpacing: -0.5,
          }}
        >
          Switch tools. Keep your context.
        </div>
      </div>

      {/* Constellation: brain in center, agents around it with connecting lines */}
      <div style={{ position: "relative", width: 900, height: 540 }}>
        {/* Connecting lines (rendered before so behind) */}
        <svg
          style={{ position: "absolute", inset: 0 }}
          width="900"
          height="540"
          viewBox="-450 -270 900 540"
        >
          {AGENTS.map((a, i) => {
            const lineFade = interpolate(frame, [40 + i * 6, 60 + i * 6], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            });
            // Pulse along the line.
            const pulseFrame = frame - 80 - i * 12;
            const pulseT = ((pulseFrame % 60) / 60);
            const showPulse = pulseFrame > 0;
            const pulseX = a.x * pulseT;
            const pulseY = a.y * pulseT;
            return (
              <g key={a.name} opacity={lineFade}>
                <line
                  x1={0}
                  y1={20}
                  x2={a.x}
                  y2={a.y}
                  stroke={CORAL}
                  strokeOpacity={0.32}
                  strokeWidth={1.5}
                  strokeDasharray="3 4"
                />
                {showPulse && (
                  <circle
                    cx={pulseX}
                    cy={pulseY + 20}
                    r={3.5}
                    fill={CORAL}
                    opacity={0.85}
                  >
                  </circle>
                )}
              </g>
            );
          })}
        </svg>

        {/* Center brain — absolute centered */}
        <div
          style={{
            position: "absolute",
            left: "50%",
            top: "50%",
            transform: `translate(-50%, -50%) scale(${brainScale})`,
            opacity: brainOpacity,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 6,
            filter: `drop-shadow(0 0 50px rgba(224,130,99,${0.4 * brainOpacity}))`,
          }}
        >
          <Glyph size={140} />
          <div
            style={{
              fontFamily: "-apple-system, Inter, system-ui, sans-serif",
              fontSize: 44,
              fontWeight: 800,
              letterSpacing: -1.6,
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
              }}
            >
              Brain
            </span>
          </div>
        </div>

        {/* Agent badges */}
        {AGENTS.map((a, i) => {
          const appear = spring({
            frame: frame - 30 - i * 7,
            fps,
            config: { damping: 14, stiffness: 130 },
          });
          return (
            <div
              key={a.name}
              style={{
                position: "absolute",
                left: "50%",
                top: "50%",
                transform: `translate(calc(-50% + ${a.x}px), calc(-50% + ${a.y + 20}px)) scale(${appear})`,
                opacity: appear,
                fontFamily: "-apple-system, Inter, system-ui, sans-serif",
                fontSize: 22,
                color: INK,
                background: "rgba(240,224,208,0.08)",
                border: "1.5px solid rgba(224,130,99,0.5)",
                borderRadius: 999,
                padding: "14px 26px",
                fontWeight: 700,
                letterSpacing: -0.3,
                whiteSpace: "nowrap",
              }}
            >
              {a.name}
            </div>
          );
        })}
      </div>

      {/* Footer */}
      <div
        style={{
          fontFamily: "ui-monospace, JetBrains Mono, monospace",
          fontSize: 18,
          color: INK_MUTE,
          letterSpacing: 1,
          opacity: interpolate(frame, [110, 130], [0, 1], { extrapolateRight: "clamp" }),
          textAlign: "center",
          fontWeight: 500,
        }}
      >
        Read via MCP. No vendor lock-in.
      </div>
    </AbsoluteFill>
  );
};
