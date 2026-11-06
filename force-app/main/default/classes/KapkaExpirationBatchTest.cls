/**
 * Karta bonus: expirace kapek po 1 roce.
 * Seam S1: Database.executeBatch(new KapkaExpirationBatch()), seam S2: KapkaExpirationBatch.scheduleNightly().
 */
@IsTest
private class KapkaExpirationBatchTest {
    private static final String EARN = 'Earn';
    private static final String REDEEM = 'Redeem';
    private static final String EXPIRE = 'Expire';
    private static final String POSTED = 'Posted';
    private static final String SOURCE_EXPIRATION = 'Expiration';

    // AC-1.1
    @IsTest
    static void expiredRemainderIsWrittenOff() {
        // Pokud Jana má připsání 100 kapek platné do včerejška, ze kterého utratila 30
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        Points_Transaction__c earn = createEarn(jana.Id, 100, Date.today().addDays(-1));
        spend(jana.Id, earn.Id, 30);

        // Když v noci proběhne expirace
        runExpiration();

        // Pak Janě propadne 70 kapek a má pohyb Expirace −70 kapek
        List<Points_Transaction__c> expirations = expirationsOf(jana.Id);
        Assert.isTrue(
            expirations.size() == 1 &&
                expirations[0].Points__c == -70 &&
                expirations[0].Status__c == POSTED &&
                expirations[0].Source__c == SOURCE_EXPIRATION &&
                remainingOf(earn.Id) == 0,
            'Janě má propadnout 70 kapek jedním zaúčtovaným pohybem Expirace, je: ' + expirations
        );
    }

    // AC-1.2
    @IsTest
    static void lastValidDayKeepsKapky() {
        // Pokud Jana má připsání 100 kapek platné do dneška
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        createEarn(jana.Id, 100, Date.today());

        // Když dnes proběhne expirace
        runExpiration();

        // Pak Janě nic nepropadne
        Assert.areEqual(0, expirationsOf(jana.Id).size(), 'V poslední den platnosti nesmí kapky propadnout.');
    }

    // AC-1.3
    @IsTest
    static void fullyConsumedPackageCreatesNoExpire() {
        // Pokud Jana má prošlé připsání 100 kapek, které celé utratila
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        Points_Transaction__c earn = createEarn(jana.Id, 100, Date.today().addDays(-1));
        spend(jana.Id, earn.Id, 100);

        // Když proběhne expirace
        runExpiration();

        // Pak Jana nemá žádný pohyb Expirace
        Assert.areEqual(0, expirationsOf(jana.Id).size(), 'Z vyčerpaného balíčku nemá nic propadnout.');
    }

    // AC-2.1
    @IsTest
    static void twoExpiredPackagesMakeOneExpire() {
        // Pokud Jana má dva prošlé balíčky se zbytky 20 a 30 kapek
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        Points_Transaction__c older = createEarn(jana.Id, 20, Date.today().addDays(-10));
        Points_Transaction__c newer = createEarn(jana.Id, 30, Date.today().addDays(-1));

        // Když proběhne expirace
        runExpiration();

        // Pak má Jana jeden pohyb Expirace −50 kapek a u každého balíčku je vidět, kolik z něj propadlo
        List<Points_Transaction__c> expirations = expirationsOf(jana.Id);
        Map<Id, Decimal> expiredByPackage = new Map<Id, Decimal>();
        for (Points_Allocation__c allocation : [
            SELECT Credit_Transaction__c, Points__c
            FROM Points_Allocation__c
            WHERE Debit_Transaction__r.Type__c = :EXPIRE
        ]) {
            expiredByPackage.put(allocation.Credit_Transaction__c, allocation.Points__c);
        }
        Assert.isTrue(
            expirations.size() == 1 &&
                expirations[0].Points__c == -50 &&
                expiredByPackage.get(older.Id) == 20 &&
                expiredByPackage.get(newer.Id) == 30,
            'Má vzniknout jedna Expirace −50 s alokacemi 20 a 30, je: ' + expirations + ' ' + expiredByPackage
        );
    }

    // AC-2.2
    @IsTest
    static void validKapkyStay() {
        // Pokud Jana má prošlý balíček se zbytkem 20 kapek a platný balíček 109 kapek
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        createEarn(jana.Id, 20, Date.today().addDays(-1));
        createEarn(jana.Id, 109, Date.today().addYears(1));

        // Když proběhne expirace
        runExpiration();

        // Pak má Jana zůstatek 109 kapek
        Assert.areEqual(109, balanceOf(jana.Id), 'Platné kapky mají Janě zůstat.');
    }

    // AC-2.3
    @IsTest
    static void secondRunWritesOffNothing() {
        // Pokud expirace už Janě prošlé kapky odepsala
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        Points_Transaction__c earn = createEarn(jana.Id, 100, Date.today().addDays(-1));
        Points_Transaction__c previousExpiration = KapkaTestDataFactory.makeTransaction(jana.Id, EXPIRE, POSTED, -100);
        previousExpiration.Source__c = SOURCE_EXPIRATION;
        insert previousExpiration;
        insert KapkaTestDataFactory.makeAllocation(earn.Id, previousExpiration.Id, 100);

        // Když proběhne expirace znovu
        runExpiration();

        // Pak se nic dalšího neodepíše
        Assert.areEqual(1, expirationsOf(jana.Id).size(), 'Opakovaný běh nesmí odepsat nic dalšího.');
    }

    // AC-3.1
    @IsTest
    static void expiringNextThirtyDaysIsRecalculated() {
        // Pokud Jana má balíček se zbytkem 40 kapek platný ještě 20 dnů a balíček 109 kapek platný ještě rok
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        createEarn(jana.Id, 40, Date.today().addDays(20));
        createEarn(jana.Id, 109, Date.today().addYears(1));

        // Když proběhne expirace
        runExpiration();

        // Pak má Jana u členství 40 kapek, které vyprší do 30 dnů
        Assert.areEqual(40, expiringSoonOf(jana.Id), 'Do 30 dnů má Janě vypršet 40 kapek.');
    }

    // AC-3.2
    @IsTest
    static void spentExpiringKapkyResetToZero() {
        // Pokud Jana měla u členství 40 kapek k expiraci a ty už utratila
        Loyalty_Member__c jana = KapkaTestDataFactory.makeMember(
            KapkaTestDataFactory.createPersonAccount('Jana', 'Nováková').Id
        );
        jana.Points_Expiring_Next_30_Days__c = 40;
        insert jana;
        Points_Transaction__c earn = createEarn(jana.Id, 40, Date.today().addDays(20));
        spend(jana.Id, earn.Id, 40);

        // Když proběhne expirace
        runExpiration();

        // Pak má Jana u členství 0 kapek k expiraci
        Assert.areEqual(0, expiringSoonOf(jana.Id), 'Utracené kapky už nemají vypršet.');
    }

    private static void runExpiration() {
        Test.startTest();
        Database.executeBatch(new KapkaExpirationBatch());
        Test.stopTest();
    }

    private static Points_Transaction__c createEarn(Id memberId, Decimal points, Date expirationDate) {
        Points_Transaction__c earn = KapkaTestDataFactory.makeTransaction(memberId, EARN, POSTED, points);
        earn.Expiration_Date__c = expirationDate;
        insert earn;
        return earn;
    }

    private static void spend(Id memberId, Id creditId, Decimal points) {
        Points_Transaction__c redemption = KapkaTestDataFactory.makeTransaction(memberId, REDEEM, POSTED, -points);
        insert redemption;
        insert KapkaTestDataFactory.makeAllocation(creditId, redemption.Id, points);
    }

    private static List<Points_Transaction__c> expirationsOf(Id memberId) {
        return [
            SELECT Points__c, Status__c, Source__c
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c = :memberId AND Type__c = :EXPIRE
        ];
    }

    private static Decimal balanceOf(Id memberId) {
        return [SELECT Points_Balance__c FROM Loyalty_Member__c WHERE Id = :memberId].Points_Balance__c;
    }

    private static Decimal expiringSoonOf(Id memberId) {
        return [SELECT Points_Expiring_Next_30_Days__c FROM Loyalty_Member__c WHERE Id = :memberId]
        .Points_Expiring_Next_30_Days__c;
    }

    private static Decimal remainingOf(Id earnId) {
        return [SELECT Remaining_Points__c FROM Points_Transaction__c WHERE Id = :earnId].Remaining_Points__c;
    }
}
