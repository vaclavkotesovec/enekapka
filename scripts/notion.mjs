#!/usr/bin/env node
// Notion konektor pro Kapka Klub přes oficiální REST API (bez závislostí, Node 18+).
// Token: NOTION_TOKEN v .env (interní integrace s přístupem ke stránce Kapka).
//
//   node scripts/notion.mjs page <zadani|model|znacka|kapka|id|url>   stránka jako Markdown
//   node scripts/notion.mjs kanban [--status "In progress"]      karty Kanbanu
//   node scripts/notion.mjs card-add "<název>" [--status "Not started"]
//   node scripts/notion.mjs card-status <id|název> "<Not started|In progress|Done>"
//   node scripts/notion.mjs comment <id|alias> "<text>"
//   node scripts/notion.mjs search "<dotaz>"
//   přepínač --json vypíše surovou odpověď API

import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const API = "https://api.notion.com/v1";
const VERSION = "2022-06-28";

const ALIASES = {
  kapka: "4103881e844c8013a1a1d7615ec0555d",
  zadani: "4103881e844c8052ae4ff58141e67f1a",
  znacka: "4103881e844c803495d4f53602529b82",
  model: "4103881e844c8054b3a9df5f076ae11d",
  kanban: "4103881e844c8083bf5ddc41556d63d0",
};
const KANBAN_DB = ALIASES.kanban;
const STATUSES = ["Not started", "In progress", "Done"];

function loadEnv() {
  const f = join(ROOT, ".env");
  if (!existsSync(f)) return;
  for (const line of readFileSync(f, "utf8").split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
}

function die(msg, code = 1) {
  console.error(msg);
  process.exit(code);
}

function toId(ref) {
  if (!ref) die("Chybí id stránky.");
  if (ALIASES[ref.toLowerCase()]) return ALIASES[ref.toLowerCase()];
  const m = ref.replace(/-/g, "").match(/[0-9a-f]{32}/i);
  return m ? m[0] : null;
}

async function api(method, path, body) {
  const token = process.env.NOTION_TOKEN;
  if (!token) die("Chybí NOTION_TOKEN. Zkopíruj .env.example do .env a doplň token (viz .claude/skills/notion-api/SKILL.md).");
  for (let attempt = 0; attempt < 4; attempt++) {
    const res = await fetch(API + path, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        "Notion-Version": VERSION,
        "Content-Type": "application/json",
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (res.status === 429) {
      await new Promise((r) => setTimeout(r, (Number(res.headers.get("retry-after")) || 1) * 1000));
      continue;
    }
    const json = await res.json().catch(() => ({}));
    if (!res.ok) {
      const hint = res.status === 404 || res.status === 403
        ? " Stránka není sdílená s integrací: v Notion na stránce Kapka … → Connections → přidej integraci."
        : res.status === 401 ? " Neplatný NOTION_TOKEN." : "";
      die(`Notion API ${res.status} ${json.code || ""}: ${(json.message || res.statusText).replace(/\.$/, "")}.${hint}`);
    }
    return json;
  }
  die("Notion API: příliš mnoho požadavků (429), zkus to za chvíli.");
}

async function paginate(method, path, body = {}) {
  const out = [];
  let cursor;
  do {
    const sep = path.includes("?") ? "&" : "?";
    const res = method === "GET"
      ? await api("GET", `${path}${sep}page_size=100${cursor ? `&start_cursor=${cursor}` : ""}`)
      : await api(method, path, { ...body, page_size: 100, ...(cursor ? { start_cursor: cursor } : {}) });
    out.push(...res.results);
    cursor = res.has_more ? res.next_cursor : null;
  } while (cursor);
  return out;
}

// ---------- bloky → Markdown ----------
const rt = (arr = []) =>
  arr.map((t) => {
    let s = t.plain_text ?? "";
    if (!s) return "";
    const a = t.annotations || {};
    if (a.code) s = "`" + s + "`";
    if (a.bold) s = `**${s}**`;
    if (a.italic) s = `_${s}_`;
    if (a.strikethrough) s = `~~${s}~~`;
    if (t.href) s = `[${s}](${t.href})`;
    return s;
  }).join("");

function fileName(b) {
  const f = b[b.type] || {};
  const url = f.file?.url || f.external?.url || f.url || "";
  return f.name || rt(f.caption) || decodeURIComponent((url.split("?")[0].split("/").pop()) || b.type);
}

async function blocksToMd(blockId, depth = 0) {
  const blocks = await paginate("GET", `/blocks/${blockId}/children`);
  const ind = "  ".repeat(depth);
  const lines = [];
  let num = 0;
  for (const b of blocks) {
    const v = b[b.type] || {};
    num = b.type === "numbered_list_item" ? num + 1 : 0;
    switch (b.type) {
      case "paragraph": lines.push(ind + rt(v.rich_text)); break;
      case "heading_1": lines.push(`\n# ${rt(v.rich_text)}`); break;
      case "heading_2": lines.push(`\n## ${rt(v.rich_text)}`); break;
      case "heading_3": lines.push(`\n### ${rt(v.rich_text)}`); break;
      case "bulleted_list_item": lines.push(`${ind}- ${rt(v.rich_text)}`); break;
      case "numbered_list_item": lines.push(`${ind}${num}. ${rt(v.rich_text)}`); break;
      case "to_do": lines.push(`${ind}- [${v.checked ? "x" : " "}] ${rt(v.rich_text)}`); break;
      case "toggle": lines.push(`${ind}▸ ${rt(v.rich_text)}`); break;
      case "quote": lines.push(`${ind}> ${rt(v.rich_text)}`); break;
      case "callout": lines.push(`${ind}> ${v.icon?.emoji ? v.icon.emoji + " " : ""}${rt(v.rich_text)}`); break;
      case "code": lines.push("```" + (v.language || "") + "\n" + rt(v.rich_text) + "\n```"); break;
      case "divider": lines.push("---"); break;
      case "child_page": lines.push(`${ind}- 📄 ${v.title} (id ${b.id.replace(/-/g, "")})`); break;
      case "child_database": lines.push(`${ind}- 🗂 ${v.title} (databáze, id ${b.id.replace(/-/g, "")})`); break;
      case "table": {
        const rows = await paginate("GET", `/blocks/${b.id}/children`);
        rows.forEach((r, i) => {
          lines.push("| " + r.table_row.cells.map((c) => rt(c).replace(/\|/g, "\\|")).join(" | ") + " |");
          if (i === 0 && v.has_column_header) lines.push("|" + r.table_row.cells.map(() => " --- |").join(""));
        });
        continue;
      }
      case "image": case "file": case "pdf": case "video": case "embed": case "bookmark":
        lines.push(`${ind}[${b.type}: ${fileName(b)}]`); break;
      case "link_to_page": lines.push(`${ind}→ odkaz na ${v.page_id || v.database_id}`); break;
      case "synced_block": break;
      default: lines.push(`${ind}[${b.type}]`);
    }
    if (b.has_children && !["child_page", "child_database", "table"].includes(b.type)) {
      lines.push(await blocksToMd(b.id, depth + 1));
    }
  }
  return lines.join("\n");
}

const title = (page) => {
  const p = Object.values(page.properties || {}).find((x) => x.type === "title");
  return p ? rt(p.title) : "";
};

// ---------- příkazy ----------
async function cmdPage(ref, json) {
  const id = toId(ref) || die(`Neznámá stránka: ${ref}`);
  const page = await api("GET", `/pages/${id}`);
  if (json) return console.log(JSON.stringify(page, null, 2));
  console.log(`# ${title(page)}\n\n_id ${id} · upraveno ${page.last_edited_time}_\n`);
  console.log(await blocksToMd(id));
}

async function queryKanban(status) {
  const filter = status ? { filter: { property: "Status", status: { equals: status } } } : {};
  return paginate("POST", `/databases/${KANBAN_DB}/query`, filter);
}

async function cmdKanban(status, json) {
  const rows = await queryKanban(status);
  if (json) return console.log(JSON.stringify(rows, null, 2));
  if (!rows.length) return console.log("Kanban je prázdný" + (status ? ` ve stavu ${status}.` : "."));
  console.log("| Status | Název | id |\n| --- | --- | --- |");
  for (const r of rows) console.log(`| ${r.properties.Status?.status?.name ?? ""} | ${title(r)} | ${r.id.replace(/-/g, "")} |`);
}

function checkStatus(s) {
  if (!STATUSES.includes(s)) die(`Neplatný stav „${s}“. Povolené: ${STATUSES.join(", ")}.`);
}

async function cmdCardAdd(name, status = "Not started", json) {
  if (!name) die("Chybí název karty.");
  checkStatus(status);
  const page = await api("POST", "/pages", {
    parent: { database_id: KANBAN_DB },
    properties: { Name: { title: [{ text: { content: name } }] }, Status: { status: { name: status } } },
  });
  console.log(json ? JSON.stringify(page, null, 2) : `Založeno: ${name} [${status}] id ${page.id.replace(/-/g, "")}`);
}

async function resolveCard(ref) {
  const id = toId(ref);
  if (id) return id;
  const hits = (await queryKanban()).filter((r) => title(r).toLowerCase().includes(ref.toLowerCase()));
  if (hits.length !== 1) die(hits.length ? `Název „${ref}“ odpovídá ${hits.length} kartám, použij id.` : `Karta „${ref}“ nenalezena.`);
  return hits[0].id.replace(/-/g, "");
}

async function cmdCardStatus(ref, status, json) {
  checkStatus(status);
  const id = await resolveCard(ref);
  const page = await api("PATCH", `/pages/${id}`, { properties: { Status: { status: { name: status } } } });
  console.log(json ? JSON.stringify(page, null, 2) : `${title(page)} → ${status}`);
}

async function cmdComment(ref, text, json) {
  if (!text) die("Chybí text komentáře.");
  const id = toId(ref) || (await resolveCard(ref));
  const res = await api("POST", "/comments", { parent: { page_id: id }, rich_text: [{ text: { content: text } }] });
  console.log(json ? JSON.stringify(res, null, 2) : `Komentář přidán k ${id}.`);
}

async function cmdSearch(q, json) {
  const res = await api("POST", "/search", { query: q || "", page_size: 20 });
  if (json) return console.log(JSON.stringify(res, null, 2));
  for (const r of res.results) {
    const t = r.object === "database" ? rt(r.title) : title(r);
    console.log(`${r.object === "database" ? "🗂" : "📄"} ${t || "(bez názvu)"}  ${r.id.replace(/-/g, "")}`);
  }
}

// ---------- CLI ----------
loadEnv();
const argv = process.argv.slice(2);
const json = argv.includes("--json");
const si = argv.indexOf("--status");
const status = si > -1 ? argv[si + 1] : undefined;
const [cmd, a1, a2] = argv.filter((a, i) => a !== "--json" && (si === -1 || (i !== si && i !== si + 1)));

const commands = {
  page: () => cmdPage(a1, json),
  kanban: () => cmdKanban(status, json),
  "card-add": () => cmdCardAdd(a1, status, json),
  "card-status": () => cmdCardStatus(a1, a2, json),
  comment: () => cmdComment(a1, a2, json),
  search: () => cmdSearch(a1, json),
};
if (!commands[cmd]) {
  console.log(readFileSync(fileURLToPath(import.meta.url), "utf8").split("\n").slice(1, 11).map((l) => l.replace(/^\/\/ ?/, "")).join("\n"));
  process.exit(cmd ? 1 : 0);
}
await commands[cmd]();
