import { Typewriter, RevealLines } from "../components/Typewriter";

const COMMAND = "nanobrain who alex";
const OUTPUT = [
  "",
  "4 matches for \"alex\":",
  "",
  "  person/alex.md",
  "    Alex Rivera — maintainer. Ships nanobrain.",
  "",
  "  projects.md",
  "    [[nanobrain]] — maintained by [[Alex Rivera]] (@alex).",
  "",
  "  learnings.md",
  "    2026-04-18 — Alex: \"markdown ages better than schemas.\"",
];

export const WhoScene = () => {
  const cmdEnd = Math.ceil(COMMAND.length / 0.8) + 6;
  return (
    <>
      <span style={{ color: "#E08263", fontWeight: 700 }}>$ </span>
      <Typewriter text={COMMAND} style={{ color: "#f0e0d0" }} />
      <RevealLines lines={OUTPUT} startFrame={cmdEnd} framesPerLine={5} />
    </>
  );
};
