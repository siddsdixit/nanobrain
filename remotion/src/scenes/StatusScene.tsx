import { Typewriter, RevealLines } from "../components/Typewriter";

const COMMAND = "nanobrain status";
const OUTPUT = [
  "",
  "nanobrain  ·  ~/my-brain",
  "",
  "  person     12",
  "  project    4",
  "  decision   18",
  "  concept    6",
  "  indexes    7",
];

export const StatusScene = () => {
  const cmdEnd = Math.ceil(COMMAND.length / 0.8) + 6;
  return (
    <>
      <span style={{ color: "#E08263", fontWeight: 700 }}>$ </span>
      <Typewriter text={COMMAND} style={{ color: "#f0e0d0" }} />
      <RevealLines lines={OUTPUT} startFrame={cmdEnd} framesPerLine={4} />
    </>
  );
};
