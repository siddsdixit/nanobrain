import { AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate, spring, Easing } from "remotion";

const CORAL = "#E08263";
const CORAL_DEEP = "#C66A4E";
const INK = "#f0e0d0";
const INK_DIM = "#9a8676";
const INK_MUTE = "#7a6a5e";

const Glyph = ({ size }: { size: number }) => (
  <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
    <defs>
      <linearGradient id="foreverGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stopColor={CORAL} stopOpacity="0.95" />
        <stop offset="100%" stopColor={CORAL_DEEP} stopOpacity="1" />
      </linearGradient>
    </defs>
    <g stroke="url(#foreverGrad)" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round" fill="none">
      <path d="M22 12c-5.2 0-9 3.8-9 8.8 0 1.6.4 3.2 1.2 4.4-1.8 1.4-3.2 3.8-3.2 6.4 0 3.2 2 6 4.8 7.2-.4 1-.6 2.2-.6 3.4 0 5 4 8.8 9 8.8 2 0 4-.6 5.4-1.8 1.2 1.2 3 1.8 4.8 1.8 1.8 0 3.6-.6 4.8-1.8 1.4 1.2 3.4 1.8 5.4 1.8 5 0 9-3.8 9-8.8 0-1.2-.2-2.4-.6-3.4 2.8-1.2 4.8-4 4.8-7.2 0-2.6-1.4-5-3.2-6.4.8-1.2 1.2-2.8 1.2-4.4 0-5-3.8-8.8-9-8.8-2 0-4 .6-5.4 1.8-1.2-1.2-3-1.8-4.8-1.8-1.8 0-3.6.6-4.8 1.8C26 12.6 24 12 22 12Z" />
      <path d="M32 14v36" />
      <path d="M22 24h5M22 32h6M22 40h5" />
      <path d="M42 24h-5M42 32h-6M42 40h-5" />
    </g>
  </svg>
);

/**
 * ForeverScene — closing. Terminal command "cat brain/self.md" → output
 * showing voice / principles in YOUR voice. Then big brand sign-off + CTA.
 */
export const ForeverScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Terminal command appears.
  const cmdFade = interpolate(frame, [0, 14], [0, 1], { extrapolateRight: "clamp" });

  // Self.md content lines fade in sequentially. Kept short for legibility.
  const lines = [
    { t: 22, label: "voice", text: "direct, no preamble" },
    { t: 36, label: "principles", text: "match patterns. ship reversible." },
    { t: 50, label: "decisions", text: "fast when reversible, slow when not" },
    { t: 64, label: "mode", text: "solo until proof" },
  ];

  // Subtitle "this works in 50 years"
  const subtitleFade = interpolate(frame, [82, 100], [0, 1], { extrapolateRight: "clamp" });

  // Brand reveal — big closing.
  const brandSpring = spring({ frame: frame - 110, fps, config: { damping: 16, stiffness: 110 } });
  const brandScale = interpolate(brandSpring, [0, 1], [0.85, 1]);
  const brandOpacity = interpolate(brandSpring, [0, 0.6], [0, 1], { extrapolateRight: "clamp" });

  // CTA + URL.
  const ctaFade = interpolate(frame, [140, 160], [0, 1], { extrapolateRight: "clamp" });

  // Terminal slides up to make room for brand.
  const terminalY = interpolate(frame, [105, 125], [0, -120], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });
  const terminalOpacity = interpolate(frame, [105, 125], [1, 0.25], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 26,
      }}
    >
      {/* Terminal block */}
      <div
        style={{
          fontFamily: "ui-monospace, JetBrains Mono, monospace",
          background: "rgba(0,0,0,0.4)",
          border: "1px solid rgba(240,224,208,0.18)",
          borderRadius: 14,
          padding: "28px 36px",
          minWidth: 820,
          maxWidth: 900,
          fontSize: 22,
          lineHeight: 1.7,
          color: INK,
          opacity: terminalOpacity,
          transform: `translateY(${terminalY}px)`,
        }}
      >
        <div style={{ opacity: cmdFade, color: CORAL, fontWeight: 700, fontSize: 22 }}>
          $ cat brain/self.md
        </div>
        <div style={{ opacity: cmdFade, color: INK_DIM, fontSize: 16, marginTop: 6, marginBottom: 16 }}>
          # who you are
        </div>
        {lines.map((l, i) => {
          const fade = interpolate(frame, [l.t, l.t + 12], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });
          return (
            <div key={i} style={{ opacity: fade, fontSize: 22, marginBottom: 4 }}>
              <span style={{ color: CORAL, fontWeight: 700 }}>{l.label}:</span>{" "}
              <span style={{ color: INK, fontWeight: 500 }}>{l.text}</span>
            </div>
          );
        })}
        <div
          style={{
            opacity: subtitleFade,
            color: INK_MUTE,
            fontSize: 16,
            marginTop: 18,
            letterSpacing: 1,
            fontFamily: "-apple-system, Inter, system-ui, sans-serif",
            fontWeight: 500,
            fontStyle: "italic",
          }}
        >
          ✦ still works in 50 years.
        </div>
      </div>

      {/* Brand sign-off */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 18,
          transform: `scale(${brandScale})`,
          opacity: brandOpacity,
          filter: `drop-shadow(0 0 40px rgba(224,130,99,${0.3 * brandOpacity}))`,
          marginTop: -40,
        }}
      >
        <Glyph size={92} />
        <div
          style={{
            fontFamily:
              "-apple-system, BlinkMacSystemFont, Inter, system-ui, sans-serif",
            fontSize: 92,
            fontWeight: 800,
            letterSpacing: -4,
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

      {/* Tagline */}
      <div
        style={{
          fontFamily: "-apple-system, Inter, system-ui, sans-serif",
          fontSize: 32,
          fontWeight: 600,
          color: INK_DIM,
          letterSpacing: -0.6,
          opacity: ctaFade,
          textAlign: "center",
        }}
      >
        the second brain that{" "}
        <em style={{ color: INK, fontStyle: "italic", fontWeight: 700 }}>thinks like you</em>.
      </div>

      {/* URL */}
      <div
        style={{
          fontFamily: "ui-monospace, JetBrains Mono, monospace",
          fontSize: 28,
          color: CORAL,
          opacity: ctaFade,
          letterSpacing: 0.5,
          fontWeight: 700,
          marginTop: 8,
        }}
      >
        → nanobrain.app
      </div>
    </AbsoluteFill>
  );
};
