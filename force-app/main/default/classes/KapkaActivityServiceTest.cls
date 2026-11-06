/**
 * Karta aktivity: kapky za profil a souhlas, aktivace člena.
 * Seam S1 z plánu: DML insert / update PartyConsent (trigger).
 */
@IsTest
private class KapkaActivityServiceTest {
    private static final String ACTIVE = 'Active';

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

    private static Id individualOf(Loyalty_Member__c member) {
        return [SELECT Account__r.PersonIndividualId FROM Loyalty_Member__c WHERE Id = :member.Id].Account__r.PersonIndividualId;
    }
}
