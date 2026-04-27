import { AbsoluteFill, useCurrentFrame } from "remotion";

// Subtle CRT scanline overlay. Sits above everything at low opacity.
// Animates a slow vertical drift to feel alive without being distracting.
export const Scanlines = () => {
  const frame = useCurrentFrame();
  const offset = (frame * 0.4) % 4;

  return (
    <AbsoluteFill
      style={{
        pointerEvents: "none",
        backgroundImage:
          "repeating-linear-gradient(180deg, rgba(255,255,255,0.02) 0 1px, transparent 1px 4px)",
        backgroundPositionY: `${offset}px`,
        mixBlendMode: "overlay",
      }}
    />
  );
};

// Soft vignette to focus the eye toward the center.
export const Vignette = () => (
  <AbsoluteFill
    style={{
      pointerEvents: "none",
      background:
        "radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.55) 100%)",
    }}
  />
);

// Animated grid/dot pattern background.
export const GridBackground = () => {
  const frame = useCurrentFrame();
  const drift = (frame * 0.3) % 80;

  return (
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(ellipse at top, #2a0e4a 0%, #110424 45%, #050010 100%)",
      }}
    >
      <AbsoluteFill
        style={{
          backgroundImage:
            "radial-gradient(rgba(255,138,112,0.18) 1px, transparent 1px)",
          backgroundSize: "80px 80px",
          backgroundPositionX: `${drift}px`,
          backgroundPositionY: `${drift}px`,
          opacity: 0.7,
        }}
      />
    </AbsoluteFill>
  );
};
