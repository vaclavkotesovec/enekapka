/**
 * Karta aktivity: kapky za profil a souhlas, aktivace člena.
 * Seam S1 z plánu: DML insert / update PartyConsent (trigger).
 */
@IsTest
private class KapkaActivityServiceTest {
    private static final String ACTIVE = 'Active';
    private static final String EARN = 'Earn';
    private static final String POSTED = 'Posted';
    private static final String PROFILE = 'Profile';
    private static final String CONSENT = 'Consent';

    // AC-1.1
    @IsTest
    static void loyaltyConsentActivatesMember() {
        // Pokud registrovaná členka Jana Nováková
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');

        // Když Jana udělí souhlas s účastí v Kapka Klubu
        Test.startTest();
        insert KapkaTestDataFactory.makeOptInConsent(individualOf(jana), purposes.get(KapkaTestDataFactory.LOYALTY_PURPOSE));
        Test.stopTest();

        // Pak je Jana aktivní členkou
        Assert.areEqual(
            ACTIVE,
            [SELECT Status__c FROM Loyalty_Member__c WHERE Id = :jana.Id].Status__c,
            'Souhlas Loyalty má člena aktivovat.'
        );
    }

    // AC-2.1
    @IsTest
    static void loyaltyConsentGivesPersonHundredKapky() {
        // Pokud registrovaná členka Jana Nováková s vyplněným profilem
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');

        // Když Jana udělí souhlas s účastí v Kapka Klubu
        Test.startTest();
        grant(jana, purposes.get(KapkaTestDataFactory.LOYALTY_PURPOSE));
        Test.stopTest();

        // Pak má Jana připsáno 100 kapek za profil
        Points_Transaction__c credit = [
            SELECT Type__c, Status__c, Source__c, Points__c, Base_Points__c
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c = :jana.Id
        ];
        Assert.isTrue(
            credit.Type__c == EARN &&
                credit.Status__c == POSTED &&
                credit.Source__c == PROFILE &&
                credit.Points__c == 100 &&
                credit.Base_Points__c == 100,
            'Za vstup do programu má vzniknout jedno zaúčtované připsání 100 kapek za profil, vzniklo: ' + credit
        );
    }

    // AC-5.1
    @IsTest
    static void activityKapkyExpireTwelveMonthsAfterConsent() {
        // Pokud registrovaná členka Jana Nováková
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');

        // Když Jana 6. 11. 2026 udělí souhlas s účastí v Kapka Klubu
        Test.startTest();
        grant(jana, purposes.get(KapkaTestDataFactory.LOYALTY_PURPOSE));
        Test.stopTest();

        // Pak kapky za profil platí do 6. 11. 2027
        Points_Transaction__c credit = [
            SELECT Transaction_Date__c, Expiration_Date__c
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c = :jana.Id AND Source__c = :PROFILE
        ];
        Assert.isTrue(
            credit.Transaction_Date__c == KapkaTestDataFactory.DEFAULT_PURCHASE_DATE &&
                credit.Expiration_Date__c == Date.newInstance(2027, 11, 6),
            'Kapky za profil mají datum souhlasu 6. 11. 2026 a platí do 6. 11. 2027, vzniklo: ' + credit
        );
    }

    // AC-5.1
    @IsTest
    static void memberLastActivityIsConsentDate() {
        // Pokud registrovaná členka Jana Nováková
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');

        // Když Jana 6. 11. 2026 udělí souhlas s účastí v Kapka Klubu
        Test.startTest();
        grant(jana, purposes.get(KapkaTestDataFactory.LOYALTY_PURPOSE));
        Test.stopTest();

        // Pak poslední aktivita Jany je 6. 11. 2026
        Assert.areEqual(
            Date.newInstance(2026, 11, 6),
            [SELECT Last_Activity_Date__c FROM Loyalty_Member__c WHERE Id = :jana.Id].Last_Activity_Date__c,
            'Poslední aktivita člena je datum souhlasu.'
        );
    }

    // AC-3.1
    @IsTest
    static void marketingConsentGivesFiftyKapky() {
        // Pokud aktivní členka Jana Nováková
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        jana.Status__c = ACTIVE;
        update jana;

        // Když Jana udělí souhlas s marketingem
        Test.startTest();
        grant(jana, purposes.get(KapkaTestDataFactory.MARKETING_PURPOSE));
        Test.stopTest();

        // Pak má Jana připsáno 50 kapek za souhlas
        Points_Transaction__c credit = [
            SELECT Type__c, Status__c, Source__c, Points__c, Expiration_Date__c
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c = :jana.Id
        ];
        Assert.isTrue(
            credit.Type__c == EARN &&
                credit.Status__c == POSTED &&
                credit.Source__c == CONSENT &&
                credit.Points__c == 50 &&
                credit.Expiration_Date__c == Date.newInstance(2027, 11, 6),
            'Za souhlas s marketingem má vzniknout jedno zaúčtované připsání 50 kapek, vzniklo: ' + credit
        );
    }

    private static void grant(Loyalty_Member__c member, DataUsePurpose purpose) {
        insert KapkaTestDataFactory.makeOptInConsent(individualOf(member), purpose);
    }

    private static Id individualOf(Loyalty_Member__c member) {
        return [SELECT Account__r.PersonIndividualId FROM Loyalty_Member__c WHERE Id = :member.Id].Account__r.PersonIndividualId;
    }
}
