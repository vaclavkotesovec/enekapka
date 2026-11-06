---
name: kapka-develop
description: "ADLC fáze 3 – vývoj Kapka Klubu v Salesforce podle plánu z karty v Notion Kanbanu: řez po řezu test-first, deploy do default orgu, běh testů a oprava, pak předání do review. Použij, když se má implementovat karta z Kanbanu."
argument-hint: "Karta v Kanbanu, např. \"earn-kapky:\""
---

# Kapka – fáze 3: vývoj

Plán v kartě je zdroj pravdy; byl odsouhlasen ve `/kapka-spec`, takže ho implementuj, ne znovu grilluj. Ptej se jen, když si plán odporuje, když realita (org, platforma) neodpovídá plánu, nebo když mlčí o rozhodnutí, které mění pozorovatelné chování. V repu vzniká jen kód a metadata; plán a stav žijí v Notion (`/notion-api`).

Každá smyčka je **úzká**: nasazuješ jen soubory karty a pouštíš jen testovací třídy karty. Celý `force-app` ani `RunLocalTests` se během karty nepouští.

## Vstup

Karta v Kanbanu ve stavu **Business ready** (`node scripts/notion.mjs page "<id>:"`). Když nemá sekci Plán nebo je ve stavu Not started, pošli uživatele na `/kapka-spec` a skonči.

## Postup

1. **Start jedním tahem:** `bash scripts/git-sync.sh`, `node scripts/notion.mjs card-start "<id>:" "<tvé jméno>" --dev`, načti kartu a [apex-standards.md](apex-standards.md), zapiš si základ `git rev-parse HEAD` pro review. Todo list z řezů karty v jejich pořadí.
2. **Řez po řezu** podle `/kapka-tdd`. Platform skilly (`/platform-custom-object-generate`, `-custom-field-`, `-validation-rule-`, `-permission-set-`, `/platform-soql-query`) načti jen u prvního řezu, který daný typ metadat mění.
   - **Red:** nasaď test a pusť ho. Když test nejde zkompilovat, protože třída nebo pole ještě neexistuje, je chyba deploye ten red – přidej rovnou minimální kód a jdi na green.
   - **Green:** nasaď soubory řezu a pusť testy karty:
     ```bash
     sf project deploy start --source-dir <soubory řezu> --wait 10
     bash scripts/apex-test.sh <TestyKarty…>   # po třídách, sám opakuje při zahlcené frontě orgu
     ```
   - Stejná chyba po třech různých pokusech → stop a reportuj s důkazy.
3. **Po zeleném řezu** naráz: `node scripts/notion.mjs card-check "<id>:" "R<n>"`, `bash scripts/git-sync.sh`, commit `feat(<id>): R<n> <co>` a push.
4. **Akceptace automaticky:** `node scripts/accept-apex.mjs "<id>:" <TestovacíTřída>` (každý test má nad sebou `// AC-x.y`); zapíše výsledky scénářů do databáze Testy, selhání založí bug kartu. Nic ručně.
5. **Po posledním řezu:** spusť `/kapka-review "<id>:" <základ>` jako subagent na pozadí. Opravy 🔴 a 🟠 udělej hned (test-first, řez `R<n> (review)` připiš do karty přes `write "<id>:" … --append`); 🟡 a ⚪ zůstanou v reportu pro uživatele. Kolo review je jedno; druhé jen když oprava změnila chování.
5. **Předej k akceptaci a pusť kartu z ruky:** `card-assign "<id>:" "<analytik karty>"` (stav zůstává In progress, akceptuje analytik) a do komentáře karty (`comment`) napiš výsledek testů, commity a demo krok (Jana, Kapka Brno – Vídeňská, 45 l + 180 Kč = +109 kapek). Analytik akceptuje ručně podle scénářů a kartu zavře `card-status "<id>:" Done`; selhaný scénář = nová karta `bug: <karta> AC-x.y` (Rozhodnutí TT4). Ty bereš další kartu.

## Report

Změněné soubory, commity, stav deploye a testů, hotové řezy, nálezy review (opravené / ponechané), komu je karta předána.
