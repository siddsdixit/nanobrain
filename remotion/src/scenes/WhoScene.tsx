import { Typewriter, RevealLines } from "../components/Typewriter";

const COMMAND = "nanobrain who sid";
const OUTPUT = [
  "",
  "4 matches for \"sid\":",
  "",
  "  person/sid.md",
  "    Sid Dixit — indie engineer. Building nanobrain.",
  "",
  "  projects.md",
  "    [[nanobrain]] — maintained by [[Sid Dixit]] (@siddsdixit).",
  "",
  "  learnings.md",
  "    2026-04-18 — Sid: \"markdown ages better than schemas.\"",
];

export const WhoScene = () => {
  const cmdEnd = Math.ceil(COMMAND.length / 0.8) + 6;
  return (
    <>
      <span style={{ color: "#79c0ff", fontWeight: 700 }}>$ </span>
      <Typewriter text={COMMAND} style={{ color: "#e6edf3" }} />
      <RevealLines lines={OUTPUT} startFrame={cmdEnd} framesPerLine={5} />
    </>
  );
};
