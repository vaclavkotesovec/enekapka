# Kapka Klub – věrnostní program čerpacích stanic na Salesforce

AI Hackathon 6. 11. 2026, tým 2. Body se jmenují **kapky** (1 litr = 1 kapka = 1 bod).

## ADLC – každá karta jde těmito fázemi v pořadí

1. `/kapka-spec`: zadání z Notion → `.work/<id>/spec.md` (AC v Gherkinu) + `plan.md` + karty v Kanbanu.
2. `/kapka-tdd`: pravidla red → green a standardy Apex testů; platí v každém řezu.
3. `/kapka-develop`: implementace plánu řez po řezu, deploy, testy.
4. `/kapka-review`: review ve dvou osách (Spec, Standardy) → `.work/<id>/review-*.md`.
5. `/kapka-retro`: zlepšení skillů a specifikace → `.work/<id>/retro-*.md`.

Bez schváleného `plan.md` se nepíše kód. Plán je jediný zdroj pravdy pro vývoj.

## Kde co je

- Notion Kapka `4103881e844c8013a1a1d7615ec0555d`: Zadání (datový model, procesy, otevřené otázky), Značka (brand kit a názvosloví), Kanban `collection://4103881e-844c-8042-bcff-000b2ffb8322`.
- Apex a doménová pravidla knihy kapek: `.claude/skills/kapka-develop/apex-standards.md`.
- Salesforce metadata: `/platform-*` skilly.
