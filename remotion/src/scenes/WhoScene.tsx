import { Typewriter, RevealLines } from "../components/Typewriter";

const COMMAND = "nanobrain who jane";
const OUTPUT = [
  "",
  "3 matches for \"jane\":",
  "",
  "  person/jane-doe.md",
  "    Jane Doe — Recruiter at Acme. First contact 2026-03-12.",
  "",
  "  people.md",
  "    [[Jane Doe]] — recruiter at Acme. Referred by Sam Park.",
  "",
  "  projects.md",
  "    Acme thread — staff-eng loop in progress. Recruiter [[Jane Doe]].",
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
