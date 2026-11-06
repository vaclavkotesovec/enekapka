# Formát akceptačních kritérií – Kapka Klub

Píše se pro business čtenáře (loyalty manažer, tester, porota). Žádné Apex třídy, API názvy polí ani SOQL. Každé kritérium musí jít dohledat ke zdroji v Notion.

## Struktura `spec.md`

````markdown
# Specifikace – <id> (<jednořádkový popis>)

**Zdroj:** Notion Zadání / Značka / karta Kanbanu. **Jazyk:** CS.

## Akceptační kritéria

```gherkin
# language: cs
Požadavek: <business schopnost>
  Jako <persona>
  chci <schopnost>
  abych <hodnota>

  Pravidlo: AC-1 — <pravidlo jednou větou>

    Scénář: AC-1.1 — <šťastná cesta>
      Pokud <kontext>
      Když <jedna akce>
      Pak <pozorovatelný výsledek>
```

## Mimo rozsah

| Vyřazeno | Důvod |
| --- | --- |

## Otevřené otázky

1. <mezera nebo nejasnost, s AC, kterého se týká>
````

- `Kontext` (Background) jen když ho sdílí 2+ scénáře pravidla.
- `Náčrt Scénáře` + `Příklady` jen když je smyslem pravidla variace dat.
- Data se 2+ poli dávej do tabulky v `Pokud`.

## Persony

Člen Kapka Klubu (demo: Jana Nováková), Loyalty manažer, Pokladna (systém), Zákaznická podpora. Jiné persony nevymýšlej; chybějící dej do Otevřených otázek.

## Příklad

```gherkin
# language: cs
Požadavek: Připsání kapek za nákup
  Jako člen Kapka Klubu
  chci dostat kapky za tankování a nákup v obchodě
  abych je mohl vyměnit za odměnu

  Pravidlo: AC-1 — Za každý celý litr paliva dostane člen jednu kapku

    Scénář: AC-1.1 — Tankování s kartou
      Pokud člen načte kartu u pokladny
      A natankuje 45,6 l paliva
      Když se nákup zaúčtuje
      Pak má člen připsáno 45 kapek

    Scénář: AC-1.2 — Nákup bez karty
      Pokud zákazník nenačte kartu
      Když se nákup zaúčtuje
      Pak se žádné kapky nepřipíšou
```
