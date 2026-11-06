---
name: kapka-review
description: "ADLC fáze 4 – code review Kapka Klubu ve dvou osách: Spec (splňuje změna plán a akceptační kritéria?) a Standardy (drží Apex standardy a doménová pravidla knihy kapek?). Zapíše seřazený report vedle plánu. Použij po /kapka-develop nebo když se má zkontrolovat rozpracovaná změna."
argument-hint: "Cesta k .work/<id>/plan.md"
---

# Kapka – fáze 4: review

Kontroluje a reportuje. Zapisuje jen nový soubor s reportem; nemění kód, necommituje, nedeployuje. Nejlépe běží jako subagent bez kontextu vývojáře.

## Proč dvě osy

Kód může projít jednou a spadnout na druhé: drží standardy, ale dělá něco jiného (Spec ✗), nebo dělá přesně, co se chtělo, ale porušuje pravidla (Standardy ✗). Osy reportuj odděleně, ať jedna nezakryje druhou.

## Postup

1. **Načti požadavky:** celý `plan.md` a `spec.md`. Bez plánu se zeptej na spec; když žádný není, dělej jen osu Standardy a napiš „spec není k dispozici“.
2. **Sesbírej změny** v pracovním stromu: `git diff HEAD --stat`, `git diff HEAD`, nové soubory přes `git status --porcelain --untracked-files=all` a přečti je celé. Když repo není git, porovnej se seznamem souborů v plánu. Prázdná změna → nahlas a skonči.
3. **Osa Spec:** každé AC označ Splněno / Částečně / Nesplněno / Neověřitelné s důkazem (test, soubor, řádek). Hlas chybějící požadavky, scope creep a špatně implementované požadavky; ke každému citace AC.
4. **Osa Standardy:** proti `/kapka-develop` → [apex-standards.md](../kapka-develop/apex-standards.md) a testy proti `/kapka-tdd`. Ke každému nálezu pravidlo, které porušuje. Navíc zkontroluj Fowlerovy code smelly (Duplicated Code, Feature Envy, Primitive Obsession, Speculative Generality, Shotgun Surgery…) jako úsudek, ne tvrdé porušení.
5. **Seřaď** v rámci každé osy:
   - 🔴 **Kritické:** nesplněné AC, porušení neměnnosti knihy kapek, ztráta dat, bezpečnostní díra, blokátor deploye;
   - 🟠 **Vysoké:** špatné chování v reálném případě, chybějící test pro AC, bulk nebo limity, chybějící zámek při čerpání;
   - 🟡 **Střední:** udržovatelnost, slabé testy, ošetření chyb;
   - ⚪ **Nízké:** pojmenování, čitelnost, drobné smelly.
6. **Zapiš report** do `.work/<id>/review-<timestamp>.md` (`date +%Y%m%d-%H%M%S`), každé kolo nový soubor:
   - **Shrnutí:** plán, změněné soubory, verdikt, počty nálezů podle os a závažnosti, nejhorší nález v každé ose;
   - **Akceptační kritéria:** `| AC | Verdikt | Důkaz |`;
   - **Nálezy Spec** a **Nálezy Standardy:** `| ID | Závažnost | Soubor / místo | Co je špatně a proč | Doporučení slovy, bez kódu |`;
   - **Otevřené otázky.**
7. **Report zpět:** cesta k reportu a počty nálezů podle os a závažnosti.
