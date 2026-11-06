---
name: kapka-retro
description: "ADLC fáze 5 – retrospektiva po dokončení karty nebo konci session Kapka Klubu: najde zlepšení skillů, CLAUDE.md, automatických kontrol a drift mezi znalostmi v Notion a kódem, nechá je schválit, zapíše schválené a záznam uloží jako podstránku karty. Použij po /kapka-review nebo když uživatel řekne retro."
argument-hint: "Volitelně karta v Kanbanu, např. \"earn-kapky:\""
---

# Kapka – fáze 5: retro

Zlepšuje **prostředí agenta** (skilly, CLAUDE.md, kontroly – ty jsou v repu) a **znalosti v Notion** (specifikace v kartách, Datový model), aby další karta šla lépe. Zapisuje se jen to, co uživatel schválí; zaznamená se všechno. Notion přes `/notion-api`.

## Postup

1. **Načti `/writing-for-agents`.** Každá navržená změna skillu nebo CLAUDE.md se jím řídí.
2. **Přečti session:** aktuální konverzaci, změny v kódu (`git status`, `git diff HEAD`), kartu (`page "<id>:"`) a její podstránky Review. Když session neobsahuje žádnou implementaci, zeptej se, zda retro přeskočit.
   Hotovo, když umíš pojmenovat chyby, okliky a drahé kroky session.
3. **Najdi kandidáty** v každé kategorii níže.
4. **Předlož** je seřazené podle závažnosti, s id `R1`, `R2`…, kategorií, cílem (soubor v repu, nebo Notion stránka) a navrženou změnou. Uživatel schválí nebo zamítne každý („vše“ platí).
5. **Zapiš** schválené: skilly a CLAUDE.md v repu, znalosti do Notion (`write`; sdílené stránky jako `model` vždy jen po výslovném souhlasu).
6. **Zaznamenej** všechny do `.work/<id>/retro.md` (id, kategorie, cíl, změna, stav `schváleno` / `zamítnuto`) a publikuj: `node scripts/notion.mjs subpage "<id>:" "Retro $(date +%Y-%m-%d)" .work/<id>/retro.md`. Bez karty ho dej pod stránku `kapka`.
7. **Report:** id záznamu, změněné soubory a stránky, počet schválených a zamítnutých.

## Kategorie

- **Navigace:** hledal agent dlouho soubor, Notion stránku nebo pravidlo? Pomohl by odkaz v CLAUDE.md, alias v `scripts/notion.mjs` nebo lepší popis skillu?
- **Automatické kontroly:** chytila by chybu kontrola (PMD / Code Analyzer, Prettier, test)? Mechanické pravidlo → kontrola; úsudek → `apex-standards.md` nebo `/kapka-review`.
- **Standardy:** propustilo review chybu? Přidat, upřesnit nebo smazat pravidlo.
- **Proces ADLC:** fungoval přechod spec → TDD → vývoj → review? Chyběl seam, AC nebo řez?
- **Úspora nástrojů:** drahé nebo opakované volání (Notion, deploy, testy), které jde zkrátit.
- **Ne-instrukce:** věty ve skillech, které chování agenta nemění. Smazat.
- **Drift znalostí:** odpovídá Specifikace v kartě a `page model` tomu, co kód dělá? Nesoulad navrhni opravit v Notion.

## Implementace vs. review

Vývojář nese nejvíc kontextu, reviewer dostane jen diff. Standardy proto patří tam, kde je čte review (`apex-standards.md`, `/kapka-review`), a CLAUDE.md drží jen navigační odkazy.
