# Kapka Klub – věrnostní program čerpacích stanic na Salesforce

AI Hackathon 6. 11. 2026, tým 2. Body se jmenují **kapky** (1 litr = 1 kapka = 1 bod).

## Kde co je

- **Notion je znalostní báze:** zadání, datový model, značka, specifikace, plány, review a retro. Jen přes `/notion-api` (`node scripts/notion.mjs`).
- **Repo nese jen skilly a kód.** Dokumenty do repa necommituj; koncepty patří do `.work/` (gitignored) a publikují se do Notion.
- Apex a doménová pravidla knihy kapek: `.claude/skills/kapka-develop/apex-standards.md`. Salesforce metadata: `/platform-*` skilly.

## Práce v týmu – vždy

Na repu i v Notion pracuje víc lidí najednou. Aby se nic nedělalo dvakrát:
- **Na začátku každé karty, před každým commitem a před pushem** spusť `bash scripts/git-sync.sh` (na startu session ho spouští hook sám). Když hlásí POZOR, nejdřív srovnej větev (`git pull --rebase`), pak pokračuj.
- **Než si vezmeš kartu**, přečti ji znovu v Notion (`node scripts/notion.mjs page "<id>:"`) a ověř stav a Řešitele; kartu In progress někoho jiného nezačínej.
- Commituj a pushuj po malých kusech (po řezu), ať ostatní vidí rozdělanou práci.

## ADLC – každá funkce = jedna karta v Kanbanu, fáze v pořadí

1. `/kapka-spec` (analytici Jakub, Veronika): Specifikace (AC v Gherkinu) a Plán s řezy do těla karty `<id>: <název>` → stav Business ready, Řešitel = vývojář (Jan, Václav) podle `page rozhodnuti`.
2. `/kapka-tdd`: pravidla red → green a standardy Apex testů; platí v každém řezu.
3. `/kapka-develop`: implementace řez po řezu, deploy, testy; hotové řezy odškrtává v kartě.
4. `/kapka-review`: review ve dvou osách (Spec, Standardy) → podstránka karty „Review …“.
5. `/kapka-retro`: zlepšení skillů a znalostí → podstránka karty „Retro …“.

Bez schváleného Plánu v kartě se nepíše kód.
