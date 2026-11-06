/**
 * Karta winback: připomínka neaktivním členům.
 * Seam S1: Database.executeBatch(new KapkaWinbackBatch()) nad členy vloženými DML, assert na Winback_Date__c.
 */
@IsTest
private class KapkaWinbackBatchTest {
    private static final String ACTIVE = 'Active';
    private static final String REGISTERED = 'Registered';
    private static final String NIGHTLY_AT_HALF_PAST_THREE = '0 30 3 * * ?';

    // AC-1.1
    @IsTest
    static void memberInactive30DaysGetsWinback() {
        // Pokud aktivní člen má poslední aktivitu před 30 dny
        Loyalty_Member__c jana = createMember('Nováková', ACTIVE, Date.today().addDays(-30), null);

        // Když proběhne noční kontrola neaktivních členů
        runWinback();

        // Pak mu je odeslána připomínka
        Assert.areEqual(Date.today(), winbackDateOf(jana.Id), 'Člen 30 dní bez aktivity má dostat připomínku.');
    }

    // AC-1.2
    @IsTest
    static void memberActiveWithin29DaysIsSkipped() {
        // Pokud aktivní člen má poslední aktivitu před 29 dny
        Loyalty_Member__c jana = createMember('Nováková', ACTIVE, Date.today().addDays(-29), null);

        // Když proběhne noční kontrola neaktivních členů
        runWinback();

        // Pak členovi žádná připomínka nepřijde
        Assert.isNull(winbackDateOf(jana.Id), 'Člen s aktivitou před 29 dny připomínku dostat nemá.');
    }

    // AC-1.3, otevřená otázka 1
    @IsTest
    static void onlyActiveMembersGetWinback() {
        // Pokud člen ve stavu Registrován nemá aktivitu 45 dní a aktivní člen nikdy nenakoupil
        Loyalty_Member__c registered = createMember('Registrovaná', REGISTERED, Date.today().addDays(-45), null);
        Loyalty_Member__c neverBought = createMember('Nenakoupila', ACTIVE, null, null);

        // Když proběhne noční kontrola neaktivních členů
        runWinback();

        // Pak žádný z nich připomínku nedostane
        Assert.isTrue(
            winbackDateOf(registered.Id) == null && winbackDateOf(neverBought.Id) == null,
            'Neaktivní členství ani člen bez aktivity připomínku dostat nemají.'
        );
    }

    // AC-2.1
    @IsTest
    static void winbackOncePerInactivePeriod() {
        // Pokud člen už dostal připomínku po své poslední aktivitě
        Date reminded = Date.today().addDays(-5);
        Loyalty_Member__c jana = createMember('Nováková', ACTIVE, Date.today().addDays(-40), reminded);

        // Když proběhne noční kontrola neaktivních členů
        runWinback();

        // Pak mu další připomínka nepřijde
        Assert.areEqual(reminded, winbackDateOf(jana.Id), 'Za jedno období nečinnosti jen jedna připomínka.');
    }

    // AC-2.2
    @IsTest
    static void returningMemberCanGetWinbackAgain() {
        // Pokud člen po připomínce znovu natankoval a od té doby uplynulo 30 dní
        Loyalty_Member__c jana = createMember(
            'Nováková',
            ACTIVE,
            Date.today().addDays(-30),
            Date.today().addDays(-60)
        );

        // Když proběhne noční kontrola neaktivních členů
        runWinback();

        // Pak mu přijde nová připomínka
        Assert.areEqual(Date.today(), winbackDateOf(jana.Id), 'Člen, který se vrátil a zase zmizel, dostane novou připomínku.');
    }

    // W4
    @IsTest
    static void scheduleNightlyPlansJob() {
        Test.startTest();
        Id jobId = KapkaWinbackBatch.scheduleNightly();
        Test.stopTest();

        CronTrigger job = [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual(NIGHTLY_AT_HALF_PAST_THREE, job.CronExpression, 'Kontrola má běžet každou noc ve 3:30.');
    }

    private static Loyalty_Member__c createMember(String lastName, String status, Date lastActivity, Date winback) {
        Loyalty_Member__c member = KapkaTestDataFactory.makeMember(
            KapkaTestDataFactory.createPersonAccount('Jana', lastName).Id
        );
        member.Status__c = status;
        member.Last_Activity_Date__c = lastActivity;
        member.Winback_Date__c = winback;
        insert member;
        return member;
    }

    private static void runWinback() {
        Test.startTest();
        Database.executeBatch(new KapkaWinbackBatch());
        Test.stopTest();
    }

    private static Date winbackDateOf(Id memberId) {
        return [SELECT Winback_Date__c FROM Loyalty_Member__c WHERE Id = :memberId].Winback_Date__c;
    }
}
