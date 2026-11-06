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
    private static final String TYPE_EARN = 'Earn';
    private static final String TYPE_REDEEM = 'Redeem';
    private static final String POSTED = 'Posted';
    private static final String COMPLETED = 'Completed';
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

    /** Ověří, že záznam neprošel ze správného důvodu: status code a pole chyby (null = chyba záznamu). */
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

    private static Product2 createNatural() {
        return KapkaTestDataFactory.createProduct(NATURAL_95, FUEL, FUEL_PRICE);
    }

    private static Order_Item__c createNaturalItem() {
        Order_Item__c item = KapkaTestDataFactory.makeOrderItem(createJanaOrder().Id, createNatural().Id, FUEL_LITERS);
        insert item;
        return item;
    }

    private static Points_Transaction__c createJanaTransaction(String type, String status, Decimal points) {
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);
        Points_Transaction__c pointsTransaction = KapkaTestDataFactory.makeTransaction(jana.Id, type, status, points);
        insert pointsTransaction;
        return pointsTransaction;
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
        assertRejected(result, StatusCode.REQUIRED_FIELD_MISSING, Loyalty_Member__c.Account__c, 'Člen bez účtu se nesmí uložit.');
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
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, Order_Item__c.Quantity__c, 'Položka s nulovým množstvím se nesmí uložit.');
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
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, Order_Item__c.Product__c, 'Položka bez produktu se nesmí uložit.');
    }

    @IsTest
    static void activeProductWithoutPriceIsRejected() {
        // Když se založí aktivní produkt bez ceny
        Product2 product = new Product2(Name = NATURAL_95, Family = FUEL, IsActive = true);
        Test.startTest();
        Database.SaveResult result = Database.insert(product, false);
        Test.stopTest();

        // Pak se produkt neuloží
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, Product2.Price__c, 'Aktivní produkt musí mít cenu.');
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
        assertRejected(result, StatusCode.DUPLICATE_VALUE, null, 'Druhý nákup se stejným číslem účtenky se nesmí uložit.');
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
        assertRejected(result, StatusCode.REQUIRED_FIELD_MISSING, Order__c.Loyalty_Member__c, 'Nákup bez člena se nesmí uložit.');
    }

    // ---------- AC-5: zůstatek a neměnnost knihy ----------

    // AC-5.1
    @IsTest
    static void balanceCountsOnlyPostedTransactions() {
        // Pokud má člen pohyby Earn 109 a 50 zaúčtované a Redeem -100 zrušený
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);
        Test.startTest();
        insert new List<Points_Transaction__c>{
            KapkaTestDataFactory.makeTransaction(jana.Id, TYPE_EARN, POSTED, JANA_EARN),
            KapkaTestDataFactory.makeTransaction(jana.Id, TYPE_EARN, POSTED, 50),
            KapkaTestDataFactory.makeTransaction(jana.Id, TYPE_REDEEM, 'Cancelled', -100)
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
        Points_Transaction__c earn = KapkaTestDataFactory.makeTransaction(jana.Id, TYPE_EARN, POSTED, JANA_EARN);
        insert earn;

        // Když se někdo pokusí změnit kapky na 200
        Test.startTest();
        Database.SaveResult result = Database.update(new Points_Transaction__c(Id = earn.Id, Points__c = 200), false);
        Test.stopTest();

        // Pak se změna neuloží
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, null, 'Kapky zaúčtovaného pohybu se nesmí změnit.');
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
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, Points_Transaction__c.Reason__c, 'Úprava kapek musí mít důvod.');
    }

    // ---------- AC-6: zbývající kapky připsání ----------

    // AC-6.1
    @IsTest
    static void allocationReducesRemainingPoints() {
        // Pokud má člen připsání 109 kapek
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);
        Points_Transaction__c earn = KapkaTestDataFactory.makeTransaction(jana.Id, TYPE_EARN, POSTED, JANA_EARN);
        Points_Transaction__c redeem = KapkaTestDataFactory.makeTransaction(jana.Id, TYPE_REDEEM, POSTED, -100);
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
        Points_Transaction__c earn = KapkaTestDataFactory.makeTransaction(jana.Id, TYPE_EARN, POSTED, JANA_EARN);
        Points_Transaction__c redeem = KapkaTestDataFactory.makeTransaction(jana.Id, TYPE_REDEEM, POSTED, -100);
        insert new List<Points_Transaction__c>{ earn, redeem };

        // Když se založí alokace s nula kapkami
        Test.startTest();
        Database.SaveResult result = Database.insert(KapkaTestDataFactory.makeAllocation(earn.Id, redeem.Id, 0), false);
        Test.stopTest();

        // Pak se alokace neuloží
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, Points_Allocation__c.Points__c, 'Alokace musí mít kladný počet kapek.');
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

    // ---------- Review kolo 1: oprávnění loyalty manažera (ST-2, SP-1) ----------

    // R13
    @IsTest
    static void managerCannotDeleteMember() {
        // Pokud loyalty manažer spravuje členku Janu
        User manager = KapkaTestDataFactory.createLoyaltyManager();
        Loyalty_Member__c jana;
        System.runAs(manager) {
            jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);
        }

        // Když se ji pokusí smazat
        Boolean deleted = true;
        Test.startTest();
        System.runAs(manager) {
            try {
                Database.delete(jana, AccessLevel.USER_MODE);
            } catch (Exception denied) {
                deleted = false;
            }
        }
        Test.stopTest();

        // Pak se členka nesmaže (s ní by kaskádou zmizela celá kniha kapek)
        Assert.isFalse(deleted, 'Loyalty manažer nesmí mazat členy; ukončení členství je stav Ukončen.');
    }

    // R13
    @IsTest
    static void managerCannotDeleteTransaction() {
        // Pokud má Jana zaúčtované připsání
        User manager = KapkaTestDataFactory.createLoyaltyManager();
        Points_Transaction__c earn;
        System.runAs(manager) {
            earn = createJanaTransaction(TYPE_EARN, POSTED, JANA_EARN);
        }

        // Když se ho loyalty manažer pokusí smazat
        Boolean deleted = true;
        Test.startTest();
        System.runAs(manager) {
            try {
                Database.delete(earn, AccessLevel.USER_MODE);
            } catch (Exception denied) {
                deleted = false;
            }
        }
        Test.stopTest();

        // Pak pohyb zůstane v knize
        Assert.isFalse(deleted, 'Loyalty manažer nesmí mazat pohyby kapek.');
    }

    // R22 (ST-13)
    @IsTest
    static void managerCannotDeletePurchase() {
        // Pokud loyalty manažer zapsal Janě nákup
        User manager = KapkaTestDataFactory.createLoyaltyManager();
        Order__c purchase;
        System.runAs(manager) {
            purchase = createJanaOrder();
        }

        // Když se ho pokusí smazat
        Boolean deleted = true;
        Test.startTest();
        System.runAs(manager) {
            try {
                Database.delete(purchase, AccessLevel.USER_MODE);
            } catch (Exception denied) {
                deleted = false;
            }
        }
        Test.stopTest();

        // Pak nákup zůstane (připsání by ztratilo vazbu a účtenka by šla připsat znovu); mazat smí jen admin
        Assert.isFalse(deleted, 'Loyalty manažer nesmí mazat nákupy.');
    }

    // R23 (ST-15)
    @IsTest
    static void managerCannotDeleteItem() {
        // Pokud loyalty manažer zapsal Janě nákup s položkou Natural 95
        User manager = KapkaTestDataFactory.createLoyaltyManager();
        Product2 natural = createNatural();
        Order_Item__c item;
        System.runAs(manager) {
            item = KapkaTestDataFactory.makeOrderItem(createJanaOrder().Id, natural.Id, FUEL_LITERS);
            insert item;
        }

        // Když se pokusí položku smazat
        Boolean deleted = true;
        Test.startTest();
        System.runAs(manager) {
            try {
                Database.delete(item, AccessLevel.USER_MODE);
            } catch (Exception denied) {
                deleted = false;
            }
        }
        Test.stopTest();

        // Pak položka zůstane (smazání by měnilo součty nákupu, ze kterých jsou kapky)
        Assert.isFalse(deleted, 'Loyalty manažer nesmí mazat položky nákupu.');
    }

    // R24 (ST-15)
    @IsTest
    static void completedPurchaseItemQuantityCannotChange() {
        // Pokud Jana dokončila nákup 45 l Natural 95
        Order_Item__c item = createNaturalItem();
        update new Order__c(Id = item.Order__c, Status__c = COMPLETED);

        // Když někdo u položky změní množství na 90 l
        Test.startTest();
        Database.SaveResult result = Database.update(new Order_Item__c(Id = item.Id, Quantity__c = 90), false);
        Test.stopTest();

        // Pak se změna neuloží (kapky jsou připsané z původních součtů)
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, null, 'Položku dokončeného nákupu nelze měnit.');
    }

    // R24 (ST-15)
    @IsTest
    static void itemCannotBeAddedToCompletedPurchase() {
        // Pokud Jana dokončila nákup 45 l Natural 95
        Order_Item__c item = createNaturalItem();
        update new Order__c(Id = item.Order__c, Status__c = COMPLETED);
        Product2 coffee = KapkaTestDataFactory.createProduct('Káva a bageta', OTHER, 180);

        // Když se k nákupu dodatečně přidá káva
        Test.startTest();
        Database.SaveResult result = Database.insert(KapkaTestDataFactory.makeOrderItem(item.Order__c, coffee.Id, 1), false);
        Test.stopTest();

        // Pak se položka neuloží
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, null, 'K dokončenému nákupu nelze přidat položku.');
    }

    // R25 (ST-15)
    @IsTest
    static void completedPurchaseItemCannotBeDeleted() {
        // Pokud Jana dokončila nákup 45 l Natural 95
        Order_Item__c item = createNaturalItem();
        update new Order__c(Id = item.Order__c, Status__c = COMPLETED);

        // Když se položku pokusí smazat i admin
        Test.startTest();
        Database.DeleteResult result = Database.delete(item, false);
        Test.stopTest();

        // Pak položka zůstane (součty nákupu jsou podklad připsaných kapek)
        Assert.isFalse(result.isSuccess(), 'Položku dokončeného nákupu nesmí smazat nikdo.');
        Assert.areEqual(
            System.Label.Kapka_Completed_Order_Item_Locked,
            result.getErrors()[0].getMessage(),
            'Smazání má odmítnout zámek dokončeného nákupu.'
        );
    }

    private static Order__c createCompletedJanaOrder() {
        Order_Item__c item = createNaturalItem();
        update new Order__c(Id = item.Order__c, Status__c = COMPLETED);
        return [SELECT Id, Loyalty_Member__c FROM Order__c WHERE Id = :item.Order__c];
    }

    // R26 (ST-15)
    @IsTest
    static void completedPurchaseCannotReturnToDraft() {
        // Pokud Jana dokončila nákup
        Order__c purchase = createCompletedJanaOrder();

        // Když ho někdo vrátí na Rozpracovaný
        Test.startTest();
        Database.SaveResult result = Database.update(new Order__c(Id = purchase.Id, Status__c = 'Draft'), false);
        Test.stopTest();

        // Pak se změna neuloží (oprava nákupu je vratka, ta je mimo rozsah)
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, null, 'Dokončený nákup nejde vrátit na Rozpracovaný.');
    }

    // R26 (ST-15)
    @IsTest
    static void completedPurchaseReceiptCannotChange() {
        // Pokud Jana dokončila nákup s účtenkou KPK-001-000123
        Order__c purchase = createCompletedJanaOrder();

        // Když někdo přepíše číslo účtenky
        Test.startTest();
        Database.SaveResult result = Database.update(new Order__c(Id = purchase.Id, Receipt_Number__c = 'KPK-001-999999'), false);
        Test.stopTest();

        // Pak se změna neuloží (stejnou účtenku by šlo naimportovat znovu a připsat podruhé)
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, null, 'Účtenka dokončeného nákupu se nesmí měnit.');
    }

    // R27 (ST-15, ST-13 přijaté riziko)
    @IsTest
    static void adminCanDeleteCompletedPurchase() {
        // Pokud Jana dokončila nákup a má za něj připsání 109 kapek
        Order__c purchase = createCompletedJanaOrder();
        Points_Transaction__c earn = KapkaTestDataFactory.makeTransaction(purchase.Loyalty_Member__c, TYPE_EARN, POSTED, JANA_EARN);
        earn.Order__c = purchase.Id;
        insert earn;

        // Když admin smaže celý nákup
        Test.startTest();
        Database.DeleteResult result = Database.delete(purchase, false);
        Test.stopTest();

        // Pak nákup i jeho položky zmizí a připsání zůstane v knize bez vazby na nákup
        Assert.isTrue(result.isSuccess(), 'Admin smí smazat celý dokončený nákup: ' + result.getErrors());
        Points_Transaction__c saved = [SELECT Order__c, Points__c FROM Points_Transaction__c WHERE Id = :earn.Id];
        Assert.areEqual(
            'null / 109',
            saved.Order__c + ' / ' + saved.Points__c.stripTrailingZeros().toPlainString(),
            'Připsání má po smazání nákupu zůstat v knize s prázdnou vazbou na nákup.'
        );
    }

    // R28
    @IsTest
    static void allocationOverRemainingPointsIsRejected() {
        // Pokud má Jana připsání 109 kapek a čerpání
        Points_Transaction__c earn = createJanaTransaction(TYPE_EARN, POSTED, JANA_EARN);
        Points_Transaction__c redeem = KapkaTestDataFactory.makeTransaction(earn.Loyalty_Member__c, TYPE_REDEEM, POSTED, -110);
        insert redeem;

        // Když se z připsání alokuje 110 kapek
        Test.startTest();
        Database.SaveResult result = Database.insert(KapkaTestDataFactory.makeAllocation(earn.Id, redeem.Id, 110), false);
        Test.stopTest();

        // Pak se alokace neuloží (zbývající kapky by klesly pod nulu)
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, null, 'Z připsání nejde vzít víc, než zbývá.');
    }

    // R28
    @IsTest
    static void allocationFromCancelledEarnIsRejected() {
        // Pokud má Jana zrušené připsání 109 kapek a čerpání
        Points_Transaction__c earn = createJanaTransaction(TYPE_EARN, 'Cancelled', JANA_EARN);
        Points_Transaction__c redeem = KapkaTestDataFactory.makeTransaction(earn.Loyalty_Member__c, TYPE_REDEEM, POSTED, -50);
        insert redeem;

        // Když se ze zrušeného připsání alokuje 50 kapek
        Test.startTest();
        Database.SaveResult result = Database.insert(KapkaTestDataFactory.makeAllocation(earn.Id, redeem.Id, 50), false);
        Test.stopTest();

        // Pak se alokace neuloží
        assertRejected(
            result,
            StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
            Points_Allocation__c.Credit_Transaction__c,
            'Brát jde jen ze zaúčtovaného připsání.'
        );
    }

    // R28
    @IsTest
    static void allocationUpToRemainingPointsIsAccepted() {
        // Pokud má Jana připsání 109 kapek a čerpání
        Points_Transaction__c earn = createJanaTransaction(TYPE_EARN, POSTED, JANA_EARN);
        Points_Transaction__c redeem = KapkaTestDataFactory.makeTransaction(earn.Loyalty_Member__c, TYPE_REDEEM, POSTED, -109);
        insert redeem;

        // Když se z připsání alokuje přesně 109 kapek
        Test.startTest();
        insert KapkaTestDataFactory.makeAllocation(earn.Id, redeem.Id, 109);
        Test.stopTest();

        // Pak z připsání nezbývá nic
        Assert.areEqual(
            0,
            [SELECT Remaining_Points__c FROM Points_Transaction__c WHERE Id = :earn.Id].Remaining_Points__c,
            'Alokace celého připsání má projít a nechat 0 kapek.'
        );
    }

    // R29
    @IsTest
    static void purchaseTakesAccountFromMember() {
        // Pokud je Jana členkou se svým osobním účtem
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);
        Fuel_Station__c station = KapkaTestDataFactory.createStation(STATION_NAME, STATION_CODE);
        List<Order__c> purchases = new List<Order__c>();
        for (Integer i = 0; i < 200; i++) {
            purchases.add(KapkaTestDataFactory.makeOrder(jana.Id, station.Id, RECEIPT + '-' + i));
        }

        // Když se jí zapíše 200 nákupů bez účtu
        Test.startTest();
        insert purchases;
        Test.stopTest();

        // Pak mají všechny nákupy účet Jany
        Assert.areEqual(
            200,
            [SELECT COUNT() FROM Order__c WHERE Account__c = :jana.Account__c],
            'Nákup bez účtu má převzít účet člena.'
        );
    }

    // R29
    @IsTest
    static void purchaseKeepsExplicitAccount() {
        // Pokud je Jana členkou a firma ENE Servis má vlastní účet
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);
        Account company = new Account(Name = 'ENE Servis s.r.o.');
        insert company;
        Order__c purchase = KapkaTestDataFactory.makeOrder(jana.Id, null, RECEIPT);
        purchase.Account__c = company.Id;

        // Když se zapíše nákup s účtem firmy
        Test.startTest();
        insert purchase;
        Test.stopTest();

        // Pak účet zůstane firmy
        Assert.areEqual(
            company.Id,
            [SELECT Account__c FROM Order__c WHERE Id = :purchase.Id].Account__c,
            'Vyplněný účet nákupu se nesmí přepsat účtem člena.'
        );
    }

    // R14
    @IsTest
    static void managerCanRecordPurchaseWithItems() {
        // Pokud loyalty manažer a produkt Natural 95 za 38 Kč
        User manager = KapkaTestDataFactory.createLoyaltyManager();
        Product2 natural = createNatural();

        // Když zapíše člena, nákup s položkou a připsání kapek
        Test.startTest();
        System.runAs(manager) {
            Account jana = KapkaTestDataFactory.createPersonAccount(JANA_FIRST, JANA_LAST);
            Loyalty_Member__c member = KapkaTestDataFactory.makeMember(jana.Id);
            Database.insert(member, AccessLevel.USER_MODE);
            Fuel_Station__c station = new Fuel_Station__c(Name = STATION_NAME, Station_Code__c = STATION_CODE);
            Database.insert(station, AccessLevel.USER_MODE);
            Order__c purchase = KapkaTestDataFactory.makeOrder(member.Id, station.Id, RECEIPT);
            Database.insert(purchase, AccessLevel.USER_MODE);
            Database.insert(KapkaTestDataFactory.makeOrderItem(purchase.Id, natural.Id, FUEL_LITERS), AccessLevel.USER_MODE);
            Points_Transaction__c earn = KapkaTestDataFactory.makeTransaction(member.Id, TYPE_EARN, POSTED, JANA_EARN);
            earn.Order__c = purchase.Id;
            Database.insert(earn, AccessLevel.USER_MODE);
        }
        Test.stopTest();

        // Pak má nákup 45 l paliva a k němu jedno připsání
        Order__c saved = [SELECT Fuel_Liters__c, (SELECT Id FROM Points_Transactions__r) FROM Order__c WHERE Receipt_Number__c = :RECEIPT];
        Assert.areEqual(
            '45 / 1',
            saved.Fuel_Liters__c.stripTrailingZeros().toPlainString() + ' / ' + saved.Points_Transactions__r.size(),
            'Loyalty manažer má s permission setem zapsat celý nákup i připsání.'
        );
    }

    // ---------- Review kolo 1: neměnnost knihy a snímku (ST-3, ST-4, ST-5, ST-6, ST-8) ----------

    // R15
    @IsTest
    static void cancelledTransactionCannotBePosted() {
        // Pokud má Jana zrušené čerpání 100 kapek
        Points_Transaction__c redeem = createJanaTransaction(TYPE_REDEEM, 'Cancelled', -100);

        // Když ho někdo přepne zpět na Zaúčtováno
        Test.startTest();
        Database.SaveResult result = Database.update(new Points_Transaction__c(Id = redeem.Id, Status__c = POSTED), false);
        Test.stopTest();

        // Pak se změna neuloží
        assertRejected(
            result,
            StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
            Points_Transaction__c.Status__c,
            'Zrušený pohyb se nesmí znovu zaúčtovat.'
        );
    }

    // R15
    @IsTest
    static void expirationDateCannotChange() {
        // Pokud má Jana připsání, které vyprší 6. 11. 2027
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);
        Points_Transaction__c earn = KapkaTestDataFactory.makeTransaction(jana.Id, TYPE_EARN, POSTED, JANA_EARN);
        earn.Expiration_Date__c = Date.newInstance(2027, 11, 6);
        insert earn;

        // Když někdo posune expiraci o rok
        Test.startTest();
        Database.SaveResult result = Database.update(
            new Points_Transaction__c(Id = earn.Id, Expiration_Date__c = Date.newInstance(2028, 11, 6)),
            false
        );
        Test.stopTest();

        // Pak se změna neuloží
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, null, 'Datum expirace se po vložení nesmí měnit.');
    }

    // R16
    @IsTest
    static void itemProductCannotChange() {
        // Pokud nákup obsahuje položku Natural 95
        Order_Item__c item = createNaturalItem();
        Product2 coffee = KapkaTestDataFactory.createProduct('Káva a bageta', OTHER, 180);

        // Když se u položky vymění produkt za kávu
        Test.startTest();
        Database.SaveResult result = Database.update(new Order_Item__c(Id = item.Id, Product__c = coffee.Id), false);
        Test.stopTest();

        // Pak se změna neuloží (cena a kategorie by patřily jinému produktu)
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, null, 'Produkt položky se po vložení nesmí měnit.');
    }

    // R16
    @IsTest
    static void itemSnapshotCannotBeOverwritten() {
        // Pokud nákup obsahuje položku Natural 95 za 38 Kč
        Order_Item__c item = createNaturalItem();

        // Když někdo ručně přepíše jednotkovou cenu na 1 Kč
        Test.startTest();
        Database.SaveResult result = Database.update(new Order_Item__c(Id = item.Id, Unit_Price__c = 1), false);
        Test.stopTest();

        // Pak se změna neuloží
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, null, 'Snímek ceny položky se nesmí přepsat.');
    }

    // R17
    @IsTest
    static void transactionWithoutTypeIsRejected() {
        // Pokud existuje členka Jana
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);

        // Když se založí pohyb kapek bez typu
        Test.startTest();
        Database.SaveResult result = Database.insert(KapkaTestDataFactory.makeTransaction(jana.Id, null, POSTED, 10), false);
        Test.stopTest();

        // Pak se pohyb neuloží
        assertRejected(result, StatusCode.REQUIRED_FIELD_MISSING, Points_Transaction__c.Type__c, 'Pohyb kapek musí mít typ.');
    }

    // R17
    @IsTest
    static void newTransactionIsPendingByDefault() {
        // Pokud existuje členka Jana
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember(JANA_FIRST, JANA_LAST);
        Points_Transaction__c earn = new Points_Transaction__c(
            Loyalty_Member__c = jana.Id,
            Type__c = TYPE_EARN,
            Points__c = JANA_EARN,
            Transaction_Date__c = KapkaTestDataFactory.DEFAULT_PURCHASE_DATE
        );

        // Když se založí pohyb bez stavu
        Test.startTest();
        insert earn;
        Test.stopTest();

        // Pak čeká na zaúčtování
        Assert.areEqual(
            'Pending',
            [SELECT Status__c FROM Points_Transaction__c WHERE Id = :earn.Id].Status__c,
            'Pohyb bez stavu má začínat jako Čeká.'
        );
    }

    // R18
    @IsTest
    static void cancelledEarnHasNoRemainingPoints() {
        // Když má Jana zrušené připsání 109 kapek
        Test.startTest();
        Points_Transaction__c earn = createJanaTransaction(TYPE_EARN, 'Cancelled', JANA_EARN);
        Test.stopTest();

        // Pak z něj nezbývá nic k čerpání ani k expiraci
        Points_Transaction__c saved = [SELECT Remaining_Points__c FROM Points_Transaction__c WHERE Id = :earn.Id];
        Assert.areEqual(0, saved.Remaining_Points__c, 'Zrušené připsání nesmí nabízet kapky k čerpání.');
    }

    // R20
    @IsTest
    static void activeProductWithoutFamilyIsRejected() {
        // Když se založí aktivní produkt s cenou, ale bez kategorie
        Product2 product = new Product2(Name = NATURAL_95, Price__c = FUEL_PRICE, IsActive = true);
        Test.startTest();
        Database.SaveResult result = Database.insert(product, false);
        Test.stopTest();

        // Pak se produkt neuloží (jeho položky by nepadly do paliva ani do ostatního)
        assertRejected(result, StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, Product2.Family, 'Aktivní produkt musí mít kategorii.');
    }
}
