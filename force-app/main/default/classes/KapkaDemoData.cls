/**
 * Demo data Kapka Klubu (karta test-data): seed a reset jedním voláním.
 * without sharing záměrně (T5): volá ho jen admin ze skriptů scripts/demo-*.apex a testy,
 * data musí vzniknout a smazat se bez ohledu na vlastníka a sdílení záznamů.
 * Seed je idempotentní: stanice se párují podle Station_Code__c, ostatní podle Name.
 */
public without sharing class KapkaDemoData {
    public static final Integer STATION_COUNT = 120;
    public static final String FIRST_STATION_NAME = 'Kapka Brno – Vídeňská';
    public static final String PARTNER_NAME = 'EneServis, s.r.o.';
    private static final Date RULES_VALID_FROM = Date.newInstance(2026, 1, 1);
    private static final Integer KAPKY_VALIDITY_MONTHS = 12;

    /** Města sítě v pořadí, ve kterém se přidělují stanicím KPK-002 a dál: město → kraj (Region__c). */
    private static final List<List<String>> CITIES = new List<List<String>>{
        new List<String>{ 'Praha', 'Praha' },
        new List<String>{ 'Brno', 'Jihomoravsky' },
        new List<String>{ 'Ostrava', 'Moravskoslezsky' },
        new List<String>{ 'Plzeň', 'Plzensky' },
        new List<String>{ 'Liberec', 'Liberecky' },
        new List<String>{ 'Olomouc', 'Olomoucky' },
        new List<String>{ 'České Budějovice', 'Jihocesky' },
        new List<String>{ 'Hradec Králové', 'Kralovehradecky' },
        new List<String>{ 'Ústí nad Labem', 'Ustecky' },
        new List<String>{ 'Pardubice', 'Pardubicky' },
        new List<String>{ 'Zlín', 'Zlinsky' },
        new List<String>{ 'Jihlava', 'Vysocina' },
        new List<String>{ 'Karlovy Vary', 'Karlovarsky' },
        new List<String>{ 'Kladno', 'Stredocesky' }
    };

    /** Připraví síť, katalog, pravidla a kampaně. Jana (R4) a její portálový účet (R5) přibudou s navazujícími kartami. */
    public static void seed(String janaEmail) {
        upsertStations();
        upsertCatalog();
        upsertRulesAndCampaigns();
    }

    private static void upsertStations() {
        List<Fuel_Station__c> stations = new List<Fuel_Station__c>{
            new Fuel_Station__c(
                Name = FIRST_STATION_NAME,
                Station_Code__c = stationCode(1),
                City__c = 'Brno',
                Street__c = 'Vídeňská 120',
                Region__c = 'Jihomoravsky',
                Is_Active__c = true
            )
        };
        for (Integer i = 2; i <= STATION_COUNT; i++) {
            List<String> city = CITIES[Math.mod(i - 2, CITIES.size())];
            stations.add(
                new Fuel_Station__c(
                    Name = 'Kapka ' + city[0] + ' ' + String.valueOf(i).leftPad(3, '0'),
                    Station_Code__c = stationCode(i),
                    City__c = city[0],
                    Region__c = city[1],
                    Is_Active__c = true
                )
            );
        }
        Database.upsert(stations, Fuel_Station__c.Station_Code__c);
    }

    private static String stationCode(Integer index) {
        return 'KPK-' + String.valueOf(index).leftPad(3, '0');
    }

    private static void upsertCatalog() {
        Id partnerId = partnerId();
        upsertByName(
            new List<Reward__c>{
                reward(partnerId, 'Sleva 200 Kč na přezutí', 500, 200, 'Sleva 200 Kč na přezutí kol v servisu EneServis.'),
                reward(partnerId, 'Sleva 500 Kč na servis', 1200, 500, 'Sleva 500 Kč na servis vozu v EneServis.'),
                reward(partnerId, 'Servisní prohlídka zdarma', 5000, null, 'Kompletní servisní prohlídka vozu v EneServis zdarma.')
            }
        );
    }

    private static Id partnerId() {
        List<Account> partners = [SELECT Id FROM Account WHERE Name = :PARTNER_NAME LIMIT 1];
        if (!partners.isEmpty()) {
            return partners[0].Id;
        }
        Account partner = new Account(Name = PARTNER_NAME);
        insert partner;
        return partner.Id;
    }

    private static Reward__c reward(Id partnerId, String name, Decimal pointsCost, Decimal valueCzk, String description) {
        return new Reward__c(
            Name = name,
            Partner__c = partnerId,
            Points_Cost__c = pointsCost,
            Value_CZK__c = valueCzk,
            Description__c = description,
            Is_Active__c = true
        );
    }

    private static void upsertRulesAndCampaigns() {
        upsertByName(
            new List<Earning_Rule__c>{
                rule('Palivo – 1 kapka za litr', 'Fuel', 'Per Liter', 1),
                rule('Ostatní – 1 kapka za 20 Kč', 'Other', 'Per CZK', 20)
            }
        );
        upsertByName(
            new List<Loyalty_Campaign__c>{
                campaign('Natankuj plnou', 'Min Fuel Liters', 40, 'Fixed Points', 50, '50 kapek navíc za nákup aspoň 40 l paliva.'),
                campaign(
                    'Zastávka na cestě',
                    'Min Other Amount',
                    150,
                    'Base Multiplier',
                    1.1,
                    'Základní kapky × 1,1 při nákupu ostatního zboží za aspoň 150 Kč.'
                )
            }
        );
    }

    private static Earning_Rule__c rule(String name, String family, String basis, Decimal unitSize) {
        return new Earning_Rule__c(
            Name = name,
            Product_Family__c = family,
            Basis__c = basis,
            Unit_Size__c = unitSize,
            Points_Per_Unit__c = 1,
            Valid_From__c = RULES_VALID_FROM,
            Expiration_Months__c = KAPKY_VALIDITY_MONTHS
        );
    }

    private static Loyalty_Campaign__c campaign(
        String name,
        String conditionType,
        Decimal threshold,
        String rewardType,
        Decimal rewardValue,
        String description
    ) {
        return new Loyalty_Campaign__c(
            Name = name,
            Condition_Type__c = conditionType,
            Threshold__c = threshold,
            Reward_Type__c = rewardType,
            Reward_Value__c = rewardValue,
            Description__c = description,
            Valid_From__c = RULES_VALID_FROM,
            Is_Active__c = true
        );
    }

    /** Založí chybějící a přepíše existující záznamy stejného typu podle Name (seed vlastní tato data). */
    private static void upsertByName(List<SObject> desired) {
        Set<String> names = new Set<String>();
        for (SObject record : desired) {
            names.add((String) record.get('Name'));
        }
        Map<String, Id> existing = new Map<String, Id>();
        String query = 'SELECT Id, Name FROM ' + desired.getSObjectType() + ' WHERE Name IN :names';
        for (SObject record : Database.query(query)) {
            existing.put((String) record.get('Name'), record.Id);
        }
        List<SObject> toInsert = desired.clone();
        toInsert.clear();
        List<SObject> toUpdate = desired.clone();
        toUpdate.clear();
        for (SObject record : desired) {
            Id existingId = existing.get((String) record.get('Name'));
            if (existingId == null) {
                toInsert.add(record);
            } else {
                record.Id = existingId;
                toUpdate.add(record);
            }
        }
        insert toInsert;
        update toUpdate;
    }
}
