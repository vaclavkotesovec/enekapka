#!/usr/bin/env node
// Automatická akceptace karty: scénáře AC ověří Apex testy v orgu a výsledek se zapíše do databáze Testy.
//   node scripts/accept-apex.mjs "<karta>" <TestovacíTřída> [--tester Jakub] [--org kapka]
// 1. tests-sync karty (řádek na každý scénář AC),
// 2. v testovací třídě najde komentáře „// AC-x.y[, AC-a.b]“ nad testovacími metodami,
// 3. pustí třídu synchronně v orgu (opakuje při zahlceném orgu),
// 4. každý scénář → test-result Prošlo / Selhalo (Selhalo založí bug kartu vývojáři, TT4),
// 5. běh třídy → test-apex (počet testů, chyby, pokrytí).
// Exit 1, když nějaký scénář selhal nebo nemá test.
import { readFileSync } from "node:fs";
import { execFileSync, spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf(name);
  return i > -1 ? args[i + 1] : def;
};
const [card, testClass] = args.filter(
  (a, i) => !a.startsWith("--") && !args[i - 1]?.startsWith("--"),
);
const tester = opt("--tester", "Jakub");
const org = opt("--org", "kapka");
if (!card || !testClass) {
  console.error('Použití: node scripts/accept-apex.mjs "<karta>" <TestovacíTřída> [--tester Jakub] [--org kapka]');
  process.exit(2);
}

const notion = (...a) =>
  execFileSync(process.execPath, [join(ROOT, "scripts/notion.mjs"), ...a], {
    cwd: ROOT,
    encoding: "utf8",
  }).trim();

// 1. scénáře karty
console.log(notion("tests-sync", card));
const key = card.replace(/:.*$/, "").trim();

// 2. mapování AC → testovací metody z komentářů
const source = readFileSync(join(ROOT, `force-app/main/default/classes/${testClass}.cls`), "utf8");
const methodsByAc = new Map();
const re = /\/\/\s*((?:AC-\d+\.\d+)(?:\s*,\s*AC-\d+\.\d+)*)[^\n]*\n(?:\s*@IsTest\s*\n)?\s*static void (\w+)\s*\(/g;
for (const m of source.matchAll(re)) {
  for (const ac of m[1].split(",").map((s) => s.trim())) {
    if (!methodsByAc.has(ac)) methodsByAc.set(ac, []);
    methodsByAc.get(ac).push(m[2]);
  }
}
if (!methodsByAc.size) {
  console.error(`V ${testClass} nejsou komentáře „// AC-x.y“ nad testy.`);
  process.exit(2);
}

// 3. běh testů v orgu
let run;
for (let attempt = 1; attempt <= 30; attempt++) {
  const r = spawnSync(
    "sf",
    ["apex", "run", "test", "--class-names", testClass, "--synchronous", "--code-coverage", "--result-format", "json", "--wait", "10", "--target-org", org],
    { cwd: ROOT, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 },
  );
  const out = r.stdout || "";
  if (/ALREADY_IN_PROCESS|UNKNOWN_EXCEPTION|ORG_ADMIN_LOCKED/.test(out + r.stderr) || !out.trim().startsWith("{")) {
    spawnSync("sleep", ["15"]);
    continue;
  }
  run = JSON.parse(out).result;
  break;
}
if (!run?.tests) {
  console.error("Testy se v orgu nepodařilo spustit (zahlcený org).");
  process.exit(1);
}
const outcome = new Map(run.tests.map((t) => [t.MethodName, t]));

// 4. výsledky scénářů
let problems = 0;
for (const [ac, methods] of [...methodsByAc].sort()) {
  const results = methods.map((m) => outcome.get(m));
  const failed = results.filter((t) => !t || t.Outcome !== "Pass");
  const note = failed.length
    ? `Automaticky (Apex ${testClass}): ${failed.map((t, i) => (t ? `${t.MethodName}: ${t.Message}` : `${methods[i]} neproběhl`)).join("; ")}`.slice(0, 1900)
    : `Automaticky ověřeno v orgu: ${testClass}.${methods.join(", ")}`;
  console.log(notion("test-result", `${key} ${ac}`, failed.length ? "Selhalo" : "Prošlo", "--tester", tester, "--note", note));
  if (failed.length) problems++;
}

// 5. běh třídy
const total = run.tests.length;
const failures = run.tests.filter((t) => t.Outcome !== "Pass").length;
const coverage = Math.round(parseFloat(run.summary?.testRunCoverage || "0"));
console.log(notion("test-apex", testClass, "--tests", String(total), "--failures", String(failures), "--coverage", String(coverage), "--tester", tester, "--card", key));
console.log(`${key}: ${methodsByAc.size} scénářů ověřeno, ${problems} s chybou; ${total - failures}/${total} testů prošlo.`);
process.exit(problems || failures ? 1 : 0);
