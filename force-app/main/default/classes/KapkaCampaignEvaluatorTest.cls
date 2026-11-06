/**
 * Karta earn-kampane: kapky navíc z kampaní.
 * Seam S1 z plánu: update Order__c.Status__c na Completed (trigger) – kampaně end-to-end.
 */
@IsTest
private class KapkaCampaignEvaluatorTest {
    private static final String ACTIVE = 'Active';
    private static final String COMPLETED = 'Completed';
    private static final String FUEL = 'Fuel';
    private static final String OTHER = 'Other';
    private static final String MIN_FUEL_LITERS = 'Min Fuel Liters';
    private static final String MIN_OTHER_AMOUNT = 'Min Other Amount';
    private static final String FIXED_POINTS = 'Fixed Points';
    private static final String BASE_MULTIPLIER = 'Base Multiplier';
    private static final String NATANKUJ_PLNOU = 'Natankuj plnou';
    private static final String ZASTAVKA_NA_CESTE = 'Zastávka na cestě';
    private static final Date ENROLLED_ON = Date.newInstance(2026, 10, 1);
    private static final Date RULES_VALID_FROM = Date.newInstance(2026, 1, 1);

    // AC-1.1
    @IsTest
    static void fullTankAdds50Kapky() {
        // Pokud aktivní kampaň Natankuj plnou
        Loyalty_Member__c member = setUpMember();
        insertCampaign(NATANKUJ_PLNOU, MIN_FUEL_LITERS, 40, FIXED_POINTS, 50);
        // A nákup aktivního člena se 40 l paliva
        Order__c purchase = createPurchase(member.Id, 'KPK-001-100001', 40, 0);

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak má člen připsáno 40 + 50 = 90 kapek
        Assert.areEqual(90, pointsOf(member.Id), 'Za 40 l má být 40 kapek základ + 50 za Natankuj plnou.');
    }

    // AC-1.2
    @IsTest
    static void under40LitersAddsNothing() {
        // Pokud aktivní kampaň Natankuj plnou
        Loyalty_Member__c member = setUpMember();
        insertCampaign(NATANKUJ_PLNOU, MIN_FUEL_LITERS, 40, FIXED_POINTS, 50);
        // A nákup aktivního člena s 39,9 l paliva
        Order__c purchase = createPurchase(member.Id, 'KPK-001-100002', 39.9, 0);

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak má člen připsáno 39 kapek
        Assert.areEqual(39, pointsOf(member.Id), 'Pod 40 l se kampaň Natankuj plnou neuplatní.');
    }

    // AC-2.1
    @IsTest
    static void roadStopMultipliesBaseDown() {
        // Pokud aktivní kampaň Zastávka na cestě
        Loyalty_Member__c member = setUpMember();
        insertCampaign(ZASTAVKA_NA_CESTE, MIN_OTHER_AMOUNT, 150, BASE_MULTIPLIER, 1.1);
        // A nákup aktivního člena s 10 l paliva a ostatním za 150 Kč
        Order__c purchase = createPurchase(member.Id, 'KPK-001-100003', 10, 150);

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak má člen připsáno 17 + 1 = 18 kapek
        Assert.areEqual(18, pointsOf(member.Id), 'floor(17 × 1,1) = 18, tedy +1 ke 17 kapkám základu.');
    }

    // AC-3.1
    @IsTest
    static void janaGets109KapkyWithBothCampaigns() {
        // Pokud aktivní kampaně Natankuj plnou a Zastávka na cestě
        Loyalty_Member__c jana = setUpMember();
        Loyalty_Campaign__c natankuj = insertCampaign(NATANKUJ_PLNOU, MIN_FUEL_LITERS, 40, FIXED_POINTS, 50);
        Loyalty_Campaign__c zastavka = insertCampaign(ZASTAVKA_NA_CESTE, MIN_OTHER_AMOUNT, 150, BASE_MULTIPLIER, 1.1);
        // A Jana natankuje 45 l za 1 710 Kč a koupí kávu se sušenkou za 180 Kč
        Order__c purchase = createPurchase(jana.Id, 'KPK-001-100004', 45, 180);

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak má Jana připsáno 109 kapek
        Points_Transaction__c credit = [
            SELECT Points__c, Base_Points__c, Campaign_Points__c
            FROM Points_Transaction__c
            WHERE Order__c = :purchase.Id
        ];
        Assert.areEqual(
            new List<Decimal>{ 109, 54, 55 },
            new List<Decimal>{ credit.Points__c, credit.Base_Points__c, credit.Campaign_Points__c },
            'Jana má mít jedno připsání 109 kapek: 54 základ + 55 z kampaní.'
        );
        // A u připsání vidí kampaně Zastávka na cestě +5 a Natankuj plnou +50
        Map<Id, Decimal> applied = new Map<Id, Decimal>();
        for (Applied_Campaign__c row : [
            SELECT Loyalty_Campaign__c, Points__c
            FROM Applied_Campaign__c
            WHERE Points_Transaction__r.Order__c = :purchase.Id
        ]) {
            applied.put(row.Loyalty_Campaign__c, row.Points__c);
        }
        Assert.areEqual(
            new Map<Id, Decimal>{ zastavka.Id => 5, natankuj.Id => 50 },
            applied,
            'U připsání mají být uplatněné kampaně Zastávka na cestě +5 a Natankuj plnou +50.'
        );
    }

    // AC-4.1
    @IsTest
    static void expiredCampaignDoesNotApply() {
        // Pokud kampaň Natankuj plnou platná do 31. 10. 2026
        Loyalty_Member__c member = setUpMember();
        Loyalty_Campaign__c campaign = makeCampaign(NATANKUJ_PLNOU, MIN_FUEL_LITERS, 40, FIXED_POINTS, 50);
        campaign.Valid_To__c = Date.newInstance(2026, 10, 31);
        insert campaign;
        // A nákup aktivního člena se 45 l s datem 6. 11. 2026
        Order__c purchase = createPurchase(member.Id, 'KPK-001-100005', 45, 0);

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak má člen připsáno 45 kapek
        Assert.areEqual(45, pointsOf(member.Id), 'Kampaň mimo období platnosti se neuplatní.');
    }

    // AC-4.2
    @IsTest
    static void inactiveCampaignDoesNotApply() {
        // Pokud kampaň Natankuj plnou je vypnutá
        Loyalty_Member__c member = setUpMember();
        Loyalty_Campaign__c campaign = makeCampaign(NATANKUJ_PLNOU, MIN_FUEL_LITERS, 40, FIXED_POINTS, 50);
        campaign.Is_Active__c = false;
        insert campaign;
        // A nákup aktivního člena se 45 l
        Order__c purchase = createPurchase(member.Id, 'KPK-001-100006', 45, 0);

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak má člen připsáno 45 kapek
        Assert.areEqual(45, pointsOf(member.Id), 'Vypnutá kampaň se neuplatní.');
    }

    // AC-5.1
    @IsTest
    static void newCampaignWorksWithoutCode() {
        // Pokud loyalty manažer založí kampaň „Velký nákup“ s podmínkou ostatní aspoň 500 Kč a odměnou 30 kapek
        Loyalty_Member__c member = setUpMember();
        insertCampaign('Velký nákup', MIN_OTHER_AMOUNT, 500, FIXED_POINTS, 30);
        // A nákup aktivního člena s ostatním za 500 Kč
        Order__c purchase = createPurchase(member.Id, 'KPK-001-100007', 0, 500);

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak má člen připsáno 25 + 30 = 55 kapek
        Assert.areEqual(55, pointsOf(member.Id), 'Nová kampaň z dat má fungovat bez změny kódu.');
    }

    // R7: bulk
    @IsTest
    static void twoHundredPurchasesWithCampaigns() {
        Loyalty_Member__c member = setUpMember();
        insertCampaign(NATANKUJ_PLNOU, MIN_FUEL_LITERS, 40, FIXED_POINTS, 50);
        insertCampaign(ZASTAVKA_NA_CESTE, MIN_OTHER_AMOUNT, 150, BASE_MULTIPLIER, 1.1);
        Fuel_Station__c station = KapkaTestDataFactory.createStation('Kapka Brno – Vídeňská', 'KPK-001');
        Product2 fuel = KapkaTestDataFactory.createProduct('Natural 95', FUEL, 38);
        Product2 snack = KapkaTestDataFactory.createProduct('Káva a sušenka', OTHER, 180);
        List<Order__c> purchases = new List<Order__c>();
        for (Integer i = 0; i < 200; i++) {
            purchases.add(KapkaTestDataFactory.makeOrder(member.Id, station.Id, 'BULK-K-' + i));
        }
        insert purchases;
        List<Order_Item__c> items = new List<Order_Item__c>();
        for (Order__c purchase : purchases) {
            items.add(KapkaTestDataFactory.makeOrderItem(purchase.Id, fuel.Id, 45));
            items.add(KapkaTestDataFactory.makeOrderItem(purchase.Id, snack.Id, 1));
            purchase.Status__c = COMPLETED;
        }
        insert items;

        Test.startTest();
        update purchases;
        Test.stopTest();

        Assert.areEqual(200 * 109, pointsOf(member.Id), '200 demo nákupů má dát 200 × 109 kapek.');
        Assert.areEqual(400, [SELECT COUNT() FROM Applied_Campaign__c], 'Každý nákup má dvě uplatněné kampaně.');
    }

    // ---------- pomocníci ----------

    private static Loyalty_Member__c setUpMember() {
        Loyalty_Member__c member = KapkaTestDataFactory.makeMember(
            KapkaTestDataFactory.createPersonAccount('Jana', 'Nováková').Id
        );
        member.Status__c = ACTIVE;
        member.Enrollment_Date__c = ENROLLED_ON;
        insert member;
        Earning_Rule__c fuelRule = KapkaTestDataFactory.makeEarningRule(FUEL, 'Per Liter', 1, 1, RULES_VALID_FROM);
        Earning_Rule__c otherRule = KapkaTestDataFactory.makeEarningRule(OTHER, 'Per CZK', 20, 1, RULES_VALID_FROM);
        fuelRule.Expiration_Months__c = 12;
        otherRule.Expiration_Months__c = 12;
        insert new List<Earning_Rule__c>{ fuelRule, otherRule };
        return member;
    }

    private static Loyalty_Campaign__c makeCampaign(
        String name,
        String conditionType,
        Decimal threshold,
        String rewardType,
        Decimal rewardValue
    ) {
        return KapkaTestDataFactory.makeCampaign(name, conditionType, threshold, rewardType, rewardValue);
    }

    private static Loyalty_Campaign__c insertCampaign(
        String name,
        String conditionType,
        Decimal threshold,
        String rewardType,
        Decimal rewardValue
    ) {
        Loyalty_Campaign__c campaign = makeCampaign(name, conditionType, threshold, rewardType, rewardValue);
        insert campaign;
        return campaign;
    }

    /** Nákup s danými litry paliva a částkou za ostatní zboží (jedna položka každého druhu). */
    private static Order__c createPurchase(Id memberId, String receiptNumber, Decimal fuelLiters, Decimal otherAmount) {
        Fuel_Station__c station = KapkaTestDataFactory.createStation('Kapka Brno – Vídeňská', receiptNumber.left(7));
        Order__c purchase = KapkaTestDataFactory.makeOrder(memberId, station.Id, receiptNumber);
        insert purchase;
        List<Order_Item__c> items = new List<Order_Item__c>();
        if (fuelLiters > 0) {
            Product2 fuel = KapkaTestDataFactory.createProduct('Natural 95', FUEL, 38);
            items.add(KapkaTestDataFactory.makeOrderItem(purchase.Id, fuel.Id, fuelLiters));
        }
        if (otherAmount > 0) {
            Product2 other = KapkaTestDataFactory.createProduct('Ostatní zboží', OTHER, otherAmount);
            items.add(KapkaTestDataFactory.makeOrderItem(purchase.Id, other.Id, 1));
        }
        insert items;
        return purchase;
    }

    private static void complete(Order__c purchase) {
        update new Order__c(Id = purchase.Id, Status__c = COMPLETED);
    }

    private static Decimal pointsOf(Id memberId) {
        AggregateResult total = [SELECT SUM(Points__c) points FROM Points_Transaction__c WHERE Loyalty_Member__c = :memberId];
        return (Decimal) total.get('points');
    }
}
