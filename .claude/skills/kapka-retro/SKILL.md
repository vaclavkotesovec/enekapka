---
name: kapka-retro
description: "ADLC fáze 5 – retrospektiva po dokončení karty nebo konci session Kapka Klubu: najde zlepšení skillů, CLAUDE.md, automatických kontrol a drift mezi specifikací a kódem, nechá je schválit, zapíše schválené a vše zaznamená. Použij po /kapka-review nebo když uživatel řekne retro."
argument-hint: "Volitelně cesta k .work/<id>/plan.md"
---

# Kapka – fáze 5: retro

Zlepšuje **prostředí agenta** (skilly, CLAUDE.md, kontroly) a **specifikace**, aby další karta šla lépe. Zapisuje se jen to, co uživatel schválí; zaznamená se všechno.

## Postup

1. **Načti `/writing-for-agents`.** Každá navržená změna skillu nebo CLAUDE.md se jím řídí.
2. **Přečti session:** aktuální konverzaci, změny (`git status`, `git diff HEAD`, pokud je git), `plan.md`, `spec.md` a reporty `review-*.md`. Když session neobsahuje žádnou implementaci, zeptej se, zda retro přeskočit.
   Hotovo, když umíš pojmenovat chyby, okliky a drahé kroky session.
3. **Najdi kandidáty** v každé kategorii níže.
4. **Předlož** je seřazené podle závažnosti, s id `R1`, `R2`…, kategorií, cílovým souborem a navrženou změnou. Uživatel schválí nebo zamítne každý („vše“ platí).
5. **Zapiš** schválené do cílových souborů.
6. **Zaznamenej** všechny do `.work/<id>/retro-<timestamp>.md`: id, kategorie, cíl, změna, stav (`schváleno` / `zamítnuto`).
7. **Notion:** nabídni krátké shrnutí retra jako komentář ke kartě v Kanbanu (`node scripts/notion.mjs comment "<název karty>" "<text>"`); zapiš jen po souhlasu.
8. **Report:** cesta k záznamu, změněné soubory, počet schválených a zamítnutých.

## Kategorie

- **Navigace:** hledal agent dlouho soubor, Notion stránku nebo pravidlo? Pomohl by odkaz v CLAUDE.md nebo popisu skillu?
- **Automatické kontroly:** chytila by chybu kontrola (PMD / Code Analyzer, Prettier, test)? Mechanické pravidlo → kontrola; úsudek → standardy v `/kapka-develop` nebo `/kapka-review`.
- **Standardy:** propustilo review chybu? Přidat, upřesnit nebo smazat pravidlo.
- **Proces ADLC:** fungoval přechod spec → TDD → vývoj → review? Chyběl seam, AC nebo karta?
- **Úspora nástrojů:** drahé nebo opakované volání (Notion, deploy, testy), které jde zkrátit.
- **Ne-instrukce:** věty ve skillech, které chování agenta nemění. Smazat.
- **Drift specifikace:** odpovídá `spec.md` a Zadání v Notion tomu, co kód dělá? Nesoulad navrhni opravit ve spec nebo v Notion (Notion jen po souhlasu).

## Implementace vs. review

Vývojář nese nejvíc kontextu, reviewer dostane jen diff. Standardy proto patří tam, kde je čte review (`apex-standards.md`, `/kapka-review`), a CLAUDE.md drží jen navigační odkazy.
