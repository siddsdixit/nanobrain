import { useCurrentFrame } from "remotion";

type Props = {
  text: string;
  startFrame?: number;
  charsPerFrame?: number;
  cursor?: boolean;
  style?: React.CSSProperties;
};

export const Typewriter = ({
  text,
  startFrame = 0,
  charsPerFrame = 0.8,
  cursor = true,
  style,
}: Props) => {
  const frame = useCurrentFrame();
  const elapsed = Math.max(0, frame - startFrame);
  const visibleChars = Math.min(text.length, Math.floor(elapsed * charsPerFrame));
  const typed = text.slice(0, visibleChars);
  const showCursor = cursor && Math.floor(frame / 15) % 2 === 0 && visibleChars < text.length + 6;

  return (
    <span style={style}>
      {typed}
      {showCursor && <span style={{ background: "#e6dccb", color: "#1a1614" }}>▌</span>}
    </span>
  );
};

type LinesProps = {
  lines: string[];
  startFrame: number;
  framesPerLine?: number;
  style?: React.CSSProperties;
};

export const RevealLines = ({
  lines,
  startFrame,
  framesPerLine = 6,
  style,
}: LinesProps) => {
  const frame = useCurrentFrame();
  const elapsed = Math.max(0, frame - startFrame);
  const visibleLines = Math.min(lines.length, Math.floor(elapsed / framesPerLine));

  return (
    <div style={style}>
      {lines.slice(0, visibleLines).map((line, i) => (
        <div key={i}>{line || " "}</div>
      ))}
    </div>
  );
};
