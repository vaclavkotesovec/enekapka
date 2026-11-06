---
name: kapka-tdd
description: "ADLC fáze 2 – test driven development pro Kapka Klub (Apex). Pravidla red → green, kde leží seamy, co je dobrý test a standardy Apex testů. Použij při návrhu testů ve /kapka-spec, před každým řezem ve /kapka-develop a při review testů."
---

# Kapka – fáze 2: TDD

TDD je smyčka red → green. Tahle stránka říká, jak z ní dostat testy, které stojí za to nechat. Platí v každém cyklu, ne až na konci.

## Seamy

**Seam** je veřejná hranice, na které pozoruješ chování bez sahání dovnitř. Testy žijí jen na seamech schválených v Plánu karty v Notion (`node scripts/notion.mjs page "<id>:"`). Potřebuješ seam, který plán nemá? Zeptej se uživatele.

Typické seamy Kapky:

| Seam | Chytí | Mine |
| --- | --- | --- |
| Trigger na `Order` (vložení objednávky s členem) | výpočet kapek end-to-end přes platformu | UI, pokladní API |
| Veřejná služba čerpání (rezervace, potvrzení, zrušení) | FIFO alokaci, zámky, stavy Pending/Posted/Cancelled | souběh dvou pokladen naostro |
| Batch expirace | Expire transakce a alokace, `Points_Expiring_Next_30_Days__c` | plánování v čase |
| Roll-up zůstatku na `Loyalty_Member__c` | součet z knihy pohybů | — |

Když je sporný samotný tvar rozhraní, použij `/codebase-design`.

## Dobrý test

- Ověřuje chování přes veřejné rozhraní a přežije refaktoring. Příklady v [tests.md](tests.md), mockování jen na hranicích systému v [mocking.md](mocking.md).
- Očekávaná hodnota pochází z nezávislého zdroje: příklad z AC nebo brand kitu (45 l + 180 Kč = 109 kapek), ne přepočet stejnou logikou.
- Jméno říká CO, ne JAK: `memberGets45KapkyFor45LitersOfFuel`.

## Anti-vzory

- **Svázaný s implementací:** testuje privátní metody nebo mockuje vlastní třídy.
- **Tautologický:** očekávanou hodnotu počítá stejně jako kód.
- **Horizontální řezy:** všechny testy napřed, pak všechen kód. Pracuj vertikálně: jeden test → jedna implementace.

## Pravidla smyčky

- **Red před green.** Nejdřív padající test (a ověř, že padá ze správného důvodu), pak jen tolik kódu, aby prošel.
- **Jeden řez naráz.** Jeden seam, jeden test, jedna minimální implementace.
- **Refaktoring nepatří do smyčky**, patří do `/kapka-review`.

## Standardy Apex testů

- `@IsTest`, `SeeAllData=false`, deterministické. Testovací data přes jednu třídu `KapkaTestDataFactory`, ne ručně v každém testu.
- Struktura Pokud / Když / Pak (Given / When / Then) a jedna logická aserce na test; `Test.startTest()/stopTest()` jen kolem akce, hlavně u batchů a async.
- Pokrývej pozitivní i negativní cesty a hranice (0 kapek, nedostatečný zůstatek, storno po čerpání, souběh).
- Bulk: aspoň jeden test na 200 záznamů pro každý trigger.
- Opakované literály (> 2×) do `private static final` konstant.
- Pokrytí: cíl 100 % řádků nové logiky, minimum 85 %.
- Testy běží proti default orgu: `sf apex run test --class-names <Trida>Test --result-format human --wait 10`.
