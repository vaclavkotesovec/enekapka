// Seed účelů zpracování Kapka Klubu pro Party Consent (karta model-jadro, R0b / R21).
// Idempotentní: zakládá jen účely, které v orgu ještě nejsou.
// Spuštění: sf apex run --file scripts/apex/seed-data-use-purposes.apex
Map<String, String> purposes = new Map<String, String>{
    'Marketing' => 'Marketingová sdělení Kapka Klubu (e-mail, SMS, push).',
    'Loyalty' => 'Členství v Kapka Klubu: sběr a čerpání kapek, výpisy.'
};
Set<String> existing = new Set<String>();
for (DataUsePurpose purpose : [SELECT Name FROM DataUsePurpose WHERE Name IN :purposes.keySet()]) {
    existing.add(purpose.Name);
}
List<DataUsePurpose> toInsert = new List<DataUsePurpose>();
for (String name : purposes.keySet()) {
    if (!existing.contains(name)) {
        toInsert.add(new DataUsePurpose(Name = name, Description = purposes.get(name), CanDataSubjectOptOut = true));
    }
}
insert toInsert;
System.debug(LoggingLevel.INFO, 'Založeno účelů: ' + toInsert.size() + ', už existovalo: ' + existing.size());
