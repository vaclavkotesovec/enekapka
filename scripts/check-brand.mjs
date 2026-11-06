// Kontrola brandu Kapka: barvy v LWC jen přes tokeny var(--kapka-*), nikdy hex natvrdo.
// Jediné místo s hex je CSS modul kapkaStyles (a styles.css sítě, který LWC nejsou).
// Použití: node scripts/check-brand.mjs [kořen projektu]   (výchozí: aktuální složka)

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";

const root = process.argv[2] || process.cwd();
const LWC_DIR = join(root, "force-app", "main", "default", "lwc");
const ALLOWED = new Set([join("kapkaStyles", "kapkaStyles.css")]);
const CHECKED = /\.(css|html|js)$/;
// #rgb, #rgba, #rrggbb, #rrggbbaa; ne HTML entita (&#123;) ani konec slova (href="#")
const HEX = /(?<![&\w])#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})\b/g;

function* files(dir) {
  let entries;
  try {
    entries = readdirSync(dir);
  } catch {
    return;
  }
  for (const name of entries) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) {
      if (name !== "__tests__") yield* files(path);
    } else if (CHECKED.test(name)) {
      yield path;
    }
  }
}

const findings = [];
for (const file of files(LWC_DIR)) {
  const inLwc = relative(LWC_DIR, file);
  if (ALLOWED.has(inLwc)) continue;
  readFileSync(file, "utf8")
    .split(/\r?\n/)
    .forEach((line, i) => {
      for (const match of line.matchAll(HEX)) {
        findings.push(`${relative(root, file).split(sep).join("/")}:${i + 1}  ${match[0]} – použij var(--kapka-*) z kapkaStyles`);
      }
    });
}

if (findings.length) {
  console.log(`Kontrola brandu: ${findings.length}× barva natvrdo\n${findings.join("\n")}`);
  process.exit(1);
}
console.log("Kontrola brandu: bez barev natvrdo.");
