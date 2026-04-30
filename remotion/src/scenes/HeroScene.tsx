import { AbsoluteFill, useCurrentFrame, useVideoConfig, spring, interpolate, Easing } from "remotion";

const CORAL = "#E08263";
const CORAL_DEEP = "#C66A4E";
const INK = "#f0e0d0";
const INK_DIM = "#9a8676";
const INK_MUTE = "#7a6a5e";

// BrandGlyph — same as site hero.
const BrandGlyph = ({ size = 96 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
    <defs>
      <linearGradient id="heroGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stopColor={CORAL} stopOpacity="0.95" />
        <stop offset="100%" stopColor={CORAL_DEEP} stopOpacity="1" />
      </linearGradient>
    </defs>
    <g stroke="url(#heroGrad)" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round" fill="none">
      <path d="M22 12c-5.2 0-9 3.8-9 8.8 0 1.6.4 3.2 1.2 4.4-1.8 1.4-3.2 3.8-3.2 6.4 0 3.2 2 6 4.8 7.2-.4 1-.6 2.2-.6 3.4 0 5 4 8.8 9 8.8 2 0 4-.6 5.4-1.8 1.2 1.2 3 1.8 4.8 1.8 1.8 0 3.6-.6 4.8-1.8 1.4 1.2 3.4 1.8 5.4 1.8 5 0 9-3.8 9-8.8 0-1.2-.2-2.4-.6-3.4 2.8-1.2 4.8-4 4.8-7.2 0-2.6-1.4-5-3.2-6.4.8-1.2 1.2-2.8 1.2-4.4 0-5-3.8-8.8-9-8.8-2 0-4 .6-5.4 1.8-1.2-1.2-3-1.8-4.8-1.8-1.8 0-3.6.6-4.8 1.8C26 12.6 24 12 22 12Z" />
      <path d="M32 14v36" />
      <path d="M22 24h5M22 32h6M22 40h5" />
      <path d="M42 24h-5M42 32h-6M42 40h-5" />
      <circle cx="22" cy="24" r="1.4" fill="url(#heroGrad)" stroke="none" />
      <circle cx="22" cy="32" r="1.4" fill="url(#heroGrad)" stroke="none" />
      <circle cx="22" cy="40" r="1.4" fill="url(#heroGrad)" stroke="none" />
      <circle cx="42" cy="24" r="1.4" fill="url(#heroGrad)" stroke="none" />
      <circle cx="42" cy="32" r="1.4" fill="url(#heroGrad)" stroke="none" />
      <circle cx="42" cy="40" r="1.4" fill="url(#heroGrad)" stroke="none" />
    </g>
  </svg>
);

// Reveal helper: returns {opacity, translateY} for an entrance animation.
const useReveal = (start: number, frame: number, duration = 18) => {
  const opacity = interpolate(frame, [start, start + duration], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const translateY = interpolate(frame, [start, start + duration], [14, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  return { opacity, translateY };
};

/**
 * HeroScene — recreates the nanobrain.app hero in motion.
 * Beats:
 *   0    tag pill ("v2.1 · research preview")
 *   8    brand wordmark (glyph + nanoBrain) springs in
 *   42   tagline subhead ("the second brain that thinks like you")
 *   72   lede paragraph
 *   100  CTAs (Install / Star on GitHub)
 *   125  install command pre block
 *   150  meta line (Markdown · Git · Vendor-neutral)
 *   180+ all sustained until exit fade ~210
 */
export const HeroScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Global exit fade for transition into next scene.
  const exitFade = interpolate(frame, [200, 215], [1, 0], { extrapolateRight: "clamp" });

  // Tag.
  const tag = useReveal(0, frame, 14);

  // Brand wordmark (spring).
  const brandSpring = spring({
    frame: frame - 8,
    fps,
    config: { damping: 16, stiffness: 110, mass: 0.8 },
  });
  const brandScale = interpolate(brandSpring, [0, 1], [0.7, 1], { extrapolateRight: "clamp" });
  const brandOpacity = interpolate(brandSpring, [0, 0.6], [0, 1], { extrapolateRight: "clamp" });

  // Subsequent reveals.
  const tagline = useReveal(42, frame);
  const lede = useReveal(72, frame);
  const ctas = useReveal(100, frame);
  const install = useReveal(125, frame);
  const meta = useReveal(150, frame);

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 22,
        opacity: exitFade,
        padding: "0 60px",
      }}
    >
      {/* 1. Tag pill */}
      <div
        style={{
          fontFamily: "ui-monospace, 'JetBrains Mono', SF Mono, Menlo, monospace",
          fontSize: 12,
          color: INK_DIM,
          letterSpacing: 3,
          textTransform: "uppercase",
          padding: "5px 14px",
          border: "1px solid rgba(224,130,99,0.35)",
          borderRadius: 999,
          background: "rgba(240,224,208,0.04)",
          display: "inline-flex",
          alignItems: "center",
          gap: 7,
          opacity: tag.opacity,
          transform: `translateY(${tag.translateY}px)`,
        }}
      >
        <span style={{ width: 6, height: 6, background: CORAL, borderRadius: "50%" }} />
        v2.1 · research preview
      </div>

      {/* 2. Brand wordmark */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 18,
          transform: `scale(${brandScale})`,
          opacity: brandOpacity,
          filter: `drop-shadow(0 0 36px rgba(224,130,99,${0.22 * brandOpacity}))`,
          marginTop: 4,
        }}
      >
        <BrandGlyph size={108} />
        <div
          style={{
            fontFamily:
              "-apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', system-ui, sans-serif",
            fontSize: 108,
            fontWeight: 800,
            letterSpacing: -5,
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

      {/* 3. Tagline subhead */}
      <div
        style={{
          fontFamily:
            "-apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', system-ui, sans-serif",
          fontSize: 30,
          fontWeight: 600,
          color: INK_DIM,
          letterSpacing: -0.4,
          textAlign: "center",
          marginTop: 4,
          opacity: tagline.opacity,
          transform: `translateY(${tagline.translateY}px)`,
        }}
      >
        the second brain that{" "}
        <span style={{ color: INK, fontStyle: "italic", fontWeight: 600 }}>thinks like you</span>.
      </div>

      {/* 4. Lede paragraph */}
      <div
        style={{
          fontFamily:
            "-apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', system-ui, sans-serif",
          fontSize: 17,
          fontWeight: 400,
          lineHeight: 1.5,
          color: INK_DIM,
          textAlign: "center",
          maxWidth: 720,
          opacity: lede.opacity,
          transform: `translateY(${lede.translateY}px)`,
        }}
      >
        A knowledge corpus that captures your decisions, voice, and relationships
        while you work. Read by every AI agent. Yours forever.
      </div>

      {/* 5. CTAs */}
      <div
        style={{
          display: "flex",
          gap: 14,
          marginTop: 8,
          opacity: ctas.opacity,
          transform: `translateY(${ctas.translateY}px)`,
        }}
      >
        <div
          style={{
            fontFamily:
              "-apple-system, BlinkMacSystemFont, 'Inter', system-ui, sans-serif",
            fontSize: 15,
            fontWeight: 600,
            color: "#1a1614",
            background: CORAL,
            padding: "11px 22px",
            borderRadius: 8,
            boxShadow: "0 8px 24px rgba(224,130,99,0.25)",
          }}
        >
          Install in 2 minutes →
        </div>
        <div
          style={{
            fontFamily:
              "-apple-system, BlinkMacSystemFont, 'Inter', system-ui, sans-serif",
            fontSize: 15,
            fontWeight: 600,
            color: INK,
            background: "rgba(240,224,208,0.04)",
            border: "1px solid rgba(240,224,208,0.18)",
            padding: "10px 22px",
            borderRadius: 8,
          }}
        >
          ★ Star on GitHub
        </div>
      </div>

      {/* 6. Install command pre block */}
      <div
        style={{
          fontFamily: "ui-monospace, 'JetBrains Mono', SF Mono, Menlo, monospace",
          fontSize: 13,
          lineHeight: 1.7,
          color: INK_DIM,
          background: "rgba(240,224,208,0.06)",
          border: "1px solid rgba(240,224,208,0.14)",
          borderRadius: 8,
          padding: "12px 18px",
          opacity: install.opacity,
          transform: `translateY(${install.translateY}px)`,
          maxWidth: 720,
          textAlign: "left",
        }}
      >
        <div>
          <span style={{ color: CORAL, marginRight: 10, opacity: 0.8 }}>$</span>
          git clone https://github.com/siddsdixit/nanobrain ~/nanobrain
        </div>
        <div>
          <span style={{ color: CORAL, marginRight: 10, opacity: 0.8 }}>$</span>
          bash ~/nanobrain/install.sh ~/my-brain
        </div>
      </div>

      {/* 7. Meta line */}
      <div
        style={{
          fontFamily:
            "-apple-system, BlinkMacSystemFont, 'Inter', system-ui, sans-serif",
          fontSize: 13,
          color: INK_MUTE,
          display: "flex",
          gap: 18,
          alignItems: "center",
          opacity: meta.opacity,
          transform: `translateY(${meta.translateY}px)`,
        }}
      >
        <span>
          <strong style={{ color: INK_DIM, fontWeight: 600 }}>Markdown</strong> · plain text, forever
        </span>
        <span style={{ opacity: 0.4 }}>·</span>
        <span>
          <strong style={{ color: INK_DIM, fontWeight: 600 }}>Git</strong> · own your history
        </span>
        <span style={{ opacity: 0.4 }}>·</span>
        <span>
          <strong style={{ color: INK_DIM, fontWeight: 600 }}>Vendor-neutral</strong> · works with every agent
        </span>
      </div>
    </AbsoluteFill>
  );
};
