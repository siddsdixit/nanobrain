import { Typewriter, RevealLines } from "../components/Typewriter";

const COMMAND = "nanobrain list project";
const OUTPUT = [
  "",
  "4 projects:",
  "",
  "  nanobrain               [active]    second brain in markdown",
  "  ledger                  [active]    B2B finance tool",
  "  brain-evolve-cycle      [paused]    weekly self-improvement loop",
  "  source-plugins-q2       [active]    Slack + Granola + Gmail ingest",
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
