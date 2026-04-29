import { useCurrentFrame, useVideoConfig, spring } from "remotion";

// Hand-pixeled 5×7 brick glyphs. 1 = brick, 0 = empty.
// Add letters here as needed; only the ones actually used need exist.
export const GLYPHS: Record<string, number[][]> = {
  A: [
    [0, 1, 1, 1, 0],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
  ],
  B: [
    [1, 1, 1, 1, 0],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 1, 1, 1, 0],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 1, 1, 1, 0],
  ],
  H: [
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 1, 1, 1, 1],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
  ],
  I: [
    [1, 1, 1, 1, 1],
    [0, 0, 1, 0, 0],
    [0, 0, 1, 0, 0],
    [0, 0, 1, 0, 0],
    [0, 0, 1, 0, 0],
    [0, 0, 1, 0, 0],
    [1, 1, 1, 1, 1],
  ],
  K: [
    [1, 0, 0, 0, 1],
    [1, 0, 0, 1, 0],
    [1, 0, 1, 0, 0],
    [1, 1, 0, 0, 0],
    [1, 0, 1, 0, 0],
    [1, 0, 0, 1, 0],
    [1, 0, 0, 0, 1],
  ],
  N: [
    [1, 0, 0, 0, 1],
    [1, 1, 0, 0, 1],
    [1, 1, 0, 0, 1],
    [1, 0, 1, 0, 1],
    [1, 0, 0, 1, 1],
    [1, 0, 0, 1, 1],
    [1, 0, 0, 0, 1],
  ],
  O: [
    [0, 1, 1, 1, 0],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [0, 1, 1, 1, 0],
  ],
  R: [
    [1, 1, 1, 1, 0],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 1, 1, 1, 0],
    [1, 1, 0, 0, 0],
    [1, 0, 1, 0, 0],
    [1, 0, 0, 1, 1],
  ],
  S: [
    [0, 1, 1, 1, 1],
    [1, 0, 0, 0, 0],
    [1, 0, 0, 0, 0],
    [0, 1, 1, 1, 0],
    [0, 0, 0, 0, 1],
    [0, 0, 0, 0, 1],
    [1, 1, 1, 1, 0],
  ],
  T: [
    [1, 1, 1, 1, 1],
    [0, 0, 1, 0, 0],
    [0, 0, 1, 0, 0],
    [0, 0, 1, 0, 0],
    [0, 0, 1, 0, 0],
    [0, 0, 1, 0, 0],
    [0, 0, 1, 0, 0],
  ],
  W: [
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 0, 1, 0, 1],
    [1, 0, 1, 0, 1],
    [1, 1, 0, 1, 1],
    [1, 0, 0, 0, 1],
  ],
  " ": [
    [0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0],
  ],
};

export const COLS = 5;
export const ROWS = 7;

export const CORAL = "#E08263";
export const CORAL_TRACE = "#7A4429";
export const CORAL_HIGHLIGHT = "#F4A586";

type BrickProps = {
  x: number;
  y: number;
  cell: number;
  delay: number;
  frame: number;
  fps: number;
};

const Brick = ({ x, y, cell, delay, frame, fps }: BrickProps) => {
  const appear = spring({
    frame: frame - delay,
    fps,
    config: { damping: 16, stiffness: 220, mass: 0.9 },
  });
  const trace = Math.max(2, Math.round(cell * 0.16));
  return (
    <>
      <div
        style={{
          position: "absolute",
          left: x + trace,
          top: y + trace,
          width: cell - 4,
          height: cell - 4,
          border: `1.5px solid ${CORAL_TRACE}`,
          borderRadius: 2,
          opacity: appear * 0.85,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: x,
          top: y,
          width: cell - 4,
          height: cell - 4,
          background: CORAL,
          borderRadius: 2,
          transform: `scale(${appear})`,
          transformOrigin: "center",
          boxShadow: `inset 0 1px 0 ${CORAL_HIGHLIGHT}, inset 0 -2px 0 rgba(0,0,0,0.18)`,
        }}
      />
    </>
  );
};

type BrickWordProps = {
  text: string;
  cell?: number;
  letterGap?: number;
  startDelay?: number;
};

// Renders a single line of brick text. Width and height are computed from
// the text length so callers can wrap it in a centered flex container.
export const BrickWord = ({
  text,
  cell = 26,
  letterGap = 16,
  startDelay = 0,
}: BrickWordProps) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const chars = text.split("");
  const letterPitch = COLS * cell + letterGap;
  const width = chars.length * letterPitch - letterGap;
  const height = ROWS * cell;

  const bricks: JSX.Element[] = [];
  chars.forEach((char, li) => {
    const grid = GLYPHS[char];
    if (!grid) return;
    const lx = li * letterPitch;
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        if (!grid[r][c]) continue;
        const delay = startDelay + li * 3 + r * 1.2 + c * 0.5;
        bricks.push(
          <Brick
            key={`${li}-${r}-${c}`}
            x={lx + c * cell}
            y={r * cell}
            cell={cell}
            delay={delay}
            frame={frame}
            fps={fps}
          />
        );
      }
    }
  });

  return <div style={{ position: "relative", width, height }}>{bricks}</div>;
};
