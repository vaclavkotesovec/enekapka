/**
 * Karta model-jadro: člen, nákup, kniha kapek, souhlasy.
 * Seamy S1–S5 z plánu: DML insert / update na objektech jádra, hodnoty z akceptačních kritérií.
 */
@IsTest
private class KapkaDataModelTest {
    private static final String JANA_FIRST = 'Jana';
    private static final String JANA_LAST = 'Nováková';
    private static final String STATION_NAME = 'Kapka Brno – Vídeňská';
    private static final String STATION_CODE = 'KPK-001';
    private static final String RECEIPT = 'KPK-001-000123';
    private static final String NATURAL_95 = 'Natural 95';
    private static final String FUEL = 'Fuel';
    private static final String OTHER = 'Other';
    private static final String EARN = 'Earn';
    private static final String REDEEM = 'Redeem';
    private static final String POSTED = 'Posted';
    private static final Decimal FUEL_PRICE = 38;
    private static final Decimal FUEL_LITERS = 45;
    private static final Decimal JANA_EARN = 109;

    private static Order__c createJanaOrder() {
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);
        Fuel_Station__c station = KapkaTestDataFactory.createStation(STATION_NAME, STATION_CODE);
        Order__c purchase = KapkaTestDataFactory.makeOrder(jana.Id, station.Id, RECEIPT);
        insert purchase;
        return purchase;
    }

    private static Order__c reloadOrder(Id orderId) {
        return [
            SELECT Total_Amount__c, Fuel_Amount__c, Fuel_Liters__c, Other_Amount__c
            FROM Order__c
            WHERE Id = :orderId
        ];
    }

    // ---------- AC-1: člen ----------

    // AC-1.1
    @IsTest
    static void newMemberIsRegistered() {
        // Pokud existuje osobní účet Jana Nováková
        Account jana = KapkaTestDataFactory.createPersonAccount(JANA_FIRST, JANA_LAST);

        // Když loyalty manažer založí člena Kapka Klubu pro tento účet
        Loyalty_Member__c member = KapkaTestDataFactory.makeMember(jana.Id);
        Test.startTest();
        insert member;
        Test.stopTest();

        // Pak je člen uložen ve stavu Registrován
        Loyalty_Member__c saved = [SELECT Status__c FROM Loyalty_Member__c WHERE Id = :member.Id];
        Assert.areEqual('Registered', saved.Status__c, 'Nový člen má začínat ve stavu Registrován.');
    }

    // AC-1.2
    @IsTest
    static void memberCanBeCompanyWithDriver() {
        // Pokud existuje firemní účet s kontaktem řidiče
        Account company = KapkaTestDataFactory.createCompany('Flotila Morava s.r.o.');
        Contact driver = KapkaTestDataFactory.createContact(company.Id, 'Petr', 'Dvořák');

        // Když loyalty manažer založí člena pro firmu a vybere řidiče
        Loyalty_Member__c member = KapkaTestDataFactory.makeMember(company.Id);
        member.Contact__c = driver.Id;
        Test.startTest();
        insert member;
        Test.stopTest();

        // Pak je člen uložen s vazbou na firmu i řidiče
        Integer linked = [
            SELECT COUNT()
            FROM Loyalty_Member__c
            WHERE Id = :member.Id AND Account__c = :company.Id AND Contact__c = :driver.Id
        ];
        Assert.areEqual(1, linked, 'Člen má být navázaný na firmu i na řidiče.');
    }

    // AC-1.3
    @IsTest
    static void memberRequiresAccount() {
        // Když loyalty manažer zkusí uložit člena bez účtu
        Test.startTest();
        Database.SaveResult result = Database.insert(KapkaTestDataFactory.makeMember(null), false);
        Test.stopTest();

        // Pak se člen neuloží
        Assert.isFalse(result.isSuccess(), 'Člen bez účtu se nesmí uložit.');
    }

    // ---------- AC-2: položka přebírá cenu a kategorii ----------

    // AC-2.1
    @IsTest
    static void fuelItemTakesPriceAndFamilyFromProduct() {
        // Pokud produkt Natural 95 je v kategorii Palivo s cenou 38 Kč
        Product2 natural = KapkaTestDataFactory.createProduct(NATURAL_95, FUEL, FUEL_PRICE);
        Order__c purchase = createJanaOrder();

        // Když se k nákupu zapíše položka 45 l Natural 95
        Order_Item__c item = KapkaTestDataFactory.makeOrderItem(purchase.Id, natural.Id, FUEL_LITERS);
        Test.startTest();
        insert item;
        Test.stopTest();

        // Pak má položka jednotkovou cenu 38 Kč, kategorii Palivo a celkem 1 710 Kč
        Order_Item__c saved = [SELECT Unit_Price__c, Product_Family__c, Line_Total__c FROM Order_Item__c WHERE Id = :item.Id];
        Assert.areEqual(
            '38 / Fuel / 1710',
            saved.Unit_Price__c.stripTrailingZeros().toPlainString() + ' / ' + saved.Product_Family__c + ' / ' +
            saved.Line_Total__c.stripTrailingZeros().toPlainString(),
            'Položka má převzít cenu a kategorii z produktu a spočítat celkem.'
        );
    }

    // AC-2.2
    @IsTest
    static void laterPriceChangeDoesNotChangeItem() {
        // Pokud nákup obsahuje položku Natural 95 za 38 Kč
        Product2 natural = KapkaTestDataFactory.createProduct(NATURAL_95, FUEL, FUEL_PRICE);
        Order_Item__c item = KapkaTestDataFactory.makeOrderItem(createJanaOrder().Id, natural.Id, FUEL_LITERS);
        insert item;

        // Když se cena produktu změní na 40 Kč
        natural.Price__c = 40;
        Test.startTest();
        update natural;
        update new Order_Item__c(Id = item.Id, Quantity__c = FUEL_LITERS);
        Test.stopTest();

        // Pak položka v nákupu dál stojí 38 Kč
        Order_Item__c saved = [SELECT Unit_Price__c FROM Order_Item__c WHERE Id = :item.Id];
        Assert.areEqual(FUEL_PRICE, saved.Unit_Price__c, 'Změna ceny produktu nesmí změnit uloženou položku.');
    }

    @IsTest
    static void itemWithZeroQuantityIsRejected() {
        // Pokud existuje nákup a produkt
        Product2 natural = KapkaTestDataFactory.createProduct(NATURAL_95, FUEL, FUEL_PRICE);
        Order__c purchase = createJanaOrder();

        // Když se zapíše položka s nulovým množstvím
        Test.startTest();
        Database.SaveResult result = Database.insert(KapkaTestDataFactory.makeOrderItem(purchase.Id, natural.Id, 0), false);
        Test.stopTest();

        // Pak se položka neuloží
        Assert.isFalse(result.isSuccess(), 'Položka s nulovým množstvím se nesmí uložit.');
    }

    @IsTest
    static void itemWithoutProductIsRejected() {
        // Pokud existuje nákup
        Order__c purchase = createJanaOrder();

        // Když se zapíše položka bez produktu
        Test.startTest();
        Database.SaveResult result = Database.insert(KapkaTestDataFactory.makeOrderItem(purchase.Id, null, FUEL_LITERS), false);
        Test.stopTest();

        // Pak se položka neuloží
        Assert.isFalse(result.isSuccess(), 'Položka bez produktu se nesmí uložit.');
    }

    @IsTest
    static void activeProductWithoutPriceIsRejected() {
        // Když se založí aktivní produkt bez ceny
        Product2 product = new Product2(Name = NATURAL_95, Family = FUEL, IsActive = true);
        Test.startTest();
        Database.SaveResult result = Database.insert(product, false);
        Test.stopTest();

        // Pak se produkt neuloží
        Assert.isFalse(result.isSuccess(), 'Aktivní produkt musí mít cenu.');
    }

    // ---------- AC-3: součty nákupu ----------

    // AC-3.1
    @IsTest
    static void demoPurchaseHasFuelAndOtherTotals() {
        // Pokud nákup Jany na stanici Kapka Brno – Vídeňská
        Product2 natural = KapkaTestDataFactory.createProduct(NATURAL_95, FUEL, FUEL_PRICE);
        Product2 coffee = KapkaTestDataFactory.createProduct('Káva a bageta', OTHER, 180);
        Order__c purchase = createJanaOrder();

        // Když se k němu zapíše 45 l paliva za 1 710 Kč a ostatní zboží za 180 Kč
        Test.startTest();
        insert new List<Order_Item__c>{
            KapkaTestDataFactory.makeOrderItem(purchase.Id, natural.Id, FUEL_LITERS),
            KapkaTestDataFactory.makeOrderItem(purchase.Id, coffee.Id, 1)
        };
        Test.stopTest();

        // Pak má nákup celkem 1 890 Kč, palivo 1 710 Kč, 45 l a ostatní 180 Kč
        Order__c saved = reloadOrder(purchase.Id);
        Assert.areEqual(
            '1890 / 1710 / 45 / 180',
            saved.Total_Amount__c.stripTrailingZeros().toPlainString() + ' / ' +
            saved.Fuel_Amount__c.stripTrailingZeros().toPlainString() + ' / ' +
            saved.Fuel_Liters__c.stripTrailingZeros().toPlainString() + ' / ' +
            saved.Other_Amount__c.stripTrailingZeros().toPlainString(),
            'Nákup má sečíst celkem, palivo (Kč a litry) a ostatní zboží.'
        );
    }

    @IsTest
    static void twoHundredItemsAreSnapshotted() {
        // Pokud existuje nákup a produkt Natural 95 za 38 Kč
        Product2 natural = KapkaTestDataFactory.createProduct(NATURAL_95, FUEL, FUEL_PRICE);
        Order__c purchase = createJanaOrder();
        List<Order_Item__c> items = new List<Order_Item__c>();
        for (Integer i = 0; i < 200; i++) {
            items.add(KapkaTestDataFactory.makeOrderItem(purchase.Id, natural.Id, 1));
        }

        // Když se najednou vloží 200 položek
        Test.startTest();
        insert items;
        Test.stopTest();

        // Pak všech 200 převzalo cenu z produktu
        Integer snapshotted = [SELECT COUNT() FROM Order_Item__c WHERE Order__c = :purchase.Id AND Unit_Price__c = :FUEL_PRICE];
        Assert.areEqual(200, snapshotted, 'Každá z 200 položek má převzít cenu produktu.');
    }

    // ---------- AC-4: jedna účtenka = jeden nákup ----------

    // AC-4.1
    @IsTest
    static void duplicateReceiptIsRejected() {
        // Pokud existuje nákup s číslem účtenky KPK-001-000123
        Order__c first = createJanaOrder();

        // Když se importuje další nákup se stejným číslem účtenky
        Order__c duplicate = first.clone(false, true);
        Test.startTest();
        Database.SaveResult result = Database.insert(duplicate, false);
        Test.stopTest();

        // Pak se druhý nákup neuloží
        Assert.isFalse(result.isSuccess(), 'Druhý nákup se stejným číslem účtenky se nesmí uložit.');
    }

    // AC-4.2
    @IsTest
    static void purchaseWithoutMemberIsRejected() {
        // Když se zkusí uložit nákup bez člena Kapka Klubu
        Fuel_Station__c station = KapkaTestDataFactory.createStation(STATION_NAME, STATION_CODE);
        Test.startTest();
        Database.SaveResult result = Database.insert(KapkaTestDataFactory.makeOrder(null, station.Id, RECEIPT), false);
        Test.stopTest();

        // Pak se nákup neuloží
        Assert.isFalse(result.isSuccess(), 'Nákup bez člena se nesmí uložit.');
    }

    // ---------- AC-5: zůstatek a neměnnost knihy ----------

    // AC-5.1
    @IsTest
    static void balanceCountsOnlyPostedTransactions() {
        // Pokud má člen pohyby Earn 109 a 50 zaúčtované a Redeem -100 zrušený
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);
        Test.startTest();
        insert new List<Points_Transaction__c>{
            KapkaTestDataFactory.makeTransaction(jana.Id, EARN, POSTED, JANA_EARN),
            KapkaTestDataFactory.makeTransaction(jana.Id, EARN, POSTED, 50),
            KapkaTestDataFactory.makeTransaction(jana.Id, REDEEM, 'Cancelled', -100)
        };
        Test.stopTest();

        // Když loyalty manažer otevře člena, pak vidí zůstatek 159 kapek
        Loyalty_Member__c saved = [SELECT Points_Balance__c FROM Loyalty_Member__c WHERE Id = :jana.Id];
        Assert.areEqual(159, saved.Points_Balance__c, 'Zůstatek má sečíst jen zaúčtované pohyby.');
    }

    @IsTest
    static void postedTransactionPointsCannotChange() {
        // Pokud má člen zaúčtované připsání 109 kapek
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);
        Points_Transaction__c earn = KapkaTestDataFactory.makeTransaction(jana.Id, EARN, POSTED, JANA_EARN);
        insert earn;

        // Když se někdo pokusí změnit kapky na 200
        Test.startTest();
        Database.SaveResult result = Database.update(new Points_Transaction__c(Id = earn.Id, Points__c = 200), false);
        Test.stopTest();

        // Pak se změna neuloží
        Assert.isFalse(result.isSuccess(), 'Kapky zaúčtovaného pohybu se nesmí změnit.');
    }

    @IsTest
    static void adjustmentWithoutReasonIsRejected() {
        // Pokud existuje člen
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);

        // Když podpora založí úpravu kapek bez důvodu
        Test.startTest();
        Database.SaveResult result = Database.insert(
            KapkaTestDataFactory.makeTransaction(jana.Id, 'Adjustment', POSTED, 20),
            false
        );
        Test.stopTest();

        // Pak se úprava neuloží
        Assert.isFalse(result.isSuccess(), 'Úprava kapek musí mít důvod.');
    }

    // ---------- AC-6: zbývající kapky připsání ----------

    // AC-6.1
    @IsTest
    static void allocationReducesRemainingPoints() {
        // Pokud má člen připsání 109 kapek
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);
        Points_Transaction__c earn = KapkaTestDataFactory.makeTransaction(jana.Id, EARN, POSTED, JANA_EARN);
        Points_Transaction__c redeem = KapkaTestDataFactory.makeTransaction(jana.Id, REDEEM, POSTED, -100);
        insert new List<Points_Transaction__c>{ earn, redeem };

        // Když se z něj alokací spotřebuje 100 kapek
        Test.startTest();
        insert KapkaTestDataFactory.makeAllocation(earn.Id, redeem.Id, 100);
        Test.stopTest();

        // Pak z připsání zbývá 9 kapek
        Points_Transaction__c saved = [SELECT Remaining_Points__c FROM Points_Transaction__c WHERE Id = :earn.Id];
        Assert.areEqual(9, saved.Remaining_Points__c, 'Z připsání 109 po alokaci 100 má zbývat 9 kapek.');
    }

    @IsTest
    static void allocationWithZeroPointsIsRejected() {
        // Pokud má člen připsání a čerpání
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);
        Points_Transaction__c earn = KapkaTestDataFactory.makeTransaction(jana.Id, EARN, POSTED, JANA_EARN);
        Points_Transaction__c redeem = KapkaTestDataFactory.makeTransaction(jana.Id, REDEEM, POSTED, -100);
        insert new List<Points_Transaction__c>{ earn, redeem };

        // Když se založí alokace s nula kapkami
        Test.startTest();
        Database.SaveResult result = Database.insert(KapkaTestDataFactory.makeAllocation(earn.Id, redeem.Id, 0), false);
        Test.stopTest();

        // Pak se alokace neuloží
        Assert.isFalse(result.isSuccess(), 'Alokace musí mít kladný počet kapek.');
    }

    // ---------- AC-7: souhlasy podle účelu ----------

    // AC-7.1
    @IsTest
    static void marketingConsentIsRecordedPerPurpose() {
        // Pokud v programu existují účely Marketing a Loyalty
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        Account jana = KapkaTestDataFactory.createPersonAccount(JANA_FIRST, JANA_LAST);
        Id janaIndividualId = [SELECT PersonIndividualId FROM Account WHERE Id = :jana.Id].PersonIndividualId;

        // Když Jana udělí souhlas s marketingem
        Test.startTest();
        insert KapkaTestDataFactory.makeOptInConsent(janaIndividualId, purposes.get(KapkaTestDataFactory.MARKETING_PURPOSE));
        Test.stopTest();

        // Pak je u ní evidován souhlas s účelem Marketing ve stavu Opt In
        Integer consents = [
            SELECT COUNT()
            FROM PartyConsent
            WHERE PartyId = :janaIndividualId
                AND DataUsePurpose.Name = :KapkaTestDataFactory.MARKETING_PURPOSE
                AND PrivacyConsentStatus = 'OptIn'
        ];
        Assert.areEqual(1, consents, 'Jana má mít souhlas s marketingem ve stavu Opt In.');
    }
}
