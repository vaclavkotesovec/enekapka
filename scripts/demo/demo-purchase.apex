// Demo (karta demo, R1): Jana natankuje na Kapka Brno – Vídeňská 45 l za 1 710 Kč a koupí kávu se sušenkou za 180 Kč.
// Očekávání: +109 kapek (54 základ + 5 Zastávka na cestě + 50 Natankuj plnou).
// Spuštění: sf apex run --file scripts/demo/demo-purchase.apex --target-org kapka
final String JANA = 'Jana Nováková';
final String STATION_CODE = 'KPK-001';
final String FUEL = 'Natural 95';
final String SHOP = 'Káva a sušenka';

List<Loyalty_Member__c> members = [SELECT Id, Account__c FROM Loyalty_Member__c WHERE Account__r.Name = :JANA LIMIT 1];
if (members.isEmpty()) {
    throw new IllegalArgumentException('V orgu chybí členka ' + JANA + ' – nejdřív spusť demo data (karta test-data).');
}
List<Fuel_Station__c> stations = [SELECT Id FROM Fuel_Station__c WHERE Station_Code__c = :STATION_CODE LIMIT 1];
if (stations.isEmpty()) {
    throw new IllegalArgumentException('V orgu chybí stanice ' + STATION_CODE + ' – nejdřív spusť demo data (karta test-data).');
}

// Produkty dema (cena na Product2, Q10): doplní se, jen když chybí.
Map<String, Product2> products = new Map<String, Product2>();
for (Product2 p : [SELECT Id, Name FROM Product2 WHERE Name IN (:FUEL, :SHOP)]) {
    products.put(p.Name, p);
}
List<Product2> missing = new List<Product2>();
if (!products.containsKey(FUEL)) {
    missing.add(new Product2(Name = FUEL, Family = 'Fuel', Price__c = 38, IsActive = true));
}
if (!products.containsKey(SHOP)) {
    missing.add(new Product2(Name = SHOP, Family = 'Other', Price__c = 180, IsActive = true));
}
insert missing;
for (Product2 p : missing) {
    products.put(p.Name, p);
}

Order__c purchase = new Order__c(
    Loyalty_Member__c = members[0].Id,
    Account__c = members[0].Account__c,
    Fuel_Station__c = stations[0].Id,
    Receipt_Number__c = STATION_CODE + '-' + Datetime.now().format('yyyyMMddHHmmss'),
    Purchase_Date__c = Datetime.now()
);
insert purchase;
insert new List<Order_Item__c>{
    new Order_Item__c(Order__c = purchase.Id, Product__c = products.get(FUEL).Id, Quantity__c = 45),
    new Order_Item__c(Order__c = purchase.Id, Product__c = products.get(SHOP).Id, Quantity__c = 1)
};
purchase.Status__c = 'Completed';
update purchase;

Points_Transaction__c earn = [
    SELECT Points__c, Base_Points__c, Campaign_Points__c
    FROM Points_Transaction__c
    WHERE Order__c = :purchase.Id AND Type__c = 'Earn'
    LIMIT 1
];
System.debug(LoggingLevel.WARN, 'DEMO nákup ' + purchase.Receipt_Number__c + ': +' + earn.Points__c + ' kapek (základ ' + earn.Base_Points__c + ', kampaně ' + earn.Campaign_Points__c + ')');
