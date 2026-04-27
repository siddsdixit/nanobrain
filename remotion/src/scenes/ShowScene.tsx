import { Typewriter, RevealLines } from "../components/Typewriter";

const COMMAND = "nanobrain show person alex";
const OUTPUT = [
  "",
  "person/alex",
  "",
  "  name              Alex Rivera",
  "  role              maintainer",
  "  github            @alex",
  "  shipping          nanobrain · shipping-tracker",
  "  stack             TypeScript · Postgres · Fly.io",
  "  status            active",
  "",
  "# Alex Rivera",
  "",
  "Indie developer. Ships small tools.",
  "Maintainer of nanobrain.",
];

export const ShowScene = () => {
  const cmdEnd = Math.ceil(COMMAND.length / 0.8) + 6;
  return (
    <>
      <span style={{ color: "#E08263", fontWeight: 700 }}>$ </span>
      <Typewriter text={COMMAND} style={{ color: "#f0e0d0" }} />
      <RevealLines lines={OUTPUT} startFrame={cmdEnd} framesPerLine={4} />
    </>
  );
};
