import { Typewriter, RevealLines } from "../components/Typewriter";

const COMMAND = "nanobrain status";
const OUTPUT = [
  "",
  "nanobrain  ·  ~/my-brain",
  "",
  "  person     1",
  "  project    1",
  "  decision   1",
  "  concept    1",
  "  indexes    7",
];

export const StatusScene = () => {
  const cmdEnd = Math.ceil(COMMAND.length / 0.8) + 6;
  return (
    <>
      <span style={{ color: "#79c0ff", fontWeight: 700 }}>$ </span>
      <Typewriter text={COMMAND} style={{ color: "#e6edf3" }} />
      <RevealLines lines={OUTPUT} startFrame={cmdEnd} framesPerLine={4} />
    </>
  );
};
