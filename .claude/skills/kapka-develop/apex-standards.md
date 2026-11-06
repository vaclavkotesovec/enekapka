# Apex standardy – Kapka Klub

Čte je `/kapka-develop` při psaní a `/kapka-review` při kontrole. Pravidla platformy ověřuj v oficiální dokumentaci Salesforce, ne z paměti.

## Doménová pravidla (nepřekročitelná)

- **Kniha kapek je neměnná.** `Points_Transaction__c` se nikdy nemaže a nemění se jí `Points__c`, `Type__c` ani datum. Smí se měnit jen `Status__c` (Pending → Posted / Cancelled). Oprava = nová transakce (Reversal, Adjustment s `Reason__c`).
- **Čerpání a expirace jen FIFO přes `Points_Allocation__c`**, seřazeno podle `Expiration_Date__c`. Před alokací zamkni člena `SELECT … FOR UPDATE`.
- **Jedna Earn transakce na Order**, ne na řádek. `Receipt_Number__c` je External ID a brání duplicitám.
- **Pravidla jsou data:** počty kapek a kampaně z `Earning_Rule__c` s platností od–do, nic natvrdo v kódu.
- Názvy: API anglicky (`Points__c`), UI labely česky podle brand kitu (Kapky, Člen, Transakce, Kampaň, Odměna, Voucher).

## Platforma

- `with sharing` jako výchozí; výjimku zdůvodni komentářem.
- Bulkifikace: žádné SOQL ani DML v cyklech, Set/Map, jeden dotaz na dávku.
- Trigger bez logiky: jeden trigger na objekt, logika v handleru nebo službě.
- CRUD/FLS: `WITH USER_MODE` v dotazech, `Security.stripInaccessible` před vrácením dat do UI.
- Async: Batch pro expiraci, Queueable pro navazující zpracování; respektuj governor limity.
- Uživatelské texty do Custom Labels, ne natvrdo.
- Citlivá data (souhlasy, kontakty) nelogovat ani neposílat v chybových hláškách.

## Pojmenování a styl

- Třídy PascalCase, metody camelCase, konstanty UPPER_SNAKE_CASE, testy končí `Test`, invocable třídy `Action`.
- Malé metody s jednou odpovědností, vlastní výjimky se smysluplnou zprávou, nejmenší nutná viditelnost.
- Žádná magická čísla: koeficienty a limity jako konstanty nebo data.
- Metadata `*-meta.xml` s nejnovější API verzí projektu.
