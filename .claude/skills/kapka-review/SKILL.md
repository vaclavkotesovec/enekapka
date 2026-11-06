---
name: kapka-review
description: "ADLC fáze 4 – code review Kapka Klubu ve dvou osách: Spec (splňuje změna plán a akceptační kritéria z karty v Notion?) a Standardy (drží Apex standardy a doménová pravidla knihy kapek?). Report zapíše jako podstránku karty. Použij po /kapka-develop nebo když se má zkontrolovat rozpracovaná změna."
argument-hint: "Karta v Kanbanu a volitelně základní commit, např. \"earn-kapky:\" a1b2c3d"
---

# Kapka – fáze 4: review

Kontroluje a reportuje. Jediný zápis je nová podstránka karty s reportem; nemění kód, necommituje, nedeployuje. Běží jako subagent bez kontextu vývojáře. Notion přes `/notion-api`.

Kód může projít jednou osou a spadnout na druhé: drží standardy, ale dělá něco jiného (Spec ✗), nebo dělá, co se chtělo, ale porušuje pravidla (Standardy ✗). Osy reportuj odděleně.

## Postup

1. **Načti požadavky:** `node scripts/notion.mjs page "<id>:"` (Specifikace a Plán). Bez karty dělej jen osu Standardy a napiš „spec není k dispozici“.
2. **Sesbírej změny karty:** základ je zadaný commit; bez něj rodič nejstaršího commitu `git log --format=%H --grep="(<id>)" | tail -1`. Čti `git diff <základ> -- force-app` plus necommitnuté změny (`git diff HEAD`, `git status --porcelain`). Soubory mimo `force-app` jen vyjmenuj. Prázdná změna → nahlas a skonči.
3. **Osa Spec:** každé AC označ Splněno / Částečně / Nesplněno / Neověřitelné s důkazem (test, soubor, řádek). Hlas chybějící požadavky, scope creep a špatně implementované požadavky; ke každému citace AC.
4. **Osa Standardy:** proti [apex-standards.md](../kapka-develop/apex-standards.md) a testy proti `/kapka-tdd`. Ke každému nálezu pravidlo, které porušuje.
5. **Seřaď** v rámci každé osy:
   - 🔴 **Kritické:** nesplněné AC, porušení neměnnosti knihy kapek, ztráta dat, bezpečnostní díra, blokátor deploye;
   - 🟠 **Vysoké:** špatné chování v reálném případě, chybějící test pro AC, bulk nebo limity, chybějící zámek při čerpání;
   - 🟡 **Střední:** udržovatelnost, slabé testy, ošetření chyb;
   - ⚪ **Nízké:** pojmenování, čitelnost.
6. **Napiš report** do `.work/<id>/review.md` se sekcemi:
   - **Shrnutí:** verdikt, počty nálezů podle os a závažnosti;
   - **Akceptační kritéria:** `| AC | Verdikt | Důkaz |`;
   - **Nálezy Spec** a **Nálezy Standardy:** `| ID | Závažnost | Soubor / místo | Co je špatně a proč | Doporučení slovy |`; 🟡 a ⚪ jedním řádkem.
7. **Publikuj:** `node scripts/notion.mjs subpage "<id>:" "Review $(date '+%Y-%m-%d %H:%M')" .work/<id>/review.md`.
8. **Report zpět:** id podstránky a nálezy 🔴 a 🟠 celé (soubor, problém, doporučení), ostatní jen počty.
