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

    private static void grant(Loyalty_Member__c member, DataUsePurpose purpose) {
        insert KapkaTestDataFactory.makeOptInConsent(individualOf(member), purpose);
    }

    private static Id individualOf(Loyalty_Member__c member) {
        return [SELECT Account__r.PersonIndividualId FROM Loyalty_Member__c WHERE Id = :member.Id].Account__r.PersonIndividualId;
    }
}
