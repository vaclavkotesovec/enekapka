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

    // ---------- pomocníci ----------

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
        Fuel_Station__c station = KapkaTestDataFactory.createStation('Kapka Brno – Vídeňská', receiptNumber.left(7));
        Order__c purchase = KapkaTestDataFactory.makeOrder(memberId, station.Id, receiptNumber);
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
