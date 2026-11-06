/**
 * Karta model-nabidka: pravidla, kampaně, odměny a vouchery jako data.
 * Seamy S1–S3 z plánu: DML insert a validace na úrovni dat.
 */
@IsTest
private class KapkaOfferModelTest {
    private static final Date DEMO_DATE = Date.newInstance(2026, 11, 6);
    private static final Date RULES_VALID_FROM = Date.newInstance(2026, 1, 1);
    private static final String FUEL = 'Fuel';
    private static final String OTHER = 'Other';
    private static final String PER_LITER = 'Per Liter';
    private static final String PER_CZK = 'Per CZK';
    private static final String MIN_FUEL_LITERS = 'Min Fuel Liters';
    private static final String MIN_OTHER_AMOUNT = 'Min Other Amount';
    private static final String FIXED_POINTS = 'Fixed Points';
    private static final String BASE_MULTIPLIER = 'Base Multiplier';
    private static final String NATANKUJ_PLNOU = 'Natankuj plnou';
    private static final String ZASTAVKA_NA_CESTE = 'Zastávka na cestě';
    private static final String PARTNER_NAME = 'EneServis, s.r.o.';
    private static final String SLEVA_NA_PREZUTI = 'Sleva 200 Kč na přezutí';
    private static final String VOUCHER_CODE = 'KPK-7Q2M-X9AB';
    private static final String EARN = 'Earn';
    private static final String REDEEM = 'Redeem';
    private static final String POSTED = 'Posted';
    private static final Decimal JANA_EARN_POINTS = 109;
    private static final Decimal ZASTAVKA_POINTS = 5;
    private static final Decimal NATANKUJ_POINTS = 50;

    // AC-1.1
    @IsTest
    static void rulesFromAssignmentAreValid() {
        // Pokud loyalty manažer založí pravidla ze zadání
        List<Earning_Rule__c> rules = new List<Earning_Rule__c>{
            KapkaTestDataFactory.makeEarningRule(FUEL, PER_LITER, 1, 1, RULES_VALID_FROM),
            KapkaTestDataFactory.makeEarningRule(OTHER, PER_CZK, 20, 1, RULES_VALID_FROM)
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
        // Pokud má pravidlo datem do dřív než datem od
        Earning_Rule__c rule = KapkaTestDataFactory.makeEarningRule(FUEL, PER_LITER, 1, 1, DEMO_DATE);
        rule.Valid_To__c = DEMO_DATE.addDays(-1);

        // Když ho loyalty manažer uloží
        Test.startTest();
        Database.SaveResult result = Database.insert(rule, false);
        Test.stopTest();

        // Pak se pravidlo neuloží kvůli období
        assertRejected(
            result,
            StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
            Earning_Rule__c.Valid_To__c,
            'Pravidlo s datem do před datem od se nesmí uložit.'
        );
    }

    // AC-2.1
    @IsTest
    static void assignmentCampaignsAreActive() {
        // Pokud loyalty manažer založí kampaně ze zadání
        List<Loyalty_Campaign__c> campaigns = makeAssignmentCampaigns();

        // Když se kampaně uloží
        Test.startTest();
        insert campaigns;
        Test.stopTest();

        // Pak jsou aktivní v období platnosti
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
        // Pokud kampaň nemá hodnotu odměny
        Loyalty_Campaign__c campaign = makeNatankujPlnou();
        campaign.Reward_Value__c = null;

        // Když ji loyalty manažer uloží
        Test.startTest();
        Database.SaveResult result = Database.insert(campaign, false);
        Test.stopTest();

        // Pak se kampaň neuloží kvůli chybějící odměně
        assertRejected(
            result,
            StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
            Loyalty_Campaign__c.Reward_Value__c,
            'Kampaň bez hodnoty odměny se nesmí uložit.'
        );
    }

    // Review SP1
    @IsTest
    static void campaignWithoutValidFromIsRejected() {
        // Pokud kampaň nemá datum Platí od
        Loyalty_Campaign__c campaign = makeNatankujPlnou();
        campaign.Valid_From__c = null;

        // Když ji loyalty manažer uloží
        Test.startTest();
        Database.SaveResult result = Database.insert(campaign, false);
        Test.stopTest();

        // Pak se kampaň neuloží, jinak by se tiše nikdy neuplatnila
        assertRejected(
            result,
            StatusCode.REQUIRED_FIELD_MISSING,
            Loyalty_Campaign__c.Valid_From__c,
            'Kampaň bez data Platí od se nesmí uložit.'
        );
    }

    // AC-3.1
    @IsTest
    static void appliedCampaignsAreVisibleOnEarn() {
        // Pokud Jana dostala za nákup připsání 109 kapek
        Points_Transaction__c earn = createJanaTransaction(EARN, JANA_EARN_POINTS);
        List<Loyalty_Campaign__c> campaigns = createAssignmentCampaigns();

        // Když se k připsání zapíší uplatněné kampaně Zastávka na cestě (+5) a Natankuj plnou (+50)
        Test.startTest();
        insert makeDemoAppliedCampaigns(earn.Id, campaigns);
        Test.stopTest();

        // Pak loyalty manažer u připsání vidí obě kampaně s jejich kapkami
        Map<String, Decimal> pointsByCampaign = new Map<String, Decimal>();
        for (Applied_Campaign__c applied : [
            SELECT Loyalty_Campaign__r.Name, Points__c
            FROM Applied_Campaign__c
            WHERE Points_Transaction__c = :earn.Id
        ]) {
            pointsByCampaign.put(applied.Loyalty_Campaign__r.Name, applied.Points__c);
        }
        Assert.areEqual(
            new Map<String, Decimal>{ ZASTAVKA_NA_CESTE => ZASTAVKA_POINTS, NATANKUJ_PLNOU => NATANKUJ_POINTS },
            pointsByCampaign,
            'U připsání mají být vidět obě uplatněné kampaně s jejich kapkami.'
        );
    }

    // Review ST2
    @IsTest
    static void campaignPointsOnEarnSumAppliedCampaigns() {
        // Pokud Jana dostala za nákup připsání 109 kapek
        Points_Transaction__c earn = createJanaTransaction(EARN, JANA_EARN_POINTS);
        List<Loyalty_Campaign__c> campaigns = createAssignmentCampaigns();

        // Když se k připsání zapíší kampaně +5 a +50
        Test.startTest();
        insert makeDemoAppliedCampaigns(earn.Id, campaigns);
        Test.stopTest();

        // Pak má připsání 55 kapek z kampaní
        Points_Transaction__c saved = [SELECT Campaign_Points__c FROM Points_Transaction__c WHERE Id = :earn.Id];
        Assert.areEqual(55, saved.Campaign_Points__c, 'Kapky z kampaní jsou součtem uplatněných kampaní.');
    }

    // Review SP2
    @IsTest
    static void appliedCampaignOnRedeemIsRejected() {
        // Pokud má Jana čerpání kapek
        Points_Transaction__c redeem = createJanaTransaction(REDEEM, -500);
        Loyalty_Campaign__c campaign = createAssignmentCampaigns()[1];

        // Když se k čerpání zapíše uplatněná kampaň
        Test.startTest();
        Database.SaveResult result = Database.insert(
            KapkaTestDataFactory.makeAppliedCampaign(redeem.Id, campaign.Id, NATANKUJ_POINTS),
            false
        );
        Test.stopTest();

        // Pak se neuloží, kampaně patří jen k připsání
        assertRejected(
            result,
            StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
            null,
            'Uplatněná kampaň smí být jen u připsání (Earn).'
        );
    }

    // Review SP2
    @IsTest
    static void appliedCampaignWithoutPointsIsRejected() {
        // Pokud má Jana připsání
        Points_Transaction__c earn = createJanaTransaction(EARN, JANA_EARN_POINTS);
        Loyalty_Campaign__c campaign = createAssignmentCampaigns()[1];

        // Když se k němu zapíše kampaň za 0 kapek
        Test.startTest();
        Database.SaveResult result = Database.insert(
            KapkaTestDataFactory.makeAppliedCampaign(earn.Id, campaign.Id, 0),
            false
        );
        Test.stopTest();

        // Pak se neuloží
        assertRejected(
            result,
            StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
            Applied_Campaign__c.Points__c,
            'Uplatněná kampaň musí přidat aspoň 1 kapku.'
        );
    }

    // AC-4.1
    @IsTest
    static void eneServisCatalogHasThreeRewards() {
        // Pokud partner EneServis, s.r.o.
        Account eneServis = KapkaTestDataFactory.createPartner(PARTNER_NAME);
        List<Reward__c> rewards = new List<Reward__c>{
            KapkaTestDataFactory.makeReward(eneServis.Id, SLEVA_NA_PREZUTI, 500),
            KapkaTestDataFactory.makeReward(eneServis.Id, 'Sleva 500 Kč na servis', 1200),
            KapkaTestDataFactory.makeReward(eneServis.Id, 'Servisní prohlídka zdarma', 5000)
        };

        // Když loyalty manažer založí odměny ze zadání
        Test.startTest();
        insert rewards;
        Test.stopTest();

        // Pak jsou v katalogu tři aktivní odměny partnera
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
        // Pokud odměna stojí 0 kapek
        Account eneServis = KapkaTestDataFactory.createPartner(PARTNER_NAME);
        Reward__c reward = KapkaTestDataFactory.makeReward(eneServis.Id, SLEVA_NA_PREZUTI, 0);

        // Když ji loyalty manažer uloží
        Test.startTest();
        Database.SaveResult result = Database.insert(reward, false);
        Test.stopTest();

        // Pak se odměna neuloží kvůli ceně
        assertRejected(
            result,
            StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
            Reward__c.Points_Cost__c,
            'Odměna za 0 kapek se nesmí uložit.'
        );
    }

    // AC-5.1
    @IsTest
    static void duplicateVoucherCodeIsRejected() {
        // Pokud existuje voucher s kódem KPK-7Q2M-X9AB
        Voucher__c existing = makeJanaVoucher(VOUCHER_CODE);
        insert existing;

        // Když se uloží další voucher se stejným kódem
        Test.startTest();
        Database.SaveResult result = Database.insert(
            KapkaTestDataFactory.makeVoucher(existing.Loyalty_Member__c, existing.Reward__c, VOUCHER_CODE),
            false
        );
        Test.stopTest();

        // Pak se druhý voucher neuloží kvůli duplicitě
        assertRejected(result, StatusCode.DUPLICATE_VALUE, null, 'Druhý voucher se stejným kódem se nesmí uložit.');
    }

    // AC-5.2
    @IsTest
    static void voucherCodeMustMatchFormat() {
        // Pokud má voucher kód 12345
        Voucher__c voucher = makeJanaVoucher('12345');

        // Když se uloží
        Test.startTest();
        Database.SaveResult result = Database.insert(voucher, false);
        Test.stopTest();

        // Pak se neuloží kvůli formátu kódu
        assertRejected(
            result,
            StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
            Voucher__c.Code__c,
            'Voucher s kódem mimo formát KPK-XXXX-XXXX se nesmí uložit.'
        );
    }

    // Review ST4
    @IsTest
    static void lowercaseVoucherCodeIsRejected() {
        // Pokud má voucher kód malými písmeny
        Voucher__c voucher = makeJanaVoucher(VOUCHER_CODE.toLowerCase());

        // Když se uloží
        Test.startTest();
        Database.SaveResult result = Database.insert(voucher, false);
        Test.stopTest();

        // Pak se neuloží, formát připouští jen velká písmena a číslice
        assertRejected(
            result,
            StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
            Voucher__c.Code__c,
            'Kód voucheru malými písmeny se nesmí uložit.'
        );
    }

    // Review ST4
    @IsTest
    static void validVoucherCodeIsAccepted() {
        // Pokud má voucher kód KPK-7Q2M-X9AB
        Voucher__c voucher = makeJanaVoucher(VOUCHER_CODE);

        // Když se uloží
        Test.startTest();
        Database.SaveResult result = Database.insert(voucher, false);
        Test.stopTest();

        // Pak je uložen ve stavu Vydán
        Voucher__c saved = [SELECT Status__c FROM Voucher__c WHERE Id = :result.getId()];
        Assert.areEqual('Issued', saved.Status__c, 'Voucher s platným kódem se uloží jako vydaný.');
    }

    private static void assertRejected(
        Database.SaveResult result,
        StatusCode expectedCode,
        Schema.SObjectField expectedField,
        String message
    ) {
        Assert.isFalse(result.isSuccess(), message);
        Database.Error error = result.getErrors()[0];
        Assert.areEqual(expectedCode, error.getStatusCode(), message + ' Skutečná chyba: ' + error.getMessage());
        if (expectedField != null) {
            Assert.isTrue(
                error.getFields().contains(expectedField.toString()),
                message + ' Chyba má být u pole ' + expectedField + ', je u ' + error.getFields()
            );
        }
    }

    private static Loyalty_Campaign__c makeNatankujPlnou() {
        return KapkaTestDataFactory.makeCampaign(NATANKUJ_PLNOU, MIN_FUEL_LITERS, 40, FIXED_POINTS, NATANKUJ_POINTS);
    }

    /** Kampaně ze zadání v pořadí Zastávka na cestě, Natankuj plnou. */
    private static List<Loyalty_Campaign__c> makeAssignmentCampaigns() {
        return new List<Loyalty_Campaign__c>{
            KapkaTestDataFactory.makeCampaign(ZASTAVKA_NA_CESTE, MIN_OTHER_AMOUNT, 150, BASE_MULTIPLIER, 1.1),
            makeNatankujPlnou()
        };
    }

    private static List<Loyalty_Campaign__c> createAssignmentCampaigns() {
        List<Loyalty_Campaign__c> campaigns = makeAssignmentCampaigns();
        insert campaigns;
        return campaigns;
    }

    private static List<Applied_Campaign__c> makeDemoAppliedCampaigns(Id earnId, List<Loyalty_Campaign__c> campaigns) {
        return new List<Applied_Campaign__c>{
            KapkaTestDataFactory.makeAppliedCampaign(earnId, campaigns[0].Id, ZASTAVKA_POINTS),
            KapkaTestDataFactory.makeAppliedCampaign(earnId, campaigns[1].Id, NATANKUJ_POINTS)
        };
    }

    private static Points_Transaction__c createJanaTransaction(String type, Decimal points) {
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        Points_Transaction__c pointsTransaction = KapkaTestDataFactory.makeTransaction(jana.Id, type, POSTED, points);
        insert pointsTransaction;
        return pointsTransaction;
    }

    /** Neuložený voucher Jany na slevu na přezutí od EneServisu. */
    private static Voucher__c makeJanaVoucher(String code) {
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        Reward__c reward = KapkaTestDataFactory.makeReward(
            KapkaTestDataFactory.createPartner(PARTNER_NAME).Id,
            SLEVA_NA_PREZUTI,
            500
        );
        insert reward;
        return KapkaTestDataFactory.makeVoucher(jana.Id, reward.Id, code);
    }
}
