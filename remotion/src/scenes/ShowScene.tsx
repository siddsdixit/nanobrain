import { Typewriter, RevealLines } from "../components/Typewriter";

const COMMAND = "nanobrain show person sid";
const OUTPUT = [
  "",
  "person/sid",
  "",
  "  name              Sid Dixit",
  "  role              Indie engineer · founder",
  "  github            @siddsdixit",
  "  shipping          nanobrain (this) · ledger",
  "  stack             TypeScript · Vercel · Fly.io",
  "  status            active",
  "",
  "# Sid Dixit",
  "",
  "Builds developer tools that compound.",
  "Maintainer of nanobrain. Open issues at",
  "github.com/siddsdixit/nanobrain.",
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
