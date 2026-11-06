// Testy kontroly brandu (karta design-system, seam S1, AC-5.1).
// Spuštění z kořene repa: node scripts/test/check-brand.test.mjs

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const CHECK = join(dirname(fileURLToPath(import.meta.url)), "..", "check-brand.mjs");

function project(files) {
  const root = mkdtempSync(join(tmpdir(), "check-brand-"));
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  }
  return root;
}

function check(root) {
  return spawnSync(process.execPath, [CHECK, root], { encoding: "utf8" });
}

const LWC = "force-app/main/default/lwc";

// AC-5.1: hex barva v komponentě portálu → kontrola selže a ukáže soubor a řádek
{
  const root = project({
    [`${LWC}/kapkaBalance/kapkaBalance.css`]: ":host {\n  display: block;\n  color: #0b6e73;\n}\n",
  });
  const run = check(root);
  rmSync(root, { recursive: true });
  assert.equal(run.status, 1, "hex barva v komponentě musí kontrolu shodit");
  assert.match(run.stdout + run.stderr, /kapkaBalance\/kapkaBalance\.css:3/, "výstup musí ukázat soubor a řádek");
}

// Komponenta jen s tokeny, kapkaStyles s hex (jediné povolené místo) a odkazy "#" v HTML projdou
{
  const root = project({
    [`${LWC}/kapkaBalance/kapkaBalance.css`]: ":host { color: var(--kapka-ink); }\n",
    [`${LWC}/kapkaBalance/kapkaBalance.html`]: '<template><a href="#">Historie</a> &#123;</template>\n',
    [`${LWC}/kapkaStyles/kapkaStyles.css`]: ".kapka-card { background: #ffffff; }\n",
  });
  const run = check(root);
  rmSync(root, { recursive: true });
  assert.equal(run.status, 0, `čistý projekt má projít, výstup: ${run.stdout}${run.stderr}`);
}

console.log("check-brand: testy prošly");
