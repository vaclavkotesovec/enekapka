# Kapka Klub – věrnostní program čerpacích stanic na Salesforce

AI Hackathon 6. 11. 2026, tým 2. Body se jmenují **kapky** (1 litr = 1 kapka = 1 bod).

## Kde co je

- **Notion je znalostní báze:** zadání, datový model, značka, specifikace, plány, review a retro. Jen přes `/notion-api` (`node scripts/notion.mjs`).
- **Repo nese jen skilly a kód.** Dokumenty do repa necommituj; koncepty patří do `.work/` (gitignored) a publikují se do Notion.
- Apex a doménová pravidla knihy kapek: `.claude/skills/kapka-develop/apex-standards.md`. Salesforce metadata: `/platform-*` skilly.

## Práce v týmu – vždy

Na repu i v Notion pracuje víc lidí najednou. Aby se nic nedělalo dvakrát:
- **Na začátku každé karty a před každým commitem s pushem** spusť `bash scripts/git-sync.sh` (na startu session ho spouští hook sám). Když hlásí POZOR, nejdřív srovnej větev (`git pull --rebase`), pak pokračuj.
- **Než si vezmeš kartu**, přečti ji znovu v Notion (`node scripts/notion.mjs page "<id>:"`) a ověř stav a Řešitele; kartu In progress někoho jiného nezačínej.
- **Na čem pracuješ, je In progress – hned, ne až na konci.** Jakmile začneš na kartě cokoli dělat (specifikaci i vývoj), spusť `card-start "<id>:" "<tvé jméno>"`. Když práci předáš (vývoj → analytik k akceptaci) nebo přerušíš, hned uprav Řešitele nebo stav (Business ready / Not started / Done). Kanban musí v každou chvíli ukazovat, kdo na čem dělá.
- Commituj a pushuj po malých kusech (po řezu), ať ostatní vidí rozdělanou práci.
- **Org je jeden pro celý tým.** Nasazuj jen soubory své karty (`sf project deploy start --source-dir <soubor> …`), nikdy celý `force-app` – přepsal bys cizí nasazenou práci. Před deployem `bash scripts/git-sync.sh`, po zeleném řezu hned commit a push, ať další deploy kohokoli obsahuje i tvou změnu.
- Deploy celého `force-app`, přes manifest nebo z větve pozadu za `origin` zablokuje hook `scripts/guard-deploy.sh`. Testy pouštěj přes `bash scripts/apex-test.sh <Třída…>` (po třídách, opakuje při zahlcené frontě).
- Když ti v orgu najednou spadnou dřív zelené testy, nejdřív ověř, kdo třídu přepsal (`sf data query -q "SELECT Name, LastModifiedBy.Name, LastModifiedDate FROM ApexClass WHERE Name = '<Třída>'"`), a ozvi se mu.

## ADLC – každá funkce = jedna karta v Kanbanu, fáze v pořadí

1. `/kapka-spec` (analytici Jakub, Veronika): Specifikace (AC v Gherkinu) a Plán s řezy do těla karty `<id>: <název>` → stav Business ready, Řešitel = vývojář (Jan, Václav) podle `page rozhodnuti`.
2. `/kapka-tdd`: pravidla red → green a standardy Apex testů; platí v každém řezu.
3. `/kapka-develop`: implementace řez po řezu (úzký deploy a testy jen karty), commit a push po řezu, předání analytikovi k akceptaci.
4. `/kapka-review`: review ve dvou osách (Spec, Standardy) jako subagent na pozadí → podstránka karty „Review …“; 🔴 a 🟠 opraví vývojář hned.
5. `/kapka-retro`: zlepšení skillů a znalostí na konci session → podstránka karty „Retro …“.

Bez schváleného Plánu v kartě se nepíše kód.
