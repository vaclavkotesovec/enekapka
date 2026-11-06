/**
 * Karta test-data: demo data jedním příkazem. Seam S1: KapkaDemoData.seed / reset volané z testu.
 * Očekávané hodnoty jsou z akceptačních kritérií karty, ne z kódu seedu.
 */
@IsTest
private class KapkaDemoDataTest {
    private static final String JANA_EMAIL = 'jana.novakova@example.com';
    private static final String ENESERVIS = 'EneServis, s.r.o.';

    // AC-1.1
    @IsTest
    static void seedCreatesHundredTwentyStations() {
        // Když se spustí seed
        Test.startTest();
        KapkaDemoData.seed(JANA_EMAIL);
        Test.stopTest();

        // Pak existuje 120 stanic KPK-001 až KPK-120 a KPK-001 se jmenuje Kapka Brno – Vídeňská
        Integer stations = [SELECT COUNT() FROM Fuel_Station__c WHERE Station_Code__c LIKE 'KPK-%'];
        List<Fuel_Station__c> first = [SELECT Name FROM Fuel_Station__c WHERE Station_Code__c = 'KPK-001'];
        List<Fuel_Station__c> last = [SELECT Name FROM Fuel_Station__c WHERE Station_Code__c = 'KPK-120'];
        Assert.areEqual(
            '120 / Kapka Brno – Vídeňská / true',
            stations + ' / ' + (first.isEmpty() ? null : first[0].Name) + ' / ' + !last.isEmpty(),
            'Seed má založit 120 stanic KPK-001 až KPK-120, první je Kapka Brno – Vídeňská.'
        );
    }

    // AC-1.2
    @IsTest
    static void seedCreatesEneServisCatalog() {
        // Když se spustí seed
        Test.startTest();
        KapkaDemoData.seed(JANA_EMAIL);
        Test.stopTest();

        // Pak jsou aktivní tři odměny partnera EneServis za 500, 1200 a 5000 kapek
        Map<String, Decimal> catalog = new Map<String, Decimal>();
        for (Reward__c reward : [
            SELECT Name, Points_Cost__c
            FROM Reward__c
            WHERE Partner__r.Name = :ENESERVIS AND Is_Active__c = TRUE
        ]) {
            catalog.put(reward.Name, reward.Points_Cost__c);
        }
        Assert.areEqual(
            new Map<String, Decimal>{
                'Sleva 200 Kč na přezutí' => 500,
                'Sleva 500 Kč na servis' => 1200,
                'Servisní prohlídka zdarma' => 5000
            },
            catalog,
            'Katalog EneServis má mít přesně tři aktivní odměny ze zadání.'
        );
    }

    // AC-1.3
    @IsTest
    static void seedCreatesRulesAndCampaigns() {
        // Když se spustí seed
        Test.startTest();
        KapkaDemoData.seed(JANA_EMAIL);
        Test.stopTest();

        // Pak platí 1 kapka za litr paliva a 1 kapka za 20 Kč ostatního s platností 12 měsíců
        // a jsou aktivní kampaně Natankuj plnou a Zastávka na cestě
        List<String> rules = new List<String>();
        for (Earning_Rule__c rule : [
            SELECT Product_Family__c, Basis__c, Unit_Size__c, Points_Per_Unit__c, Expiration_Months__c
            FROM Earning_Rule__c
            ORDER BY Product_Family__c
        ]) {
            rules.add(
                rule.Product_Family__c + ' ' + rule.Basis__c + ' ' + rule.Unit_Size__c.stripTrailingZeros().toPlainString() +
                ' → ' + rule.Points_Per_Unit__c.stripTrailingZeros().toPlainString() + ', ' + rule.Expiration_Months__c + ' m'
            );
        }
        List<String> campaigns = new List<String>();
        for (Loyalty_Campaign__c campaign : [SELECT Name FROM Loyalty_Campaign__c WHERE Is_Active__c = TRUE ORDER BY Name]) {
            campaigns.add(campaign.Name);
        }
        Assert.areEqual(
            'Fuel Per Liter 1 → 1, 12 m | Other Per CZK 20 → 1, 12 m || Natankuj plnou | Zastávka na cestě',
            String.join(rules, ' | ') + ' || ' + String.join(campaigns, ' | '),
            'Seed má založit pravidla a kampaně ze zadání.'
        );
    }

    // AC-3.1 (síť, katalog, pravidla; Jana přibude v R4)
    @IsTest
    static void seedTwiceKeepsSameData() {
        // Pokud seed už jednou proběhl
        KapkaDemoData.seed(JANA_EMAIL);

        // Když se spustí znovu
        Test.startTest();
        KapkaDemoData.seed(JANA_EMAIL);
        Test.stopTest();

        // Pak je pořád 120 stanic, tři odměny, dvě pravidla a dvě kampaně
        Assert.areEqual(
            '120 / 3 / 2 / 2',
            [SELECT COUNT() FROM Fuel_Station__c] + ' / ' + [SELECT COUNT() FROM Reward__c] + ' / ' +
            [SELECT COUNT() FROM Earning_Rule__c] + ' / ' + [SELECT COUNT() FROM Loyalty_Campaign__c],
            'Druhé spuštění seedu nesmí nic zdvojit.'
        );
    }
}
