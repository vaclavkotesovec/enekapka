// Podvržené Notion API pro testy konektoru (seam S1).
// Použití: NOTION_MOCK_STATE=<stav.json> node --import ./scripts/test/notion-mock.mjs scripts/notion.mjs …
// Stav (stránky, řádky databází a jejich bloky) žije v JSON souboru, aby přežil mezi spuštěními CLI.
// Podporuje jen volání, která konektor používá: query databáze, stránky a bloky.

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { randomUUID } from "node:crypto";

const FILE = process.env.NOTION_MOCK_STATE;
if (!FILE) throw new Error("notion-mock: chybí NOTION_MOCK_STATE");

const load = () =>
  existsSync(FILE)
    ? JSON.parse(readFileSync(FILE, "utf8"))
    : { pages: {}, log: [] };
const save = (s) => writeFileSync(FILE, JSON.stringify(s, null, 2));
const norm = (id) => (id || "").replace(/-/g, "");

const richText = (arr = []) =>
  arr.map((t) => ({
    type: "text",
    text: t.text,
    plain_text: t.text?.content ?? t.plain_text ?? "",
    annotations: t.annotations || {},
    href: t.text?.link?.url || null,
  }));

// vstupní tvar vlastnosti → výstupní tvar, jak ho vrací API
function prop(value) {
  const type = Object.keys(value).find((k) => k !== "type");
  const v = value[type];
  if (type === "title" || type === "rich_text")
    return { type, [type]: richText(v) };
  return { type, [type]: v };
}

function matches(page, filter) {
  if (!filter) return true;
  if (filter.and) return filter.and.every((f) => matches(page, f));
  const p = page.properties[filter.property];
  const [kind, cond] = Object.entries(filter).find(([k]) => k !== "property");
  if (kind === "title" || kind === "rich_text") {
    const s = (p?.[p.type] || []).map((t) => t.plain_text).join("");
    return s === cond.equals;
  }
  if (kind === "status" || kind === "select")
    return p?.[p.type]?.name === cond.equals;
  throw new Error(`notion-mock: nepodporovaný filtr ${JSON.stringify(filter)}`);
}

function block(b) {
  const v = b[b.type] || {};
  return {
    object: "block",
    id: randomUUID(),
    type: b.type,
    has_children: false,
    [b.type]: {
      ...v,
      ...(v.rich_text ? { rich_text: richText(v.rich_text) } : {}),
    },
  };
}

function newPage(s, body) {
  const id = randomUUID();
  const properties = {};
  for (const [k, v] of Object.entries(body.properties || {}))
    properties[k] = prop(v);
  const page = {
    object: "page",
    id,
    url: `https://www.notion.so/mock-${norm(id)}`,
    parent: body.parent,
    archived: false,
    properties,
    children: (body.children || []).map(block),
  };
  s.pages[norm(id)] = page;
  return page;
}

const out = ({ children, ...page }) => page;

function handle(method, path, body) {
  const s = load();
  s.log.push({ method, path });
  let m;
  let res;
  if (method === "POST" && (m = path.match(/^\/databases\/([^/]+)\/query$/))) {
    const db = norm(m[1]);
    res = {
      results: Object.values(s.pages)
        .filter((p) => !p.archived && norm(p.parent?.database_id) === db)
        .filter((p) => matches(p, body.filter))
        .map(out),
      has_more: false,
      next_cursor: null,
    };
  } else if (method === "POST" && path === "/pages") {
    res = out(newPage(s, body));
  } else if ((m = path.match(/^\/pages\/([^/?]+)$/))) {
    const page = s.pages[norm(m[1])];
    if (!page) return [404, { code: "object_not_found", message: "Not found" }];
    if (method === "PATCH") {
      for (const [k, v] of Object.entries(body.properties || {}))
        page.properties[k] = prop(v);
      if (body.archived !== undefined) page.archived = body.archived;
    }
    res = out(page);
  } else if ((m = path.match(/^\/blocks\/([^/?]+)\/children/))) {
    const page = s.pages[norm(m[1])];
    if (!page) return [404, { code: "object_not_found", message: "Not found" }];
    if (method === "PATCH") page.children.push(...body.children.map(block));
    res = { results: page.children, has_more: false, next_cursor: null };
  } else {
    throw new Error(`notion-mock: nepodporované volání ${method} ${path}`);
  }
  save(s);
  return [200, res];
}

globalThis.fetch = async (url, init = {}) => {
  const path = String(url).replace("https://api.notion.com/v1", "");
  const [status, json] = handle(
    init.method || "GET",
    path,
    init.body ? JSON.parse(init.body) : {},
  );
  return new Response(JSON.stringify(json), {
    status,
    headers: { "content-type": "application/json" },
  });
};
