import { AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate, Easing, spring } from "remotion";

const CORAL = "#E08263";
const CORAL_DEEP = "#C66A4E";
const INK = "#f0e0d0";
const INK_DIM = "#9a8676";
const INK_MUTE = "#7a6a5e";

/**
 * SpawnEvolveScene — three side-by-side panels showing self-improvement:
 *   1. /brain spawn branding-agent  →  agent file appears
 *   2. /brain compact (weekly)      →  duplicates collapse, archive grows
 *   3. /brain evolve (monthly)      →  one targeted edit proposed
 */
export const SpawnEvolveScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleFade = interpolate(frame, [0, 14], [0, 1], { extrapolateRight: "clamp" });
  const exitFade = interpolate(frame, [200, 215], [1, 0], { extrapolateRight: "clamp" });

  // Panel reveal timings.
  const p1 = spring({ frame: frame - 14, fps, config: { damping: 18, stiffness: 110 } });
  const p2 = spring({ frame: frame - 26, fps, config: { damping: 18, stiffness: 110 } });
  const p3 = spring({ frame: frame - 38, fps, config: { damping: 18, stiffness: 110 } });

  // Spawn — agent file types in.
  const spawnTypeStart = 50;
  const spawnLine1 = interpolate(frame, [spawnTypeStart, spawnTypeStart + 15], [0, 1], { extrapolateRight: "clamp" });
  const spawnLine2 = interpolate(frame, [spawnTypeStart + 18, spawnTypeStart + 33], [0, 1], { extrapolateRight: "clamp" });
  const spawnLine3 = interpolate(frame, [spawnTypeStart + 36, spawnTypeStart + 51], [0, 1], { extrapolateRight: "clamp" });
  const spawnLine4 = interpolate(frame, [spawnTypeStart + 54, spawnTypeStart + 69], [0, 1], { extrapolateRight: "clamp" });

  // Compact — duplicates collapse.
  const compactStart = 90;
  const compactCollapse = interpolate(frame, [compactStart, compactStart + 30], [1, 0.3], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });
  const compactArrow = interpolate(frame, [compactStart + 18, compactStart + 32], [0, 1], { extrapolateRight: "clamp" });

  // Evolve — proposal pulse.
  const evolveStart = 130;
  const evolvePulse = Math.sin((frame - evolveStart) / 6) * 0.5 + 0.5;
  const evolveProposal = interpolate(frame, [evolveStart, evolveStart + 18], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "column",
        gap: 30,
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
          It improves itself.
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
          Spawn agents. Compact weekly. Evolve monthly.
        </div>
      </div>

      {/* Three panels */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1fr 1fr 1fr",
          gap: 22,
          width: "100%",
          maxWidth: 1240,
          marginTop: 12,
        }}
      >
        {/* Panel 1 — SPAWN */}
        <div
          style={{
            background: "rgba(240,224,208,0.05)",
            border: "1px solid rgba(240,224,208,0.14)",
            borderRadius: 16,
            padding: "26px 28px",
            opacity: interpolate(p1, [0, 0.6], [0, 1]),
            transform: `translateY(${interpolate(p1, [0, 1], [16, 0])}px)`,
          }}
        >
          <div
            style={{
              fontFamily: "-apple-system, Inter, system-ui, sans-serif",
              fontSize: 13,
              color: INK_MUTE,
              fontWeight: 700,
              letterSpacing: 2,
              textTransform: "uppercase",
              marginBottom: 12,
            }}
          >
            ✦ Spawn
          </div>
          <div
            style={{
              fontFamily: "ui-monospace, JetBrains Mono, monospace",
              fontSize: 18,
              color: CORAL,
              fontWeight: 700,
              marginBottom: 18,
            }}
          >
            /brain spawn agent
          </div>
          <div
            style={{
              fontFamily: "ui-monospace, JetBrains Mono, monospace",
              fontSize: 17,
              color: INK,
              lineHeight: 1.9,
              background: "rgba(0,0,0,0.3)",
              padding: "16px 18px",
              borderRadius: 8,
              border: "1px solid rgba(240,224,208,0.08)",
            }}
          >
            <div style={{ opacity: spawnLine2 }}>
              <span style={{ color: CORAL, fontWeight: 700 }}>voice</span>{" "}
              <span style={{ color: INK }}>· yours</span>
            </div>
            <div style={{ opacity: spawnLine3 }}>
              <span style={{ color: CORAL, fontWeight: 700 }}>knows</span>{" "}
              <span style={{ color: INK }}>· your decisions</span>
            </div>
            <div style={{ opacity: spawnLine4 }}>
              <span style={{ color: CORAL, fontWeight: 700 }}>scope</span>{" "}
              <span style={{ color: INK }}>· you choose</span>
            </div>
          </div>
        </div>

        {/* Panel 2 — COMPACT */}
        <div
          style={{
            background: "rgba(240,224,208,0.05)",
            border: "1px solid rgba(240,224,208,0.14)",
            borderRadius: 16,
            padding: "26px 28px",
            opacity: interpolate(p2, [0, 0.6], [0, 1]),
            transform: `translateY(${interpolate(p2, [0, 1], [16, 0])}px)`,
          }}
        >
          <div
            style={{
              fontFamily: "-apple-system, Inter, system-ui, sans-serif",
              fontSize: 13,
              color: INK_MUTE,
              fontWeight: 700,
              letterSpacing: 2,
              textTransform: "uppercase",
              marginBottom: 12,
            }}
          >
            ↻ Compact · weekly
          </div>
          <div
            style={{
              fontFamily: "ui-monospace, JetBrains Mono, monospace",
              fontSize: 18,
              color: CORAL,
              fontWeight: 700,
              marginBottom: 18,
            }}
          >
            /brain compact
          </div>
          <div
            style={{
              fontFamily: "ui-monospace, JetBrains Mono, monospace",
              fontSize: 17,
              lineHeight: 1.9,
              display: "flex",
              flexDirection: "column",
              gap: 2,
            }}
          >
            <div style={{ opacity: compactCollapse, textDecoration: frame > compactStart + 10 ? "line-through" : "none", color: frame > compactStart + 10 ? INK_MUTE : INK }}>
              — Postgres pick
            </div>
            <div style={{ opacity: compactCollapse, textDecoration: frame > compactStart + 14 ? "line-through" : "none", color: frame > compactStart + 14 ? INK_MUTE : INK }}>
              — same (4/16)
            </div>
            <div style={{ opacity: compactCollapse, textDecoration: frame > compactStart + 18 ? "line-through" : "none", color: frame > compactStart + 18 ? INK_MUTE : INK }}>
              — same (4/22)
            </div>
            <div style={{ opacity: compactArrow, color: CORAL, marginTop: 8, fontSize: 22, fontWeight: 700 }}>↓</div>
            <div style={{ opacity: compactArrow, color: INK, fontWeight: 600 }}>— Postgres pick</div>
          </div>
        </div>

        {/* Panel 3 — EVOLVE */}
        <div
          style={{
            background: "rgba(240,224,208,0.05)",
            border: "1px solid rgba(240,224,208,0.14)",
            borderRadius: 16,
            padding: "26px 28px",
            opacity: interpolate(p3, [0, 0.6], [0, 1]),
            transform: `translateY(${interpolate(p3, [0, 1], [16, 0])}px)`,
            position: "relative",
            overflow: "hidden",
          }}
        >
          <div
            style={{
              fontFamily: "-apple-system, Inter, system-ui, sans-serif",
              fontSize: 13,
              color: INK_MUTE,
              fontWeight: 700,
              letterSpacing: 2,
              textTransform: "uppercase",
              marginBottom: 12,
            }}
          >
            ⟳ Evolve · monthly
          </div>
          <div
            style={{
              fontFamily: "ui-monospace, JetBrains Mono, monospace",
              fontSize: 18,
              color: CORAL,
              fontWeight: 700,
              marginBottom: 18,
            }}
          >
            /brain evolve
          </div>
          <div
            style={{
              fontFamily: "ui-monospace, JetBrains Mono, monospace",
              opacity: evolveProposal,
            }}
          >
            <div
              style={{
                background: `rgba(224,130,99,${0.1 + evolvePulse * 0.08})`,
                border: `1.5px solid rgba(224,130,99,${0.5 + evolvePulse * 0.2})`,
                borderRadius: 10,
                padding: "16px 18px",
              }}
            >
              <div style={{ color: CORAL, fontWeight: 700, fontSize: 12, letterSpacing: 2, marginBottom: 10 }}>
                ✦ PROPOSED EDIT
              </div>
              <div style={{ color: INK, fontSize: 18, fontStyle: "italic", fontWeight: 500, lineHeight: 1.4 }}>
                "always async,<br/>never meetings"
              </div>
              <div style={{ color: INK_MUTE, fontSize: 13, marginTop: 10 }}>
                from 14 decisions
              </div>
            </div>
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};
