// Testy příkazů tests-sync, test-result a test-apex proti podvrženému Notion API (seam S1, AC-1 až AC-3).
// Spuštění z kořene repa: node scripts/test/notion.test.mjs

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const CLI = join(HERE, "..", "notion.mjs");
const MOCK = pathToFileURL(join(HERE, "notion-mock.mjs")).href;
const KANBAN_DB = "4103881e844c8083bf5ddc41556d63d0";
const TESTS_DB = "4103881e844c8162a83cf19c3e0eda3d";
const CARD_ID = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

const GHERKIN = `# language: cs
Požadavek: Připsání základních kapek za nákup
  Jako člen Kapka Klubu
  chci dostat kapky za tankování a nákup v obchodě

  Pravidlo: AC-1 — Za každý celý litr paliva jedna kapka

    Scénář: AC-1.1 — Demo nákup Jany (jen základ)
      Pokud aktivní členka Jana Nováková
      A nákup na stanici Kapka Brno – Vídeňská s 45 l paliva a ostatním za 180 Kč
      Když se nákup dokončí
      Pak má Jana připsáno 54 kapek jako základ

    Scénář: AC-1.2 — Litry se sčítají za celý nákup
      Pokud nákup aktivního člena se dvěma položkami paliva po 20,6 l
      Když se nákup dokončí
      Pak má člen připsáno 41 kapek

    Scénář: AC-1.3 — Nedokončených 20 Kč se nepočítá
      Pokud nákup aktivního člena jen s ostatním zbožím za 39 Kč
      Když se nákup dokončí
      Pak má člen připsánu 1 kapku

  Pravidlo: AC-2 — Za jeden nákup vznikne nejvýš jedno připsání

    Scénář: AC-2.1 — Opakované dokončení
      Pokud dokončený nákup, za který člen dostal kapky
      Když se nákup dokončí znovu
      Pak má člen za tento nákup pořád jen jedno připsání

    Scénář: AC-2.2 — Nákup za 0 kapek
      Pokud nákup aktivního člena jen s kávou za 15 Kč
      Když se nákup dokončí
      Pak člen nemá za tento nákup žádný pohyb kapek

  Pravidlo: AC-3 — Kapky dostane jen aktivní člen

    Scénář: AC-3.1 — Neaktivní člen
      Pokud člen ve stavu Registrován
      Když se jeho nákup dokončí
      Pak se nákup uloží a žádné kapky se nepřipíší

    Scénář: AC-3.2 — Nákup před registrací
      Pokud aktivní člen registrovaný 1. 11. 2026
      A nákup s datem 30. 10. 2026
      Když se nákup dokončí
      Pak se žádné kapky nepřipíší

  Pravidlo: AC-4 — Platí pravidla platná k datu nákupu

    Scénář: AC-4.1 — Změna pravidla
      Pokud pravidlo za palivo 1 kapka za litr platné do 31. 10. 2026
      A nákup aktivního člena s 10 l paliva s datem 30. 10. 2026
      Když se nákup dokončí
      Pak má člen připsáno 10 kapek

  Pravidlo: AC-5 — Připsané kapky platí 12 měsíců od nákupu

    Scénář: AC-5.1 — Datum expirace a aktivita
      Pokud nákup aktivního člena s datem 6. 11. 2026 za 54 kapek
      Když se nákup dokončí
      Pak připsání platí do 6. 11. 2027
      A poslední aktivita člena je 6. 11. 2026`;

const rt = (s) => [{ type: "text", text: { content: s }, plain_text: s }];
const kanbanCard = (id, name, owners) => ({
  object: "page",
  id,
  parent: { database_id: KANBAN_DB },
  properties: {
    Name: { type: "title", title: rt(name) },
    Status: { type: "status", status: { name: "Business ready" } },
    Řešitel: {
      type: "multi_select",
      multi_select: owners.map((name) => ({ name })),
    },
  },
  children: [],
});

const dir = mkdtempSync(join(tmpdir(), "notion-test-"));
const STATE = join(dir, "state.json");
const earn = kanbanCard(CARD_ID, "earn-zaklad: základní kapky za nákup", [
  "Jan",
]);
earn.children = [
  {
    object: "block",
    id: "b1",
    type: "code",
    code: { language: "gherkin", rich_text: rt(GHERKIN) },
  },
];
writeFileSync(
  STATE,
  JSON.stringify({
    pages: {
      [CARD_ID]: earn,
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb: kanbanCard(
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        "earn-zaklad-extra: jiná karta se stejným prefixem",
        ["Václav"],
      ),
    },
    log: [],
  }),
);

function run(...args) {
  const r = spawnSync(process.execPath, ["--import", MOCK, CLI, ...args], {
    env: { ...process.env, NOTION_TOKEN: "test", NOTION_MOCK_STATE: STATE },
    encoding: "utf8",
  });
  return { code: r.status, out: r.stdout, err: r.stderr };
}
function ok(...args) {
  const r = run(...args);
  assert.equal(r.code, 0, `${args.join(" ")} selhal: ${r.err}`);
  return r.out;
}
const state = () => JSON.parse(readFileSync(STATE, "utf8"));
const text = (p) => (p?.[p.type] || []).map((t) => t.plain_text).join("");
const rows = () =>
  Object.values(state().pages).filter(
    (p) => !p.archived && p.parent?.database_id === TESTS_DB,
  );
const row = (name) => {
  const hits = rows().filter((r) => text(r.properties.Name) === name);
  assert.equal(hits.length, 1, `řádek ${name}: ${hits.length}×`);
  return hits[0].properties;
};
const sel = (p) => p?.select?.name;
const d = new Date();
const TODAY = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

const tests = [];
const test = (name, fn) => tests.push([name, fn]);

test("AC-1.1 tests-sync založí 9 řádků Nespuštěno s kroky a očekávaným výsledkem", () => {
  ok("tests-sync", "earn-zaklad:");
  const names = rows()
    .map((r) => text(r.properties.Name))
    .sort();
  assert.deepEqual(names, [
    "earn-zaklad AC-1.1",
    "earn-zaklad AC-1.2",
    "earn-zaklad AC-1.3",
    "earn-zaklad AC-2.1",
    "earn-zaklad AC-2.2",
    "earn-zaklad AC-3.1",
    "earn-zaklad AC-3.2",
    "earn-zaklad AC-4.1",
    "earn-zaklad AC-5.1",
  ]);
  for (const r of rows()) {
    assert.equal(sel(r.properties.Stav), "Nespuštěno");
    assert.equal(sel(r.properties.Typ), "Ruční");
    assert.equal(text(r.properties.Karta), "earn-zaklad");
  }
  const a = row("earn-zaklad AC-1.1");
  assert.equal(
    text(a.Kroky),
    "Pokud aktivní členka Jana Nováková\nA nákup na stanici Kapka Brno – Vídeňská s 45 l paliva a ostatním za 180 Kč\nKdyž se nákup dokončí",
  );
  assert.equal(
    text(a["Očekávaný výsledek"]),
    "Pak má Jana připsáno 54 kapek jako základ",
  );
  assert.equal(
    text(row("earn-zaklad AC-5.1")["Očekávaný výsledek"]),
    "Pak připsání platí do 6. 11. 2027\nA poslední aktivita člena je 6. 11. 2026",
  );
});

test("AC-2.1 test-result Prošlo zapíše stav, testera a dnešní datum", () => {
  ok("test-result", "earn-zaklad AC-1.1", "Prošlo", "--tester", "Jakub");
  const a = row("earn-zaklad AC-1.1");
  assert.equal(sel(a.Stav), "Prošlo");
  assert.equal(sel(a.Tester), "Jakub");
  assert.equal(a.Datum.date.start, TODAY);
});

test("AC-1.2 opakovaný tests-sync nezaloží duplicity a nechá výsledek AC-1.1", () => {
  const out = ok("tests-sync", "earn-zaklad:");
  assert.match(out, /0 nových/);
  assert.equal(rows().length, 9);
  const a = row("earn-zaklad AC-1.1");
  assert.equal(sel(a.Stav), "Prošlo");
  assert.equal(sel(a.Tester), "Jakub");
  assert.equal(a.Datum.date.start, TODAY);
});

test("AC-1.2 změněný text scénáře se aktualizuje bez přepsání výsledku", () => {
  const s = state();
  const code = s.pages[CARD_ID].children[0].code;
  code.rich_text = rt(
    text({ type: "rich_text", rich_text: code.rich_text }).replace(
      "54 kapek jako základ",
      "54 kapek",
    ),
  );
  writeFileSync(STATE, JSON.stringify(s));
  assert.match(ok("tests-sync", "earn-zaklad:"), /1 aktualizovaných/);
  const a = row("earn-zaklad AC-1.1");
  assert.equal(text(a["Očekávaný výsledek"]), "Pak má Jana připsáno 54 kapek");
  assert.equal(sel(a.Stav), "Prošlo");
  assert.equal(rows().length, 9);
});

test("AC-2.2 test-apex přidá řádek Apex Prošlo s poznámkou N/N a pokrytím", () => {
  ok(
    "test-apex",
    "KapkaEarnServiceTest",
    "--tests",
    "10",
    "--failures",
    "0",
    "--coverage",
    "96",
    "--tester",
    "Jan",
  );
  const a = row("KapkaEarnServiceTest");
  assert.equal(sel(a.Typ), "Apex");
  assert.equal(sel(a.Stav), "Prošlo");
  assert.equal(sel(a.Tester), "Jan");
  assert.equal(a.Datum.date.start, TODAY);
  assert.equal(text(a.Poznámka), "10/10, pokrytí 96 %");
});

test("AC-2.2 test-apex s chybami je Selhalo", () => {
  ok(
    "test-apex",
    "KapkaFailTest",
    "--tests",
    "5",
    "--failures",
    "2",
    "--coverage",
    "70",
    "--tester",
    "Václav",
  );
  const a = row("KapkaFailTest");
  assert.equal(sel(a.Stav), "Selhalo");
  assert.equal(text(a.Poznámka), "3/5, pokrytí 70 %");
});

test("AC-3.1 test-result Selhalo založí bug pro vývojáře původní karty s odkazem na test", () => {
  ok(
    "test-result",
    "earn-zaklad AC-2.1",
    "Selhalo",
    "--tester",
    "Jakub",
    "--note",
    "dvě připsání",
  );
  const a = row("earn-zaklad AC-2.1");
  assert.equal(sel(a.Stav), "Selhalo");
  assert.equal(text(a.Poznámka), "dvě připsání");
  const s = state();
  const testRow = Object.values(s.pages).find(
    (p) => text(p.properties.Name) === "earn-zaklad AC-2.1",
  );
  const bugs = Object.values(s.pages).filter(
    (p) => text(p.properties.Name) === "bug: earn-zaklad AC-2.1",
  );
  assert.equal(bugs.length, 1);
  const bug = bugs[0];
  assert.equal(bug.parent.database_id, KANBAN_DB);
  assert.equal(bug.properties.Status.status.name, "Not started");
  assert.deepEqual(
    bug.properties.Řešitel.multi_select.map((o) => o.name),
    ["Jan"],
  );
  const links = bug.children
    .flatMap((b) => (b[b.type].rich_text || []).map((t) => t.href))
    .filter(Boolean);
  assert.ok(
    links.includes(testRow.url),
    `bug neodkazuje na ${testRow.url}: ${links}`,
  );
});

test("AC-3.1 opakované Selhalo nezaloží druhý bug", () => {
  ok("test-result", "earn-zaklad AC-2.1", "Selhalo", "--tester", "Jakub");
  const bugs = Object.values(state().pages).filter(
    (p) => text(p.properties.Name) === "bug: earn-zaklad AC-2.1",
  );
  assert.equal(bugs.length, 1);
  assert.equal(text(row("earn-zaklad AC-2.1").Poznámka), "dvě připsání");
});

test("chyby: neznámý test a neplatný tester", () => {
  const r1 = run(
    "test-result",
    "earn-zaklad AC-9.9",
    "Prošlo",
    "--tester",
    "Jakub",
  );
  assert.notEqual(r1.code, 0);
  assert.match(r1.err, /nejdřív tests-sync/);
  const r2 = run(
    "test-result",
    "earn-zaklad AC-1.2",
    "Prošlo",
    "--tester",
    "Pepa",
  );
  assert.notEqual(r2.code, 0);
  assert.match(r2.err, /Neplatný tester/);
  const r3 = run(
    "test-result",
    "earn-zaklad AC-1.2",
    "OK",
    "--tester",
    "Jakub",
  );
  assert.notEqual(r3.code, 0);
});

let failed = 0;
for (const [name, fn] of tests) {
  try {
    fn();
    console.log(`✔ ${name}`);
  } catch (e) {
    failed++;
    console.log(`✘ ${name}\n  ${e.message.split("\n").join("\n  ")}`);
  }
}
rmSync(dir, { recursive: true, force: true });
console.log(`\n${tests.length - failed}/${tests.length} prošlo`);
process.exit(failed ? 1 : 0);
