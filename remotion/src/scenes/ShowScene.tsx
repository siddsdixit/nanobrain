import { Typewriter, RevealLines } from "../components/Typewriter";

const COMMAND = "nanobrain show person jane-doe";
const OUTPUT = [
  "",
  "person/jane-doe",
  "",
  "  name              Jane Doe",
  "  role              Recruiter at Acme",
  "  status            active",
  "  first_contact     2026-03-12",
  "",
  "# Jane Doe",
  "",
  "Recruiter at Acme. Sourced via [[Sam Park]] (Acme PM).",
];

export const ShowScene = () => {
  const cmdEnd = Math.ceil(COMMAND.length / 0.8) + 6;
  return (
    <>
      <span style={{ color: "#79c0ff", fontWeight: 700 }}>$ </span>
      <Typewriter text={COMMAND} style={{ color: "#e6edf3" }} />
      <RevealLines lines={OUTPUT} startFrame={cmdEnd} framesPerLine={4} />
    </>
  );
};
