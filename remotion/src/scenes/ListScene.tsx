import { Typewriter, RevealLines } from "../components/Typewriter";

const COMMAND = "nanobrain list project";
const OUTPUT = [
  "",
  "1 project:",
  "",
  "  ledger                  [active]    Ledger",
];

export const ListScene = () => {
  const cmdEnd = Math.ceil(COMMAND.length / 0.8) + 6;
  return (
    <>
      <span style={{ color: "#79c0ff", fontWeight: 700 }}>$ </span>
      <Typewriter text={COMMAND} style={{ color: "#e6edf3" }} />
      <RevealLines lines={OUTPUT} startFrame={cmdEnd} framesPerLine={5} />
    </>
  );
};
