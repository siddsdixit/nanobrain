import { AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate, Easing, spring } from "remotion";

const CORAL = "#E08263";
const INK = "#f0e0d0";
const INK_DIM = "#9a8676";
const INK_MUTE = "#7a6a5e";

// brain/*.md files that grow as distill runs.
const FILES = [
  {
    name: "decisions.md",
    bullets: [
      { t: 16, text: "Postgres over Mongo" },
      { t: 50, text: "Drop multi-currency from MVP" },
      { t: 90, text: "Hire one eng first" },
    ],
  },
  {
    name: "people.md",
    bullets: [
      { t: 28, text: "Priya — async only" },
      { t: 65, text: "Jane — Acme recruiter" },
      { t: 105, text: "Sam — monthly coffee" },
    ],
  },
  {
    name: "projects.md",
    bullets: [
      { t: 38, text: "ledger v0.4 — pricing pending" },
      { t: 78, text: "Acme loop · 2 left" },
    ],
  },
  {
    name: "learnings.md",
    bullets: [
      { t: 58, text: "no LLM in critical path" },
      { t: 100, text: "vendor-neutral > open-source" },
    ],
  },
];

export const DistillScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleFade = interpolate(frame, [0, 14], [0, 1], { extrapolateRight: "clamp" });
  const exitFade = interpolate(frame, [205, 220], [1, 0], { extrapolateRight: "clamp" });

  const subtitleFade = interpolate(frame, [160, 180], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 28,
        opacity: exitFade,
        padding: "0 60px",
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
          The brain writes itself.
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
          In <em style={{ color: CORAL, fontStyle: "italic", fontWeight: 600 }}>your voice</em>. Committed to git.
        </div>
      </div>

      {/* 4 markdown files growing */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1fr 1fr",
          gap: 16,
          width: "100%",
          maxWidth: 1100,
        }}
      >
        {FILES.map((file, fi) => {
          const fileSpring = spring({
            frame: frame - 12 - fi * 4,
            fps,
            config: { damping: 18, stiffness: 120 },
          });
          return (
            <div
              key={file.name}
              style={{
                background: "rgba(240,224,208,0.05)",
                border: "1px solid rgba(240,224,208,0.14)",
                borderRadius: 14,
                padding: "26px 30px",
                opacity: interpolate(fileSpring, [0, 0.6], [0, 1], { extrapolateRight: "clamp" }),
                transform: `translateY(${interpolate(fileSpring, [0, 1], [16, 0])}px)`,
              }}
            >
              <div
                style={{
                  fontFamily: "ui-monospace, JetBrains Mono, monospace",
                  fontSize: 18,
                  color: CORAL,
                  letterSpacing: 0.5,
                  marginBottom: 16,
                  fontWeight: 700,
                }}
              >
                {file.name}
              </div>
              {file.bullets.map((b, bi) => {
                const lineFade = interpolate(frame, [b.t, b.t + 10], [0, 1], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                });
                const lineY = interpolate(frame, [b.t, b.t + 10], [8, 0], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                });
                return (
                  <div
                    key={bi}
                    style={{
                      fontFamily: "ui-monospace, JetBrains Mono, monospace",
                      fontSize: 19,
                      color: INK,
                      lineHeight: 1.7,
                      opacity: lineFade,
                      transform: `translateY(${lineY}px)`,
                      display: "flex",
                      gap: 12,
                      fontWeight: 500,
                    }}
                  >
                    <span style={{ color: INK_MUTE }}>—</span>
                    <span>{b.text}</span>
                  </div>
                );
              })}
              {frame % 30 < 15 && file.bullets.every((b) => frame >= b.t + 10) === false && (
                <div
                  style={{
                    fontFamily: "ui-monospace, monospace",
                    fontSize: 18,
                    color: CORAL,
                    marginTop: 2,
                  }}
                >
                  ▋
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Footer line */}
      <div
        style={{
          fontFamily: "-apple-system, Inter, system-ui, sans-serif",
          fontSize: 22,
          color: INK_MUTE,
          letterSpacing: -0.3,
          fontWeight: 500,
          opacity: subtitleFade,
          display: "flex",
          gap: 18,
          alignItems: "center",
          marginTop: 8,
        }}
      >
        <span>Auto-linked via [[wikilinks]]</span>
        <span style={{ opacity: 0.4 }}>·</span>
        <span style={{ color: CORAL }}>You own it. Forever.</span>
      </div>
    </AbsoluteFill>
  );
};
