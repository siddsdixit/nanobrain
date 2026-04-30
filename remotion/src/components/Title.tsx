import { AbsoluteFill, useCurrentFrame, interpolate, Easing, spring, useVideoConfig } from "remotion";

const CORAL = "#E08263";
const CORAL_DEEP = "#C66A4E";
const INK = "#f0e0d0";
const INK_DIM = "#9a8676";

// BrandGlyph — same shape as the site hero SVG, simplified for video clarity.
const BrandGlyph = ({ size = 120 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
    <defs>
      <linearGradient id="brandGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stopColor={CORAL} stopOpacity="0.95" />
        <stop offset="100%" stopColor={CORAL_DEEP} stopOpacity="1" />
      </linearGradient>
    </defs>
    <g stroke="url(#brandGrad)" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round" fill="none">
      <path d="M22 12c-5.2 0-9 3.8-9 8.8 0 1.6.4 3.2 1.2 4.4-1.8 1.4-3.2 3.8-3.2 6.4 0 3.2 2 6 4.8 7.2-.4 1-.6 2.2-.6 3.4 0 5 4 8.8 9 8.8 2 0 4-.6 5.4-1.8 1.2 1.2 3 1.8 4.8 1.8 1.8 0 3.6-.6 4.8-1.8 1.4 1.2 3.4 1.8 5.4 1.8 5 0 9-3.8 9-8.8 0-1.2-.2-2.4-.6-3.4 2.8-1.2 4.8-4 4.8-7.2 0-2.6-1.4-5-3.2-6.4.8-1.2 1.2-2.8 1.2-4.4 0-5-3.8-8.8-9-8.8-2 0-4 .6-5.4 1.8-1.2-1.2-3-1.8-4.8-1.8-1.8 0-3.6.6-4.8 1.8C26 12.6 24 12 22 12Z" />
      <path d="M32 14v36" />
      <path d="M22 24h5M22 32h6M22 40h5" />
      <path d="M42 24h-5M42 32h-6M42 40h-5" />
      <circle cx="22" cy="24" r="1.4" fill="url(#brandGrad)" stroke="none" />
      <circle cx="22" cy="32" r="1.4" fill="url(#brandGrad)" stroke="none" />
      <circle cx="22" cy="40" r="1.4" fill="url(#brandGrad)" stroke="none" />
      <circle cx="42" cy="24" r="1.4" fill="url(#brandGrad)" stroke="none" />
      <circle cx="42" cy="32" r="1.4" fill="url(#brandGrad)" stroke="none" />
      <circle cx="42" cy="40" r="1.4" fill="url(#brandGrad)" stroke="none" />
    </g>
  </svg>
);

export const Title = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const exitFade = interpolate(frame, [78, 90], [1, 0], { extrapolateRight: "clamp" });

  // Tag pill fades in first.
  const tagFade = interpolate(frame, [0, 14], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  // Brand wordmark + glyph slam in via spring.
  const brandSpring = spring({
    frame: frame - 8,
    fps,
    config: { damping: 16, stiffness: 110, mass: 0.8 },
  });
  const brandScale = interpolate(brandSpring, [0, 1], [0.7, 1], { extrapolateRight: "clamp" });
  const brandOpacity = interpolate(brandSpring, [0, 0.6], [0, 1], { extrapolateRight: "clamp" });

  // Tagline subhead fades in last.
  const taglineFade = interpolate(frame, [42, 60], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const taglineY = interpolate(frame, [42, 60], [12, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

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
      {/* Research preview tag — small, top */}
      <div
        style={{
          fontFamily: "ui-monospace, 'JetBrains Mono', SF Mono, Menlo, monospace",
          fontSize: 13,
          color: INK_DIM,
          letterSpacing: 3,
          textTransform: "uppercase",
          padding: "6px 16px",
          border: "1px solid rgba(224,130,99,0.35)",
          borderRadius: 999,
          opacity: tagFade,
          background: "rgba(240,224,208,0.04)",
          display: "inline-flex",
          alignItems: "center",
          gap: 8,
        }}
      >
        <span style={{ width: 6, height: 6, background: CORAL, borderRadius: "50%" }} />
        v2.1 · research preview
      </div>

      {/* Brand wordmark — THE hero */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 22,
          transform: `scale(${brandScale})`,
          opacity: brandOpacity,
          filter: `drop-shadow(0 0 40px rgba(224,130,99,${0.25 * brandOpacity}))`,
        }}
      >
        <BrandGlyph size={120} />
        <div
          style={{
            fontFamily:
              "-apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', system-ui, sans-serif",
            fontSize: 132,
            fontWeight: 800,
            letterSpacing: -6,
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

      {/* Tagline subhead — matches site */}
      <div
        style={{
          fontFamily:
            "-apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', system-ui, sans-serif",
          fontSize: 32,
          fontWeight: 600,
          color: INK_DIM,
          letterSpacing: -0.5,
          opacity: taglineFade,
          transform: `translateY(${taglineY}px)`,
          textAlign: "center",
        }}
      >
        the second brain that{" "}
        <span style={{ color: INK, fontStyle: "italic", fontWeight: 600 }}>thinks like you</span>.
      </div>
    </AbsoluteFill>
  );
};
