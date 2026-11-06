// Reset dema (karta demo, R2): Jana bez nákupů, voucherů a souhlasu s marketingem, s historií 400 kapek (D2).
// Jen pro demo org! Kniha kapek se jinak nikdy nemaže (apex-standards) – reset je výjimka pro opakovatelnou generálku.
// Spuštění: sf apex run --file scripts/demo/demo-reset.apex --target-org kapka
final String JANA = 'Jana Nováková';
final Integer HISTORY_KAPKY = 400;
final Integer VALIDITY_MONTHS = 12;

List<Loyalty_Member__c> members = [
    SELECT Id, Account__c, Account__r.PersonIndividualId
    FROM Loyalty_Member__c
    WHERE Account__r.Name = :JANA
    LIMIT 1
];
if (members.isEmpty()) {
    throw new IllegalArgumentException('V orgu chybí členka ' + JANA + ' – nejdřív spusť demo data (karta test-data).');
}
Loyalty_Member__c member = members[0];

delete [SELECT Id FROM Voucher__c WHERE Loyalty_Member__c = :member.Id];
delete [SELECT Id FROM Applied_Campaign__c WHERE Points_Transaction__r.Loyalty_Member__c = :member.Id];
delete [SELECT Id FROM Points_Allocation__c WHERE Credit_Transaction__r.Loyalty_Member__c = :member.Id];
delete [SELECT Id FROM Points_Transaction__c WHERE Loyalty_Member__c = :member.Id];
delete [SELECT Id FROM Order__c WHERE Loyalty_Member__c = :member.Id];
if (member.Account__r.PersonIndividualId != null) {
    delete [SELECT Id FROM PartyConsent WHERE PartyId = :member.Account__r.PersonIndividualId AND DataUsePurpose.Name = 'Marketing'];
}

// Historie z dřívějších nákupů, aby demo skončilo voucherem: 400 + 109 + 50 ≥ 500 (Sleva 200 Kč na přezutí).
Datetime historyDate = Datetime.now().addMonths(-2);
insert new Points_Transaction__c(
    Loyalty_Member__c = member.Id,
    Type__c = 'Earn',
    Status__c = 'Posted',
    Source__c = 'Purchase',
    Points__c = HISTORY_KAPKY,
    Base_Points__c = HISTORY_KAPKY,
    Transaction_Date__c = historyDate,
    Expiration_Date__c = historyDate.date().addMonths(VALIDITY_MONTHS)
);
System.debug(LoggingLevel.WARN, 'DEMO reset: Jana má ' + HISTORY_KAPKY + ' kapek, žádné vouchery ani souhlas s marketingem.');
