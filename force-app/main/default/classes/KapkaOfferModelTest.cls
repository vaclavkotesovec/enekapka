/**
 * Karta model-nabidka: pravidla, kampaně a katalog odměn jako data.
 * Seamy S1 a S3 z plánu: DML insert a validace na úrovni dat.
 */
@IsTest
private class KapkaOfferModelTest {
    private static final Date DEMO_DATE = Date.newInstance(2026, 11, 6);
    private static final Date RULES_VALID_FROM = Date.newInstance(2026, 1, 1);
    private static final String FUEL = 'Fuel';
    private static final String PER_LITER = 'Per Liter';
    private static final String MIN_FUEL_LITERS = 'Min Fuel Liters';
    private static final String FIXED_POINTS = 'Fixed Points';
    private static final String PARTNER_NAME = 'EneServis, s.r.o.';

    // AC-1.1
    @IsTest
    static void rulesFromAssignmentAreValid() {
        // Pokud loyalty manažer založí pravidla ze zadání
        List<Earning_Rule__c> rules = new List<Earning_Rule__c>{
            KapkaTestDataFactory.makeEarningRule(FUEL, PER_LITER, 1, 1, RULES_VALID_FROM),
            KapkaTestDataFactory.makeEarningRule('Other', 'Per CZK', 20, 1, RULES_VALID_FROM)
        };

        // Když se pravidla uloží
        Test.startTest();
        insert rules;
        Test.stopTest();

        // Pak jsou obě pravidla platná ke dni 6. 11. 2026
        Integer validRules = [
            SELECT COUNT()
            FROM Earning_Rule__c
            WHERE Valid_From__c <= :DEMO_DATE AND (Valid_To__c = NULL OR Valid_To__c >= :DEMO_DATE)
        ];
        Assert.areEqual(2, validRules, 'Obě pravidla ze zadání mají platit k 6. 11. 2026.');
    }

    // AC-1.2
    @IsTest
    static void ruleWithInvertedPeriodIsRejected() {
        Earning_Rule__c rule = KapkaTestDataFactory.makeEarningRule(FUEL, PER_LITER, 1, 1, DEMO_DATE);
        rule.Valid_To__c = DEMO_DATE.addDays(-1);

        Test.startTest();
        Database.SaveResult result = Database.insert(rule, false);
        Test.stopTest();

        Assert.isFalse(result.isSuccess(), 'Pravidlo s datem do před datem od se nesmí uložit.');
    }

    // AC-2.1
    @IsTest
    static void assignmentCampaignsAreActive() {
        List<Loyalty_Campaign__c> campaigns = new List<Loyalty_Campaign__c>{
            KapkaTestDataFactory.makeCampaign('Natankuj plnou', MIN_FUEL_LITERS, 40, FIXED_POINTS, 50),
            KapkaTestDataFactory.makeCampaign('Zastávka na cestě', 'Min Other Amount', 150, 'Base Multiplier', 1.1)
        };

        Test.startTest();
        insert campaigns;
        Test.stopTest();

        Integer activeCampaigns = [
            SELECT COUNT()
            FROM Loyalty_Campaign__c
            WHERE
                Is_Active__c = TRUE
                AND Valid_From__c <= :DEMO_DATE
                AND (Valid_To__c = NULL OR Valid_To__c >= :DEMO_DATE)
        ];
        Assert.areEqual(2, activeCampaigns, 'Obě kampaně ze zadání mají být aktivní v období platnosti.');
    }

    // AC-2.2
    @IsTest
    static void campaignWithoutRewardIsRejected() {
        Loyalty_Campaign__c campaign = KapkaTestDataFactory.makeCampaign(
            'Natankuj plnou',
            MIN_FUEL_LITERS,
            40,
            FIXED_POINTS,
            null
        );

        Test.startTest();
        Database.SaveResult result = Database.insert(campaign, false);
        Test.stopTest();

        Assert.isFalse(result.isSuccess(), 'Kampaň bez hodnoty odměny se nesmí uložit.');
    }

    // AC-4.1
    @IsTest
    static void eneServisCatalogHasThreeRewards() {
        Account eneServis = KapkaTestDataFactory.createPartner(PARTNER_NAME);
        List<Reward__c> rewards = new List<Reward__c>{
            KapkaTestDataFactory.makeReward(eneServis.Id, 'Sleva 200 Kč na přezutí', 500),
            KapkaTestDataFactory.makeReward(eneServis.Id, 'Sleva 500 Kč na servis', 1200),
            KapkaTestDataFactory.makeReward(eneServis.Id, 'Servisní prohlídka zdarma', 5000)
        };

        Test.startTest();
        insert rewards;
        Test.stopTest();

        Integer activeRewards = [
            SELECT COUNT()
            FROM Reward__c
            WHERE Partner__r.Name = :PARTNER_NAME AND Is_Active__c = TRUE
        ];
        Assert.areEqual(3, activeRewards, 'Katalog EneServis má mít tři aktivní odměny.');
    }

    // AC-4.2
    @IsTest
    static void rewardWithZeroCostIsRejected() {
        Account eneServis = KapkaTestDataFactory.createPartner(PARTNER_NAME);
        Reward__c reward = KapkaTestDataFactory.makeReward(eneServis.Id, 'Sleva 200 Kč na přezutí', 0);

        Test.startTest();
        Database.SaveResult result = Database.insert(reward, false);
        Test.stopTest();

        Assert.isFalse(result.isSuccess(), 'Odměna za 0 kapek se nesmí uložit.');
    }
}
