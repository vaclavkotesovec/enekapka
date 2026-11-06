/**
 * Karta earn-zaklad: základní kapky za nákup.
 * Seam S1 z plánu: update Order__c.Status__c na Completed (trigger).
 */
@IsTest
private class KapkaEarnServiceTest {
    private static final String ACTIVE = 'Active';
    private static final String COMPLETED = 'Completed';
    private static final String EARN = 'Earn';
    private static final String FUEL = 'Fuel';
    private static final String OTHER = 'Other';
    private static final Date ENROLLED_ON = Date.newInstance(2026, 10, 1);
    private static final Date RULES_VALID_FROM = Date.newInstance(2026, 1, 1);

    // AC-1.1
    @IsTest
    static void memberGets54KapkyForDemoPurchase() {
        // Pokud aktivní členka Jana Nováková
        Loyalty_Member__c jana = createActiveMember('Jana', 'Nováková');
        createBaseRules(RULES_VALID_FROM);
        // A nákup na stanici Kapka Brno – Vídeňská s 45 l paliva a ostatním za 180 Kč
        Order__c purchase = createOrder(jana.Id, 'KPK-001-000001');
        addItem(purchase.Id, 'Natural 95', FUEL, 38, 45);
        addItem(purchase.Id, 'Káva a sušenka', OTHER, 180, 1);

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak má Jana připsáno 54 kapek jako základ
        Points_Transaction__c credit = [
            SELECT Type__c, Status__c, Source__c, Points__c, Base_Points__c, Order__c
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c = :jana.Id
        ];
        Assert.isTrue(
            credit.Type__c == EARN &&
                credit.Status__c == 'Posted' &&
                credit.Source__c == 'Purchase' &&
                credit.Points__c == 54 &&
                credit.Base_Points__c == 54 &&
                credit.Order__c == purchase.Id,
            'Za 45 l a 180 Kč ostatního má vzniknout jedno zaúčtované připsání 54 kapek za nákup, vzniklo: ' + credit
        );
    }

    // AC-1.2
    @IsTest
    static void litersAreSummedPerPurchase() {
        // Pokud nákup aktivního člena se dvěma položkami paliva po 20,6 l
        Loyalty_Member__c member = createActiveMember('Petr', 'Svoboda');
        createBaseRules(RULES_VALID_FROM);
        Order__c purchase = createOrder(member.Id, 'KPK-001-000002');
        Product2 fuel = KapkaTestDataFactory.createProduct('Natural 95', FUEL, 38);
        insert new List<Order_Item__c>{
            KapkaTestDataFactory.makeOrderItem(purchase.Id, fuel.Id, 20.6),
            KapkaTestDataFactory.makeOrderItem(purchase.Id, fuel.Id, 20.6)
        };

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak má člen připsáno 41 kapek
        Assert.areEqual(41, pointsOf(member.Id), 'Litry se sčítají za celý nákup: floor(41,2) = 41.');
    }

    // AC-1.3
    @IsTest
    static void unfinished20CzkDoNotCount() {
        // Pokud nákup aktivního člena jen s ostatním zbožím za 39 Kč
        Loyalty_Member__c member = createActiveMember('Petr', 'Svoboda');
        createBaseRules(RULES_VALID_FROM);
        Order__c purchase = createOrder(member.Id, 'KPK-001-000003');
        addItem(purchase.Id, 'Bageta', OTHER, 39, 1);

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak má člen připsánu 1 kapku
        Assert.areEqual(1, pointsOf(member.Id), 'Za 39 Kč je jen jedna celá dvacetikoruna.');
    }

    // AC-2.1
    @IsTest
    static void completingTwiceEarnsOnce() {
        // Pokud dokončený nákup, za který člen dostal kapky
        Loyalty_Member__c member = createActiveMember('Petr', 'Svoboda');
        createBaseRules(RULES_VALID_FROM);
        Order__c purchase = createOrder(member.Id, 'KPK-001-000004');
        addItem(purchase.Id, 'Natural 95', FUEL, 38, 10);
        complete(purchase);
        update new Order__c(Id = purchase.Id, Status__c = 'Draft');

        // Když se nákup dokončí znovu
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak má člen za tento nákup pořád jen jedno připsání
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Points_Transaction__c WHERE Order__c = :purchase.Id],
            'Za jeden nákup smí vzniknout nejvýš jedno připsání.'
        );
    }

    // AC-2.2
    @IsTest
    static void zeroKapkyPurchaseCreatesNoTransaction() {
        // Pokud nákup aktivního člena jen s kávou za 15 Kč
        Loyalty_Member__c member = createActiveMember('Petr', 'Svoboda');
        createBaseRules(RULES_VALID_FROM);
        Order__c purchase = createOrder(member.Id, 'KPK-001-000005');
        addItem(purchase.Id, 'Káva', OTHER, 15, 1);

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak člen nemá za tento nákup žádný pohyb kapek
        Assert.areEqual(0, transactionCount(member.Id), 'Nákup za 0 kapek nemá vytvořit žádný pohyb (E5).');
    }

    // AC-3.1
    @IsTest
    static void inactiveMemberEarnsNothing() {
        // Pokud člen ve stavu Registrován
        Loyalty_Member__c member = createActiveMember('Petr', 'Svoboda');
        update new Loyalty_Member__c(Id = member.Id, Status__c = 'Registered');
        createBaseRules(RULES_VALID_FROM);
        Order__c purchase = createOrder(member.Id, 'KPK-001-000006');
        addItem(purchase.Id, 'Natural 95', FUEL, 38, 10);

        // Když se jeho nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak se nákup uloží a žádné kapky se nepřipíší
        Assert.areEqual(
            COMPLETED,
            [SELECT Status__c FROM Order__c WHERE Id = :purchase.Id].Status__c,
            'Nákup neaktivního člena se má normálně dokončit.'
        );
        Assert.areEqual(0, transactionCount(member.Id), 'Neaktivní člen nemá dostat kapky (E2).');
    }

    // AC-3.2
    @IsTest
    static void purchaseBeforeEnrollmentEarnsNothing() {
        // Pokud aktivní člen registrovaný 1. 11. 2026
        Loyalty_Member__c member = createActiveMember('Petr', 'Svoboda');
        update new Loyalty_Member__c(Id = member.Id, Enrollment_Date__c = Date.newInstance(2026, 11, 1));
        createBaseRules(RULES_VALID_FROM);
        // A nákup s datem 30. 10. 2026
        Order__c purchase = createOrder(member.Id, 'KPK-001-000007', Datetime.newInstance(2026, 10, 30, 12, 0, 0));
        addItem(purchase.Id, 'Natural 95', FUEL, 38, 10);

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak se žádné kapky nepřipíší
        Assert.areEqual(0, transactionCount(member.Id), 'Za nákup před registrací se kapky nepřipisují (E2).');
    }

    // AC-4.1
    @IsTest
    static void ruleValidOnPurchaseDateApplies() {
        // Pokud pravidlo za palivo 1 kapka za litr platné do 31. 10. 2026
        Loyalty_Member__c member = createActiveMember('Petr', 'Svoboda');
        Earning_Rule__c oldRule = KapkaTestDataFactory.makeEarningRule(FUEL, 'Per Liter', 1, 1, RULES_VALID_FROM);
        oldRule.Valid_To__c = Date.newInstance(2026, 10, 31);
        // A pravidlo za palivo 2 kapky za litr platné od 1. 11. 2026
        Earning_Rule__c newRule = KapkaTestDataFactory.makeEarningRule(FUEL, 'Per Liter', 1, 2, Date.newInstance(2026, 11, 1));
        insert new List<Earning_Rule__c>{ oldRule, newRule };
        // A nákup aktivního člena s 10 l paliva s datem 30. 10. 2026
        Order__c purchase = createOrder(member.Id, 'KPK-001-000008', Datetime.newInstance(2026, 10, 30, 12, 0, 0));
        addItem(purchase.Id, 'Natural 95', FUEL, 38, 10);

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak má člen připsáno 10 kapek
        Assert.areEqual(10, pointsOf(member.Id), 'Platí pravidlo platné k datu nákupu, ne k datu dokončení.');
    }

    // AC-5.1
    @IsTest
    static void earnExpiresTwelveMonthsAfterPurchaseAndTouchesMember() {
        // Pokud nákup aktivního člena s datem 6. 11. 2026 za 54 kapek
        Loyalty_Member__c member = createActiveMember('Jana', 'Nováková');
        createBaseRules(RULES_VALID_FROM);
        Order__c purchase = createOrder(member.Id, 'KPK-001-000009', Datetime.newInstance(2026, 11, 6, 8, 30, 0));
        addItem(purchase.Id, 'Natural 95', FUEL, 38, 45);
        addItem(purchase.Id, 'Káva a sušenka', OTHER, 180, 1);

        // Když se nákup dokončí
        Test.startTest();
        complete(purchase);
        Test.stopTest();

        // Pak připsání platí do 6. 11. 2027
        // A poslední aktivita člena je 6. 11. 2026
        Points_Transaction__c credit = [SELECT Expiration_Date__c FROM Points_Transaction__c WHERE Order__c = :purchase.Id];
        Loyalty_Member__c touched = [SELECT Last_Activity_Date__c FROM Loyalty_Member__c WHERE Id = :member.Id];
        Assert.areEqual(
            new List<Date>{ Date.newInstance(2027, 11, 6), Date.newInstance(2026, 11, 6) },
            new List<Date>{ credit.Expiration_Date__c, touched.Last_Activity_Date__c },
            'Připsání platí 12 měsíců od nákupu a poslední aktivita je datum nákupu.'
        );
    }

    // R10: bulk
    @IsTest
    static void twoHundredPurchasesEarnInOneTransaction() {
        Loyalty_Member__c member = createActiveMember('Petr', 'Svoboda');
        createBaseRules(RULES_VALID_FROM);
        Fuel_Station__c station = KapkaTestDataFactory.createStation('Kapka Brno – Vídeňská', 'KPK-001');
        List<Order__c> purchases = new List<Order__c>();
        for (Integer i = 0; i < 200; i++) {
            purchases.add(KapkaTestDataFactory.makeOrder(member.Id, station.Id, 'BULK-' + i));
        }
        insert purchases;
        Product2 fuel = KapkaTestDataFactory.createProduct('Natural 95', FUEL, 38);
        List<Order_Item__c> items = new List<Order_Item__c>();
        for (Order__c purchase : purchases) {
            items.add(KapkaTestDataFactory.makeOrderItem(purchase.Id, fuel.Id, 10));
        }
        insert items;
        for (Order__c purchase : purchases) {
            purchase.Status__c = COMPLETED;
        }

        Test.startTest();
        update purchases;
        Test.stopTest();

        Assert.areEqual(2000, pointsOf(member.Id), '200 nákupů po 10 l má v jedné transakci dát 200 připsání po 10 kapkách.');
    }

    // ---------- pomocníci ----------

    private static Decimal pointsOf(Id memberId) {
        AggregateResult total = [SELECT SUM(Points__c) points FROM Points_Transaction__c WHERE Loyalty_Member__c = :memberId];
        return (Decimal) total.get('points');
    }

    private static Integer transactionCount(Id memberId) {
        return [SELECT COUNT() FROM Points_Transaction__c WHERE Loyalty_Member__c = :memberId];
    }

    private static Loyalty_Member__c createActiveMember(String firstName, String lastName) {
        Loyalty_Member__c member = KapkaTestDataFactory.makeMember(
            KapkaTestDataFactory.createPersonAccount(firstName, lastName).Id
        );
        member.Status__c = ACTIVE;
        member.Enrollment_Date__c = ENROLLED_ON;
        insert member;
        return member;
    }

    /** Pravidla ze zadání: 1 kapka za litr paliva, 1 kapka za celých 20 Kč ostatního, platnost 12 měsíců. */
    private static void createBaseRules(Date validFrom) {
        Earning_Rule__c fuelRule = KapkaTestDataFactory.makeEarningRule(FUEL, 'Per Liter', 1, 1, validFrom);
        Earning_Rule__c otherRule = KapkaTestDataFactory.makeEarningRule(OTHER, 'Per CZK', 20, 1, validFrom);
        fuelRule.Expiration_Months__c = 12;
        otherRule.Expiration_Months__c = 12;
        insert new List<Earning_Rule__c>{ fuelRule, otherRule };
    }

    private static Order__c createOrder(Id memberId, String receiptNumber) {
        return createOrder(memberId, receiptNumber, KapkaTestDataFactory.DEFAULT_PURCHASE_DATE);
    }

    private static Order__c createOrder(Id memberId, String receiptNumber, Datetime purchaseDate) {
        Fuel_Station__c station = KapkaTestDataFactory.createStation('Kapka Brno – Vídeňská', receiptNumber.left(7));
        Order__c purchase = KapkaTestDataFactory.makeOrder(memberId, station.Id, receiptNumber);
        purchase.Purchase_Date__c = purchaseDate;
        insert purchase;
        return purchase;
    }

    private static void addItem(Id orderId, String productName, String family, Decimal price, Decimal quantity) {
        Product2 product = KapkaTestDataFactory.createProduct(productName, family, price);
        insert KapkaTestDataFactory.makeOrderItem(orderId, product.Id, quantity);
    }

    private static void complete(Order__c purchase) {
        update new Order__c(Id = purchase.Id, Status__c = COMPLETED);
    }
}
