---
name: kapka-develop
description: "ADLC fáze 3 – vývoj Kapka Klubu v Salesforce podle plánu z karty v Notion Kanbanu: řez po řezu test-first, deploy do default orgu, běh testů a oprava, pak předání do review. Použij, když se má implementovat karta z Kanbanu."
argument-hint: "Karta v Kanbanu, např. \"earn-kapky:\""
---

# Kapka – fáze 3: vývoj

Plán v kartě je zdroj pravdy; byl odsouhlasen ve `/kapka-spec`, takže ho implementuj, ne znovu grilluj. Ptej se jen, když si plán odporuje, když realita (org, platforma) neodpovídá plánu, nebo když mlčí o rozhodnutí, které mění pozorovatelné chování. V repu vzniká jen kód a metadata; plán a stav žijí v Notion (`/notion-api`).

## Vstup

Karta v Kanbanu ve stavu **Business ready** (`node scripts/notion.mjs page "<id>:"`). Když nemá sekci Plán nebo je ve stavu Not started, pošli uživatele na `/kapka-spec` a skonči.

## Postup

1. **Načti kartu** celou a [apex-standards.md](apex-standards.md). Hotovo, když má každé AC řez s testem.
2. **Začni hned In progress:** `node scripts/notion.mjs card-status "<id>:" "In progress"` a `card-assign "<id>:" "<tvé jméno>"` dřív, než napíšeš první řádek. Todo list z řezů karty v jejich pořadí.
3. **Implementuj řez po řezu** podle `/kapka-tdd`: padající test, ověř, že padá; minimální kód; zelená. Na metadata použij platform skilly:
   - objekty `/platform-custom-object-generate`, pole `/platform-custom-field-generate`, validace `/platform-validation-rule-generate`, oprávnění `/platform-permission-set-generate`, dotazy `/platform-soql-query`.
4. **Validuj a opravuj**, dokud není *zeleno*:
   - deploy: `sf project deploy start --source-dir force-app` (do default orgu; když není nastavený, zeptej se);
   - testy: `sf apex run test --test-level RunLocalTests --result-format human --code-coverage --wait 20`;
   - oprav každou chybu a pusť znovu. Stejná chyba po třech různých pokusech → stop a reportuj s důkazy.
   *Zeleno* = deploy prošel a všechny relevantní testy prošly.
5. **Zapiš postup do karty:** po každém zeleném řezu zaškrtni jeho `- [x]` v Plánu. Stáhni kartu (`page "<id>:" > .work/<id>/karta.md`), smaž z exportu první nadpis, řádek `_id … · upraveno …_` a řádky podstránek `- 📄 …`, uprav a publikuj `write "<id>:" .work/<id>/karta.md`.
6. **Necommituj.** Commity jsou na uživateli.
7. **Předej do review:** spusť `/kapka-review "<id>:"` (ideálně jako subagent bez tvého kontextu). Nálezy ukaž podle závažnosti, nech uživatele vybrat, co opravit; schválené opravy nejdřív připiš do Plánu v kartě jako nové řezy, pak je udělej test-first a znovu krok 4.
8. **Ruční test:** požádej uživatele o ověření v orgu (demo: Jana, Kapka Brno – Vídeňská, 45 l + 180 Kč = +109 kapek). Každý nález → nejdřív řez do karty, pak test-first oprava.
9. **Akceptace:** zapiš výsledek Apex testů do databáze Testy a požádej analytika karty (Jakub / Veronika) o ruční akceptaci podle scénářů karty. Selhaný scénář = nová karta `bug: <karta> AC-x.y` (Rozhodnutí TT4).
10. **Zavři:** až po zeleném review a zelené akceptaci `card-status "<id>:" Done` a navrhni `/kapka-retro "<id>:"`.

## Report

Při každé zastávce: změněné soubory, stav deploye a testů, hotové řezy, kola review, stav ručního testu, co zůstává otevřené. Krok označ jako hotový, jen když opravdu proběhl.
