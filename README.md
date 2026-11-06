# Kapka Klub – věrnostní program čerpacích stanic na Salesforce

AI Hackathon 6. 11. 2026 · tým 2 · Enehano × Kapka. Body se jmenují **kapky**: 1 litr = 1 kapka.

Za jeden den jsme postavili funkční věrnostní program v reálném Salesforce orgu. Nevznikl promptováním naslepo, ale řízeným procesem, ve kterém AI agenti pracují podle stejných pravidel jako tým. Tento README vysvětluje, **co jsme postavili, proč takhle a kde to v repu najdete**.

## Co funguje (ověřeno v orgu)

Demo scénář: Jana natankuje 45 l na stanici Kapka Brno – Vídeňská a koupí kávu se sušenkou za 180 Kč.

| Krok | Co se stane | Kapky |
| --- | --- | --- |
| Nákup (Order → Completed) | trigger spočítá základ 45 + 9 a kampaně „Natankuj plnou“ +50 a „Zastávka na cestě“ +5 | **+109** |
| Marketingový souhlas | aktivita v profilu člena | +50 |
| Voucher na přezutí | FIFO odečet z nejdřív expirujících kapek, kód `KPK-XXXX-XXXX` | −500 |
| Noční batch | kapky starší než 12 měsíců propadnou jako dohledatelný pohyb | |

Generálka dema prošla v orgu v 15:20: zůstatek 509 → 618 → 668 → 168.

Funkce podle karet: základní kapky za nákup, kampaně jako konfigurace, kapky za profil a souhlas, expirace po roce, uplatnění voucheru, ruční úprava kapek s důvodem, back-office aplikace pro loyalty manažera, Experience Cloud portál člena v brandu Kapka, připomínky (kapky na dosah, winback).

## Proč takhle – klíčová rozhodnutí

### 1. Kniha kapek místo čísla na členovi
Každý pohyb je záznam `Points_Transaction__c` (Earn, Redeem, Expire, Adjust). Pohyb se nikdy nemaže, mění se jen jeho stav. Čerpání zapisuje `Points_Allocation__c`, ze kterých balíčků kapky ubyly.
**Proč:** věrnostní body jsou pro firmu závazek. Každou kapku jde dohledat k nákupu, kampani nebo voucheru, expirace přesně ví, co propadá, a reklamace se dá vyřešit z dat, ne odhadem. Permission set back-office záměrně nemá Delete na pohybech.

### 2. Kampaně jsou konfigurace, ne kód
`Loyalty_Campaign__c` (pevné kapky, násobek základu, minimální litry nebo částka, platnost od–do) vyhodnocuje `KapkaCampaignEvaluator`. Uplatněné kampaně se zapisují do `Applied_Campaign__c`.
**Proč:** marketing spustí novou kampaň bez vývojáře a bez deploye (test `newCampaignWorksWithoutCode`). Validační pravidla hlídají, že kampaň nedá necelé kapky a násobek je vždy větší než 1.

### 3. Jedna služba čerpání pro portál i back-office
`KapkaRedeemService.redeem(memberId, rewardId)`: zámek `FOR UPDATE` na členovi, FIFO podle expirace, vše v jedné transakci s rollbackem a hlášky v Custom Labels.
**Proč:** nedojde k dvojímu utracení, logika je na jednom místě a portál jen dodá přihlášeného člena (`KapkaPortalRedeemController`). Kódy voucherů jsou bez znaků 0, O, 1, I a L, takže se dají nadiktovat po telefonu.

### 4. Bulk-safe od prvního řezu
Každá karta má bulk test na 200 záznamů (nákupy, souhlasy, expirace členů).
**Proč:** 120 stanic a dávkové importy nákupů. Trigger, který projde s jedním záznamem a spadne na 200, je v Salesforce nejčastější produkční chyba.

## Jak jsme pracovali – AI s mantinely

### ADLC: pět fází, pět skillů (`.claude/skills/kapka-*`)
1. **`/kapka-spec`**: zadání z Notion převede na akceptační kritéria v Gherkinu, testovací seamy a plán v řezech. **Bez schváleného plánu se nepíše kód.**
2. **`/kapka-tdd`**: nejdřív červený test, pak minimální kód.
3. **`/kapka-develop`**: implementace řez po řezu, úzký deploy jen souborů karty a commit a push po každém zeleném řezu.
4. **`/kapka-review`**: nezávislý subagent kontroluje kód ve dvou osách (Spec a Standardy), nálezy 🔴 a 🟠 se opravují hned. V gitu je vidět, že review našlo skutečné chyby: `fix(earn-kampane): R8 (review T1)`, opravy expirace.
5. **`/kapka-retro`**: zlepšení skillů po kartě, takže další karta jde rychleji.

**Proč:** agent bez mantinelů vymýšlí datový model a „hotovo“ hlásí bez důkazu. U nás je hotovo až po zelených testech proti AC. Commit history tak odpovídá plánu v kartě, `feat(<karta>): R<n> <co>`.

### Notion jako jediný zdroj pravdy
Zadání, datový model, značka, Kanban a review žijí v Notion. Agent je čte i zapisuje přes `scripts/notion.mjs` (vlastní REST klient bez závislostí). Kanban v každé chvíli ukazuje, kdo na čem dělá, a karta jde do In progress hned při startu.

### Čtyři lidé a víc AI sessions nad jedním orgem
Sdílený org je největší riziko týmové práce na Salesforce: deploy celého `force-app` přepíše cizí práci. Proto to hlídají automatické kontroly, ne jen dobrá vůle:
- `scripts/git-sync.sh`: hook na startu session a před každou kartou upozorní, když je větev pozadu.
- `scripts/guard-deploy.sh`: hook zablokuje deploy celého `force-app`, deploy přes manifest i deploy z větve, která je pozadu za `origin`.
- `scripts/apex-test.sh`: testy po třídách s opakováním při zahlcené frontě orgu.
- `scripts/check-brand.mjs`: kontrola, že LWC nepoužívají natvrdo hex barvy mimo tokeny brandu.

Jedna session orchestruje, rozdává karty sessions a subagentům, sbírá stav a hlídá termín.

## Kde co najdete

| Co | Kde |
| --- | --- |
| Apex služby a triggery | `force-app/main/default/classes`, `triggers` |
| Datový model (objekty, pole, validace) | `force-app/main/default/objects` |
| Portál a brand (LWC, CSS tokeny, logo) | `force-app/main/default/lwc`, `staticresources` |
| ADLC skilly a Apex standardy | `.claude/skills/kapka-*`, `.claude/skills/kapka-develop/apex-standards.md` |
| Týmové hooky a skripty | `scripts/`, `.claude/settings.json` |
| Pravidla pro agenta | `CLAUDE.md` |

## Spuštění

```bash
sf project deploy start --source-dir force-app/main/default/classes/<Třída>.cls --wait 10   # vždy úzce
bash scripts/apex-test.sh KapkaEarnServiceTest KapkaRedeemServiceTest
sf apex run --file scripts/run-expiration.apex   # expirace ručně
```
