---
name: kapka-develop
description: "ADLC fáze 3 – vývoj Kapka Klubu v Salesforce podle schváleného plánu: řez po řezu test-first, deploy do default orgu, běh testů a oprava, pak předání do review. Použij, když se má implementovat plán z .work/<id>/plan.md nebo karta z Kanbanu."
argument-hint: "Cesta k .work/<id>/plan.md"
---

# Kapka – fáze 3: vývoj

Plán je zdroj pravdy; byl odsouhlasen ve `/kapka-spec`, takže ho implementuj, ne znovu grilluj. Ptej se jen, když si plán odporuje, když realita (org, platforma) neodpovídá plánu, nebo když mlčí o rozhodnutí, které mění pozorovatelné chování.

## Vstup

`.work/<id>/plan.md`. Když chybí, zeptej se na něj a skonči.

## Postup

1. **Načti plán** celý, `spec.md` a [apex-standards.md](apex-standards.md). Hotovo, když má každé AC naplánovanou změnu a test.
2. **Todo list** z řezů plánu v pořadí: datový model → logika → UI. Kartu v Kanbanu, na které začínáš, přepni na In progress (`node scripts/notion.mjs card-status "<název>" "In progress"`).
3. **Implementuj řez po řezu** podle `/kapka-tdd`: padající test, ověř, že padá; minimální kód; zelená. Na metadata použij platform skilly:
   - objekty `/platform-custom-object-generate`, pole `/platform-custom-field-generate`, validace `/platform-validation-rule-generate`, oprávnění `/platform-permission-set-generate`, dotazy `/platform-soql-query`.
4. **Validuj a opravuj**, dokud není *zeleno*:
   - deploy: `sf project deploy start --source-dir force-app` (do default orgu; když není nastavený, zeptej se);
   - testy: `sf apex run test --test-level RunLocalTests --result-format human --code-coverage --wait 20`;
   - oprav každou chybu a pusť znovu. Stejná chyba po třech různých pokusech → stop a reportuj s důkazy.
   *Zeleno* = deploy prošel a všechny relevantní testy prošly.
5. **Necommituj.** Commity jsou na uživateli nebo na konci `/kapka-retro`.
6. **Předej do review:** spusť `/kapka-review` s cestou k plánu (ideálně jako subagent, ať reviewer nemá tvůj kontext). Nálezy ukaž podle závažnosti, nech uživatele vybrat, co opravit, nejdřív zapiš opravy do plánu a pak je udělej test-first a znovu do kroku 4.
7. **Ruční test:** požádej uživatele o ruční ověření v orgu (demo scénář: Jana, Kapka Brno – Vídeňská, 45 l + 180 Kč = +109 kapek). Každý nález → nejdřív do plánu, pak test-first oprava.
8. **Zavři:** kartu přepni na Done (`node scripts/notion.mjs card-status "<název>" Done`) až po zeleném review a ručním testu a navrhni `/kapka-retro`.

## Report

Při každé zastávce: změněné soubory, stav deploye a testů, kola review, stav ručního testu, co zůstává otevřené. Krok označ jako hotový, jen když opravdu proběhl.
