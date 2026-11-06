#!/usr/bin/env node
// Notion konektor pro Kapka Klub přes oficiální REST API (bez závislostí, Node 18+).
// Token: NOTION_TOKEN v .env (interní integrace s přístupem ke stránce Kapka).
//
//   page <zadani|model|znacka|kapka|karta|id|url>        stránka nebo karta jako Markdown
//   kanban [--status "In progress"]                       karty Kanbanu
//   card-add "<název>" [--status "Not started"] [--file spec.md]
//   card-status <karta> "<Not started|In progress|Done>"
//   write <stránka|karta> <soubor.md|-> [--append]        nahradí (nebo připojí) obsah; podstránky zůstanou
//   subpage <stránka|karta> "<název>" [soubor.md|-]       nová podstránka, např. review nebo retro
//   comment <stránka|karta> "<text>"
//   search "<dotaz>"
//   --json vypíše surovou odpověď API; <karta> = id nebo jednoznačná část názvu

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
      const hint = json.code === "restricted_resource"
        ? " Integrace na to nemá oprávnění: v nastavení integrace (Capabilities) zapni čtení/zápis obsahu a komentáře."
        : res.status === 404 || res.status === 403
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
  const id = await resolvePage(ref);
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

async function cmdCardAdd(name, status = "Not started", file, json) {
  if (!name) die("Chybí název karty.");
  checkStatus(status);
  const page = await api("POST", "/pages", {
    parent: { database_id: KANBAN_DB },
    properties: { Name: { title: [{ text: { content: name } }] }, Status: { status: { name: status } } },
  });
  if (file) await appendBlocks(page.id, mdToBlocks(readSource(file)));
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

// ---------- Markdown → bloky ----------
const LANGS = new Set(["gherkin", "java", "javascript", "typescript", "json", "sql", "shell", "bash", "markdown", "xml", "html", "css", "python", "yaml", "mermaid"]);

function inline(text) {
  const out = [];
  const re = /(\*\*[^*]+\*\*|`[^`]+`|\[[^\]]+\]\([^)]+\)|_[^_\s][^_]*_)/g;
  let last = 0, m;
  const push = (content, ann = {}, link) => {
    for (let i = 0; i < content.length; i += 2000) {
      out.push({ type: "text", text: { content: content.slice(i, i + 2000), ...(link ? { link: { url: link } } : {}) }, annotations: ann });
    }
  };
  while ((m = re.exec(text))) {
    if (m.index > last) push(text.slice(last, m.index));
    const t = m[0];
    if (t.startsWith("**")) push(t.slice(2, -2), { bold: true });
    else if (t.startsWith("`")) push(t.slice(1, -1), { code: true });
    else if (t.startsWith("[")) { const [, l, u] = t.match(/\[([^\]]+)\]\(([^)]+)\)/); /^https?:/.test(u) ? push(l, {}, u) : push(l); }
    else push(t.slice(1, -1), { italic: true });
    last = m.index + t.length;
  }
  if (last < text.length) push(text.slice(last));
  return out;
}

const blk = (type, text, extra = {}) => ({ object: "block", type, [type]: { rich_text: inline(text), ...extra } });

function mdToBlocks(md) {
  const lines = md.replace(/\r/g, "").split("\n");
  const blocks = [];
  let i = 0;
  const lastList = [];
  while (i < lines.length) {
    const line = lines[i];
    const fence = line.match(/^```\s*([\w+-]*)/);
    if (fence) {
      const body = [];
      i++;
      while (i < lines.length && !/^```/.test(lines[i])) body.push(lines[i++]);
      i++;
      const lang = LANGS.has(fence[1]) ? fence[1] : "plain text";
      const content = body.join("\n");
      blocks.push({ object: "block", type: "code", code: { language: lang, rich_text: chunks(content) } });
      continue;
    }
    if (/^\s*\|.*\|\s*$/.test(line)) {
      const rows = [];
      while (i < lines.length && /^\s*\|.*\|\s*$/.test(lines[i])) rows.push(lines[i++]);
      const cells = rows.filter((r) => !/^\s*\|[\s:|-]+\|\s*$/.test(r))
        .map((r) => r.trim().slice(1, -1).split(/(?<!\\)\|/).map((c) => c.trim().replace(/\\\|/g, "|")));
      const width = Math.max(...cells.map((c) => c.length));
      blocks.push({ object: "block", type: "table", table: {
        table_width: width, has_column_header: rows.length > 1 && /^\s*\|[\s:|-]+\|\s*$/.test(rows[1]), has_row_header: false,
        children: cells.map((c) => ({ object: "block", type: "table_row", table_row: { cells: Array.from({ length: width }, (_, k) => inline(c[k] ?? "")) } })),
      } });
      continue;
    }
    i++;
    if (!line.trim()) { lastList.length = 0; continue; }
    let m;
    if ((m = line.match(/^(#{1,3})\s+(.*)/))) { blocks.push(blk(`heading_${m[1].length}`, m[2])); continue; }
    if (/^(-{3,}|\*{3,})\s*$/.test(line)) { blocks.push({ object: "block", type: "divider", divider: {} }); continue; }
    if ((m = line.match(/^>\s?(.*)/))) { blocks.push(blk("quote", m[1])); continue; }
    if ((m = line.match(/^(\s*)(?:[-*]\s+\[([ xX])\]\s+(.*))$/))) { list(m[1], blk("to_do", m[3], { checked: m[2] !== " " })); continue; }
    if ((m = line.match(/^(\s*)[-*]\s+(.*)/))) { list(m[1], blk("bulleted_list_item", m[2])); continue; }
    if ((m = line.match(/^(\s*)\d+[.)]\s+(.*)/))) { list(m[1], blk("numbered_list_item", m[2])); continue; }
    blocks.push(blk("paragraph", line.trim()));
    lastList.length = 0;
  }
  return blocks;

  function chunks(s) {
    const r = [];
    for (let k = 0; k < s.length; k += 2000) r.push({ type: "text", text: { content: s.slice(k, k + 2000) } });
    return r;
  }
  function list(indent, b) {
    const level = Math.min(1, Math.floor(indent.replace(/\t/g, "  ").length / 2));
    if (level > 0 && lastList[0]) {
      const parent = lastList[0][lastList[0].type];
      (parent.children ||= []).push(b);
    } else {
      blocks.push(b);
      lastList[0] = b;
    }
  }
}

async function appendBlocks(pageId, blocks) {
  for (let k = 0; k < blocks.length; k += 100) {
    await api("PATCH", `/blocks/${pageId}/children`, { children: blocks.slice(k, k + 100) });
  }
}

function readSource(src) {
  if (!src) die("Chybí zdroj obsahu: cesta k .md souboru nebo - pro stdin.");
  return src === "-" ? readFileSync(0, "utf8") : readFileSync(src, "utf8");
}

async function resolvePage(ref) {
  return toId(ref) || (await resolveCard(ref));
}

async function cmdWrite(ref, src, append, json) {
  const id = await resolvePage(ref);
  const blocks = mdToBlocks(readSource(src));
  let removed = 0;
  if (!append) {
    const old = await paginate("GET", `/blocks/${id}/children`);
    for (const b of old) {
      if (["child_page", "child_database"].includes(b.type)) continue; // podstránky (review, retro) zůstávají
      await api("DELETE", `/blocks/${b.id}`);
      removed++;
    }
  }
  await appendBlocks(id, blocks);
  console.log(json ? JSON.stringify({ id, removed, added: blocks.length }) : `Zapsáno do ${id}: ${blocks.length} bloků${append ? " (připojeno)" : `, ${removed} starých nahrazeno`}.`);
}

async function cmdSubpage(ref, name, src, json) {
  if (!name) die("Chybí název podstránky.");
  const parent = await resolvePage(ref);
  const blocks = src ? mdToBlocks(readSource(src)) : [];
  const page = await api("POST", "/pages", {
    parent: { page_id: parent },
    properties: { title: { title: [{ text: { content: name } }] } },
    children: blocks.slice(0, 100),
  });
  if (blocks.length > 100) await appendBlocks(page.id, blocks.slice(100));
  console.log(json ? JSON.stringify(page, null, 2) : `Podstránka „${name}“ id ${page.id.replace(/-/g, "")} (${blocks.length} bloků).`);
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
const append = argv.includes("--append");
const opt = {};
const pos = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === "--status" || argv[i] === "--file") opt[argv[i].slice(2)] = argv[++i];
  else if (!["--json", "--append"].includes(argv[i])) pos.push(argv[i]);
}
const status = opt.status;
const [cmd, a1, a2, a3] = pos;

const commands = {
  page: () => cmdPage(a1, json),
  kanban: () => cmdKanban(status, json),
  "card-add": () => cmdCardAdd(a1, status, opt.file, json),
  write: () => cmdWrite(a1, a2, append, json),
  subpage: () => cmdSubpage(a1, a2, a3, json),
  "card-status": () => cmdCardStatus(a1, a2, json),
  comment: () => cmdComment(a1, a2, json),
  search: () => cmdSearch(a1, json),
};
if (!commands[cmd]) {
  console.log(readFileSync(fileURLToPath(import.meta.url), "utf8").split("\n").slice(1, 14).map((l) => l.replace(/^\/\/ ?/, "")).join("\n"));
  process.exit(cmd ? 1 : 0);
}
await commands[cmd]();
