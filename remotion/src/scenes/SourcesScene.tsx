import { AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate, Easing, spring } from "remotion";

const CORAL = "#E08263";
const CORAL_DEEP = "#C66A4E";
const INK = "#f0e0d0";
const INK_DIM = "#9a8676";
const INK_MUTE = "#7a6a5e";

const SOURCES = [
  { name: "claude", label: "Claude session", color: "#cc7b5e" },
  { name: "gmail",  label: "Gmail thread",   color: "#d4574e" },
  { name: "gcal",   label: "Calendar event", color: "#5e9bcc" },
  { name: "gdrive", label: "Drive doc",      color: "#7ec77a" },
  { name: "slack",  label: "Slack message",  color: "#8e6ec9" },
];

/**
 * SourcesScene — visualize 5 sources flowing through the capture pipeline.
 * Sources on the left, hook in the middle, INBOX on the right.
 * Particles flow left → middle → right.
 */
export const SourcesScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleFade = interpolate(frame, [0, 14], [0, 1], { extrapolateRight: "clamp" });
  const exitFade = interpolate(frame, [195, 210], [1, 0], { extrapolateRight: "clamp" });

  // Hook box appears.
  const hookSpring = spring({
    frame: frame - 18,
    fps,
    config: { damping: 18, stiffness: 110 },
  });
  const hookScale = interpolate(hookSpring, [0, 1], [0.7, 1]);
  const hookOpacity = interpolate(hookSpring, [0, 0.6], [0, 1], { extrapolateRight: "clamp" });

  // INBOX panel.
  const inboxFade = interpolate(frame, [40, 60], [0, 1], { extrapolateRight: "clamp" });
  const inboxX = interpolate(frame, [40, 60], [30, 0], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 32,
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
          Capture is invisible.
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
          5 sources → 50ms hook → markdown.
        </div>
      </div>

      {/* Pipeline: sources → hook → inbox */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "320px 240px 360px",
          gap: 36,
          alignItems: "center",
          marginTop: 24,
        }}
      >
        {/* Sources column */}
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          {SOURCES.map((s, i) => {
            const appear = spring({
              frame: frame - 24 - i * 7,
              fps,
              config: { damping: 14, stiffness: 130 },
            });
            // Each source pulses to indicate "data flowing"
            const pulse = Math.sin((frame - 60 - i * 8) / 10) * 0.5 + 0.5;
            const pulseOpacity = frame > 60 + i * 8 ? 0.5 + pulse * 0.5 : 0;
            return (
              <div
                key={s.name}
                style={{
                  fontFamily: "ui-monospace, JetBrains Mono, monospace",
                  fontSize: 20,
                  color: INK,
                  background: "rgba(240,224,208,0.05)",
                  border: `1.5px solid ${s.color}66`,
                  borderRadius: 10,
                  padding: "14px 18px",
                  display: "flex",
                  alignItems: "center",
                  gap: 14,
                  transform: `scale(${appear}) translateX(${(1 - appear) * -30}px)`,
                  opacity: appear,
                  position: "relative",
                }}
              >
                <span
                  style={{
                    width: 11,
                    height: 11,
                    borderRadius: "50%",
                    background: s.color,
                    boxShadow: `0 0 ${pulseOpacity * 14}px ${s.color}`,
                    flexShrink: 0,
                  }}
                />
                <span style={{ fontWeight: 700 }}>{s.name}</span>
              </div>
            );
          })}
        </div>

        {/* Center: hook */}
        <div
          style={{
            transform: `scale(${hookScale})`,
            opacity: hookOpacity,
            position: "relative",
          }}
        >
          <div
            style={{
              fontFamily: "-apple-system, Inter, system-ui, sans-serif",
              background: `linear-gradient(135deg, ${CORAL} 0%, ${CORAL_DEEP} 100%)`,
              color: "#1a1614",
              borderRadius: 16,
              padding: "26px 28px",
              textAlign: "center",
              fontWeight: 800,
              boxShadow: `0 0 50px rgba(224,130,99,0.35)`,
            }}
          >
            <div style={{ fontSize: 32, letterSpacing: -0.8, lineHeight: 1 }}>Stop hook</div>
            <div
              style={{
                fontFamily: "ui-monospace, JetBrains Mono, monospace",
                fontSize: 18,
                opacity: 0.75,
                marginTop: 8,
                fontWeight: 600,
              }}
            >
              &lt; 50ms
            </div>
          </div>
          {/* Flow arrows */}
          <div
            style={{
              position: "absolute",
              top: "50%",
              left: -36,
              transform: "translateY(-50%)",
              fontSize: 24,
              color: CORAL,
              opacity: hookOpacity,
            }}
          >
            ⟶
          </div>
          <div
            style={{
              position: "absolute",
              top: "50%",
              right: -36,
              transform: "translateY(-50%)",
              fontSize: 24,
              color: CORAL,
              opacity: hookOpacity,
            }}
          >
            ⟶
          </div>
        </div>

        {/* INBOX panel */}
        <div
          style={{
            opacity: inboxFade,
            transform: `translateX(${inboxX}px)`,
          }}
        >
          <div
            style={{
              fontFamily: "ui-monospace, JetBrains Mono, monospace",
              background: "rgba(240,224,208,0.06)",
              border: "1px solid rgba(240,224,208,0.18)",
              borderRadius: 12,
              padding: "20px 22px",
              fontSize: 18,
              color: INK,
              lineHeight: 1.8,
            }}
          >
            <div style={{ color: INK_DIM, fontSize: 14, marginBottom: 14, letterSpacing: 2, textTransform: "uppercase", fontWeight: 600 }}>
              INBOX.md
            </div>
            {SOURCES.map((s, i) => {
              const fadeIn = interpolate(
                frame,
                [70 + i * 12, 80 + i * 12],
                [0, 1],
                { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
              );
              return (
                <div
                  key={s.name}
                  style={{
                    opacity: fadeIn,
                    color: INK,
                    fontSize: 18,
                    fontWeight: 600,
                  }}
                >
                  <span style={{ color: s.color, marginRight: 10, fontWeight: 800 }}>+</span>
                  {s.name}
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Subtitle */}
      <div
        style={{
          fontFamily: "-apple-system, Inter, system-ui, sans-serif",
          fontSize: 22,
          color: INK_MUTE,
          letterSpacing: -0.3,
          fontWeight: 500,
          opacity: interpolate(frame, [140, 160], [0, 1], { extrapolateRight: "clamp" }),
        }}
      >
        Secrets redacted. Zero blocking.
      </div>
    </AbsoluteFill>
  );
};
