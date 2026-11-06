/**
 * Karta bonus: ruční úprava kapek. Seam S1: KapkaAdjustPointsAction.adjust pod uživatelem
 * s permission setem Kapka_Points_Adjuster nebo bez něj. Hodnoty z akceptačních kritérií.
 */
@IsTest
private class KapkaAdjustPointsActionTest {
    private static final Datetime DEMO_NOW = Datetime.newInstance(2026, 11, 6, 10, 0, 0);
    private static final String EARN = 'Earn';
    private static final String POSTED = 'Posted';
    private static final String MANUAL = 'Manual';

    private static User createAdjuster() {
        User adjuster = KapkaTestDataFactory.createLoyaltyManager();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new PermissionSetAssignment(
                AssigneeId = adjuster.Id,
                PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Kapka_Points_Adjuster'].Id
            );
        }
        return adjuster;
    }

    /** Aktivní členka Jana s balíčky kapek: platnost → kapky. */
    private static Loyalty_Member__c createJana(Map<Date, Decimal> packages) {
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        jana.Status__c = 'Active';
        update jana;
        List<Points_Transaction__c> credits = new List<Points_Transaction__c>();
        for (Date expiration : packages.keySet()) {
            Points_Transaction__c credit = KapkaTestDataFactory.makeTransaction(jana.Id, EARN, POSTED, packages.get(expiration));
            credit.Expiration_Date__c = expiration;
            credits.add(credit);
        }
        insert credits;
        return jana;
    }

    private static KapkaAdjustPointsAction.Request request(Id memberId, Decimal points, String reason) {
        KapkaAdjustPointsAction.Request request = new KapkaAdjustPointsAction.Request();
        request.memberId = memberId;
        request.points = points;
        request.reason = reason;
        return request;
    }

    /** Spustí úpravu pod uživatelem a vrátí chybovou hlášku, nebo null, když úprava prošla. */
    private static String adjustAs(User user, Id memberId, Decimal points, String reason) {
        String error;
        System.runAs(user) {
            try {
                KapkaAdjustPointsAction.adjust(new List<KapkaAdjustPointsAction.Request>{ request(memberId, points, reason) });
            } catch (KapkaAdjustPointsException e) {
                error = e.getMessage();
            }
        }
        return error;
    }

    /** Spustí dávku úprav pod uživatelem a vrátí chybovou hlášku, nebo null, když dávka prošla. */
    private static String adjustAllAs(User user, List<KapkaAdjustPointsAction.Request> requests) {
        String error;
        System.runAs(user) {
            try {
                KapkaAdjustPointsAction.adjust(requests);
            } catch (KapkaAdjustPointsException e) {
                error = e.getMessage();
            }
        }
        return error;
    }

    private static Decimal balanceOf(Id memberId) {
        return [SELECT Points_Balance__c FROM Loyalty_Member__c WHERE Id = :memberId].Points_Balance__c;
    }

    /** Ruční připsání založené přímo, mimo akci Upravit kapky. */
    private static Points_Transaction__c manualEarn(Id memberId, String reason) {
        Points_Transaction__c earn = KapkaTestDataFactory.makeTransaction(memberId, EARN, POSTED, 100);
        earn.Source__c = MANUAL;
        earn.Reason__c = reason;
        earn.Expiration_Date__c = Date.newInstance(2027, 11, 6);
        return earn;
    }

    /** Založí pohyb přímo pod uživatelem (user mode) a vrátí kód první chyby a pole, nebo null. */
    private static String insertDirectlyAs(User user, Points_Transaction__c movement) {
        Database.SaveResult result;
        System.runAs(user) {
            result = Database.insert(movement, false, AccessLevel.USER_MODE);
        }
        return result.isSuccess() ? null : result.getErrors()[0].getStatusCode() + ' ' + result.getErrors()[0].getFields();
    }

    /** Člen patří manažerovi, aby ho směl editovat (pohyb pod člena chce zápis do rodiče). */
    private static void giveMemberTo(Loyalty_Member__c member, User owner) {
        member.OwnerId = owner.Id;
        update member;
    }

    // AC-3.1
    @IsTest
    static void plusAdjustmentCreatesSpendableManualEarn() {
        // Pokud Jana má 0 kapek
        User adjuster = createAdjuster();
        Loyalty_Member__c jana = createJana(new Map<Date, Decimal>());
        Reward__c reward = KapkaTestDataFactory.makeReward(KapkaTestDataFactory.createPartner('EneServis, s.r.o.').Id, 'Mytí zdarma', 100);
        insert reward;
        KapkaAdjustPointsAction.now = DEMO_NOW;

        // Když jí loyalty manažer 6. 11. 2026 přidá 100 kapek s důvodem „Reklamace myčky“
        Test.startTest();
        String error = adjustAs(adjuster, jana.Id, 100, 'Reklamace myčky');
        Test.stopTest();

        // Pak má Jana 100 kapek s původem Ručně a důvodem, platí do 6. 11. 2027 a jde je uplatnit
        Points_Transaction__c earn = [
            SELECT Points__c, Source__c, Reason__c, Expiration_Date__c
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c = :jana.Id
        ];
        Voucher__c voucher = KapkaRedeemService.redeem(jana.Id, reward.Id);
        Assert.areEqual(
            'null / 100 / Manual / Reklamace myčky / 2027-11-06 / true',
            error + ' / ' + earn.Points__c + ' / ' + earn.Source__c + ' / ' + earn.Reason__c + ' / ' +
            String.valueOf(earn.Expiration_Date__c) + ' / ' + (voucher.Id != null),
            'Přidané kapky mají být ruční připsání s důvodem, platné 12 měsíců a utratitelné.'
        );
    }

    // AC-2.1
    @IsTest
    static void adjustmentWithoutReasonFails() {
        // Pokud loyalty manažer s oprávněním k úpravám
        User adjuster = createAdjuster();
        Loyalty_Member__c jana = createJana(new Map<Date, Decimal>());

        // Když přidá Janě 100 kapek bez důvodu
        Test.startTest();
        String error = adjustAs(adjuster, jana.Id, 100, '  ');
        Test.stopTest();

        // Pak se úprava neuloží a manažer vidí, že musí vyplnit důvod
        Assert.areEqual(
            Label.Kapka_Adjust_Reason_Required + ' / 0',
            error + ' / ' + [SELECT COUNT() FROM Points_Transaction__c WHERE Loyalty_Member__c = :jana.Id],
            'Úprava bez důvodu se nesmí uložit.'
        );
    }

    // AC-1.1 (logika; viditelnost akce ověří ruční test S2)
    @IsTest
    static void userWithoutPermissionCannotAdjust() {
        // Pokud loyalty manažer bez oprávnění k úpravám
        User manager = KapkaTestDataFactory.createLoyaltyManager();
        Loyalty_Member__c jana = createJana(new Map<Date, Decimal>());

        // Když se pokusí přidat Janě kapky
        Test.startTest();
        String error = adjustAs(manager, jana.Id, 100, 'Reklamace myčky');
        Test.stopTest();

        // Pak se úprava neuloží
        Assert.areEqual(
            Label.Kapka_Adjust_No_Permission + ' / 0',
            error + ' / ' + [SELECT COUNT() FROM Points_Transaction__c WHERE Loyalty_Member__c = :jana.Id],
            'Bez custom permission Kapka_Adjust_Points se kapky upravit nesmí.'
        );
    }

    // AC-4.1
    @IsTest
    static void minusAdjustmentTakesEarliestExpiringFirst() {
        // Pokud Jana má balíček 50 kapek platný do 1. 2. 2027 a 109 kapek platný do 6. 11. 2027
        User adjuster = createAdjuster();
        Date earlier = Date.newInstance(2027, 2, 1);
        Date later = Date.newInstance(2027, 11, 6);
        Loyalty_Member__c jana = createJana(new Map<Date, Decimal>{ later => 109, earlier => 50 });

        // Když jí loyalty manažer ubere 60 kapek s důvodem „Chybně naimportovaný nákup“
        Test.startTest();
        String error = adjustAs(adjuster, jana.Id, -60, 'Chybně naimportovaný nákup');
        Test.stopTest();

        // Pak má Jana 99 kapek a z balíčku do 1. 2. 2027 se vzalo 50 a z druhého 10
        List<String> taken = new List<String>();
        for (Points_Allocation__c allocation : [
            SELECT Points__c, Credit_Transaction__r.Expiration_Date__c
            FROM Points_Allocation__c
            WHERE Debit_Transaction__r.Loyalty_Member__c = :jana.Id
            ORDER BY Credit_Transaction__r.Expiration_Date__c
        ]) {
            taken.add(String.valueOf(allocation.Credit_Transaction__r.Expiration_Date__c) + ': ' + allocation.Points__c);
        }
        Assert.areEqual(
            'null / 99 / 2027-02-01: 50, 2027-11-06: 10',
            error + ' / ' + balanceOf(jana.Id) + ' / ' + String.join(taken, ', '),
            'Ubrané kapky se berou od balíčku, který vyprší nejdřív.'
        );
    }

    // AC-4.2
    @IsTest
    static void minusOverBalanceFails() {
        // Pokud Jana má 40 kapek
        User adjuster = createAdjuster();
        Loyalty_Member__c jana = createJana(new Map<Date, Decimal>{ Date.newInstance(2027, 11, 6) => 40 });

        // Když jí loyalty manažer ubere 60 kapek s důvodem „Oprava“
        Test.startTest();
        String error = adjustAs(adjuster, jana.Id, -60, 'Oprava');
        Test.stopTest();

        // Pak se úprava neuloží a manažer vidí hlášku „Člen má jen 40 kapek.“
        Assert.areEqual('Člen má jen 40 kapek. / 40', error + ' / ' + balanceOf(jana.Id), 'Ubrat víc, než člen má, nejde.');
    }

    // AC-5.1 (data; zobrazení historie ověří ruční test S2)
    @IsTest
    static void adjustmentKeepsReasonSourceAndAuthor() {
        // Pokud loyalty manažer Janě upravil kapky
        User adjuster = createAdjuster();
        Loyalty_Member__c jana = createJana(new Map<Date, Decimal>{ Date.newInstance(2027, 11, 6) => 109 });
        KapkaAdjustPointsAction.now = DEMO_NOW;

        Test.startTest();
        adjustAs(adjuster, jana.Id, -9, 'Oprava');
        Test.stopTest();

        // Když se podívá do historie pohybů, pak vidí úpravu s kapkami, důvodem, datem a kdo ji udělal
        Points_Transaction__c adjustment = [
            SELECT Type__c, Source__c, Points__c, Reason__c, Transaction_Date__c, CreatedById
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c = :jana.Id AND Type__c = 'Adjustment'
        ];
        Assert.areEqual(
            'Manual / -9 / Oprava / ' + DEMO_NOW + ' / true',
            adjustment.Source__c + ' / ' + adjustment.Points__c + ' / ' + adjustment.Reason__c + ' / ' +
            adjustment.Transaction_Date__c + ' / ' + (adjustment.CreatedById == adjuster.Id),
            'Úprava má nést zdroj Ručně, kapky, důvod, datum a autora.'
        );
    }

    // AC-1 (review SP-1): oprávnění nejde obejít přímým založením pohybu
    @IsTest
    static void managerWithoutPermissionCannotInsertManualMovementDirectly() {
        // Pokud loyalty manažer bez oprávnění k úpravám může editovat členku Janu
        User manager = KapkaTestDataFactory.createLoyaltyManager();
        Loyalty_Member__c jana = createJana(new Map<Date, Decimal>());
        giveMemberTo(jana, manager);

        // Když jí přímo (mimo akci Upravit kapky) založí ruční připsání 100 kapek s důvodem
        Test.startTest();
        String error = insertDirectlyAs(manager, manualEarn(jana.Id, 'Reklamace myčky'));
        Test.stopTest();

        // Pak se pohyb neuloží kvůli validaci
        Assert.areEqual('FIELD_CUSTOM_VALIDATION_EXCEPTION ()', error, 'Ruční pohyb smí založit jen uživatel s oprávněním k úpravám.');
    }

    // AC-2 (review SP-1): důvod hlídá i přímé založení ručního pohybu
    @IsTest
    static void manualMovementWithoutReasonIsRejected() {
        // Pokud loyalty manažer s oprávněním k úpravám může editovat členku Janu
        User adjuster = createAdjuster();
        Loyalty_Member__c jana = createJana(new Map<Date, Decimal>());
        giveMemberTo(jana, adjuster);

        // Když jí přímo založí ruční připsání bez důvodu
        Test.startTest();
        String error = insertDirectlyAs(adjuster, manualEarn(jana.Id, null));
        Test.stopTest();

        // Pak se pohyb neuloží a chyba ukazuje na pole Důvod
        Assert.areEqual('FIELD_CUSTOM_VALIDATION_EXCEPTION (Reason__c)', error, 'Ruční pohyb musí mít důvod.');
    }

    // AC-4 (review ST-1): dva odpisy jednoho člena v jedné dávce nesmí přečerpat balíček
    @IsTest
    static void twoDebitsForOneMemberInOneCallFail() {
        // Pokud Jana má 40 kapek
        User adjuster = createAdjuster();
        Loyalty_Member__c jana = createJana(new Map<Date, Decimal>{ Date.newInstance(2027, 11, 6) => 40 });

        // Když jí loyalty manažer v jedné dávce ubere dvakrát 30 kapek
        Test.startTest();
        String error = adjustAllAs(
            adjuster,
            new List<KapkaAdjustPointsAction.Request>{ request(jana.Id, -30, 'Oprava 1'), request(jana.Id, -30, 'Oprava 2') }
        );
        Test.stopTest();

        // Pak se nic neuloží, Jana má dál 40 kapek a manažer vidí hlášku
        Assert.areEqual(
            Label.Kapka_Adjust_Multiple_Debits + ' / 40',
            error + ' / ' + balanceOf(jana.Id),
            'Víc odpisů jednoho člena v jedné dávce se musí odmítnout.'
        );
    }

    private static Integer movementCountOf(Id memberId) {
        return [SELECT COUNT() FROM Points_Transaction__c WHERE Loyalty_Member__c = :memberId];
    }

    // Hranice 0 kapek (review ST-2, rozhodnutí v plánu)
    @IsTest
    static void zeroPointsAdjustmentFails() {
        // Pokud loyalty manažer s oprávněním k úpravám
        User adjuster = createAdjuster();
        Loyalty_Member__c jana = createJana(new Map<Date, Decimal>());

        // Když Janě upraví kapky o 0
        Test.startTest();
        String error = adjustAs(adjuster, jana.Id, 0, 'Oprava');
        Test.stopTest();

        // Pak se nic neuloží a manažer vidí hlášku
        Assert.areEqual(
            Label.Kapka_Adjust_Zero_Points + ' / 0',
            error + ' / ' + movementCountOf(jana.Id),
            'Úprava o 0 kapek se nesmí uložit.'
        );
    }

    // Jen celé kapky (review ST-3; Points__c má 0 desetinných míst)
    @IsTest
    static void fractionalPointsAdjustmentFails() {
        // Pokud loyalty manažer s oprávněním k úpravám
        User adjuster = createAdjuster();
        Loyalty_Member__c jana = createJana(new Map<Date, Decimal>());

        // Když Janě přidá 10,5 kapky
        Test.startTest();
        String error = adjustAs(adjuster, jana.Id, 10.5, 'Oprava');
        Test.stopTest();

        // Pak se nic neuloží a manažer vidí, že kapky jsou jen celé
        Assert.areEqual(
            Label.Kapka_Adjust_Whole_Points + ' / 0',
            error + ' / ' + movementCountOf(jana.Id),
            'Necelé kapky se nesmí uložit.'
        );
    }

}
