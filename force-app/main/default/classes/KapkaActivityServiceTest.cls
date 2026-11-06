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
    private static final String OPT_IN = 'OptIn';
    private static final String OPT_OUT = 'OptOut';
    private static final Integer BULK_SIZE = 200;

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

    // AC-3.2
    @IsTest
    static void registeredMemberGetsMarketingKapky() {
        // Pokud registrovaná členka Jana Nováková
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');

        // Když Jana udělí souhlas s marketingem
        Test.startTest();
        grant(jana, purposes.get(KapkaTestDataFactory.MARKETING_PURPOSE));
        Test.stopTest();

        // Pak má Jana připsáno 50 kapek za souhlas
        Assert.areEqual(50, pointsOf(jana.Id, CONSENT), 'Kapky za marketing se připíší i registrovanému členovi (A3).');
    }

    // AC-4.1
    @IsTest
    static void bothConsentsAtOnceActivateAndGiveHundredFifty() {
        // Pokud registrovaná členka Jana Nováková
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        Id individualId = individualOf(jana);

        // Když Jana udělí najednou souhlas s účastí i s marketingem
        Test.startTest();
        insert new List<PartyConsent>{
            KapkaTestDataFactory.makeOptInConsent(individualId, purposes.get(KapkaTestDataFactory.LOYALTY_PURPOSE)),
            KapkaTestDataFactory.makeOptInConsent(individualId, purposes.get(KapkaTestDataFactory.MARKETING_PURPOSE))
        };
        Test.stopTest();

        // Pak je Jana aktivní členkou a má připsáno 150 kapek
        Loyalty_Member__c result = [SELECT Status__c FROM Loyalty_Member__c WHERE Id = :jana.Id];
        Decimal total = pointsOf(jana.Id, PROFILE) + pointsOf(jana.Id, CONSENT);
        Assert.isTrue(
            result.Status__c == ACTIVE && total == 150,
            'Oba souhlasy najednou: aktivní člen se 150 kapkami, je: ' + result.Status__c + ', ' + total + ' kapek'
        );
    }

    // AC-2.3, AC-3.4
    @IsTest
    static void repeatedConsentEarnsNothing() {
        // Pokud členka Jana, která už dostala kapky za profil i za marketing a oba souhlasy odvolala
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        Id individualId = individualOf(jana);
        List<PartyConsent> consents = new List<PartyConsent>{
            KapkaTestDataFactory.makeOptInConsent(individualId, purposes.get(KapkaTestDataFactory.LOYALTY_PURPOSE)),
            KapkaTestDataFactory.makeOptInConsent(individualId, purposes.get(KapkaTestDataFactory.MARKETING_PURPOSE))
        };
        insert consents;
        setStatus(consents, OPT_OUT);

        // Když Jana udělí oba souhlasy znovu
        Test.startTest();
        setStatus(consents, OPT_IN);
        Test.stopTest();

        // Pak se žádné další kapky nepřipíší
        Assert.areEqual(
            150,
            pointsOf(jana.Id, PROFILE) + pointsOf(jana.Id, CONSENT),
            'Každá aktivita se odmění nejvýš jednou za členství (A2).'
        );
    }

    // AC-3.5
    @IsTest
    static void optOutKeepsKapky() {
        // Pokud členka Jana, která dostala 50 kapek za marketing
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        List<PartyConsent> consents = new List<PartyConsent>{
            KapkaTestDataFactory.makeOptInConsent(individualOf(jana), purposes.get(KapkaTestDataFactory.MARKETING_PURPOSE))
        };
        insert consents;

        // Když Jana souhlas s marketingem odvolá
        Test.startTest();
        setStatus(consents, OPT_OUT);
        Test.stopTest();

        // Pak má Jana pořád 50 kapek
        Assert.areEqual(50, pointsOf(jana.Id, CONSENT), 'Odvolání souhlasu kapky nebere (A2).');
    }

    // AC-2.2, AC-3.3
    @IsTest
    static void companyDriverConsents() {
        // Pokud registrovaný firemní člen s řidičem
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        Account company = KapkaTestDataFactory.createCompany('Doprava Morava s.r.o.');
        Contact driver = KapkaTestDataFactory.createDriver(company.Id, 'Petr', 'Svoboda');
        Loyalty_Member__c member = KapkaTestDataFactory.makeMember(company.Id);
        member.Contact__c = driver.Id;
        insert member;

        // Když řidič udělí souhlas s účastí v Kapka Klubu i s marketingem
        Test.startTest();
        insert new List<PartyConsent>{
            KapkaTestDataFactory.makeOptInConsent(driver.IndividualId, purposes.get(KapkaTestDataFactory.LOYALTY_PURPOSE)),
            KapkaTestDataFactory.makeOptInConsent(driver.IndividualId, purposes.get(KapkaTestDataFactory.MARKETING_PURPOSE))
        };
        Test.stopTest();

        // Pak je člen aktivní, kapky za profil se nepřipíší a za souhlas má 50 kapek
        Loyalty_Member__c result = [SELECT Status__c FROM Loyalty_Member__c WHERE Id = :member.Id];
        Decimal profilePoints = pointsOf(member.Id, PROFILE);
        Decimal consentPoints = pointsOf(member.Id, CONSENT);
        Assert.isTrue(
            result.Status__c == ACTIVE && profilePoints == 0 && consentPoints == 50,
            'Firma: aktivní, 0 kapek za profil, 50 za souhlas; je: ' + result.Status__c + ', ' + profilePoints + ', ' + consentPoints
        );
    }

    // AC-6.1, AC-6.2
    @IsTest
    static void noMemberOrDeclinedConsentEarnsNothing() {
        // Pokud osoba, která není členem, a registrovaná členka Jana Nováková
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        DataUsePurpose marketing = purposes.get(KapkaTestDataFactory.MARKETING_PURPOSE);
        Account outsider = KapkaTestDataFactory.createPersonAccount('Karel', 'Dvořák');
        Loyalty_Member__c jana = KapkaTestDataFactory.createMember('Jana', 'Nováková');
        PartyConsent declined = KapkaTestDataFactory.makeOptInConsent(individualOf(jana), marketing);
        declined.PrivacyConsentStatus = OPT_OUT;

        // Když nečlen udělí souhlas s marketingem a Jana ho odmítne
        Test.startTest();
        insert new List<PartyConsent>{
            KapkaTestDataFactory.makeOptInConsent(
                [SELECT PersonIndividualId FROM Account WHERE Id = :outsider.Id].PersonIndividualId,
                marketing
            ),
            declined
        };
        Test.stopTest();

        // Pak se žádné kapky nepřipíší
        Assert.areEqual(0, [SELECT COUNT() FROM Points_Transaction__c], 'Bez členství nebo bez udělení se nic nepřipíše.');
    }

    // R11: bulk
    @IsTest
    static void twoHundredConsentsInOneTransaction() {
        // Pokud 200 registrovaných členů
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        List<Loyalty_Member__c> members = KapkaTestDataFactory.createPersonMembers('Hromadná', BULK_SIZE);
        List<PartyConsent> consents = new List<PartyConsent>();
        for (Loyalty_Member__c member : [
            SELECT Account__r.PersonIndividualId
            FROM Loyalty_Member__c
            WHERE Id IN :members
        ]) {
            consents.add(
                KapkaTestDataFactory.makeOptInConsent(
                    member.Account__r.PersonIndividualId,
                    purposes.get(KapkaTestDataFactory.LOYALTY_PURPOSE)
                )
            );
        }

        // Když všichni udělí souhlas s účastí v jedné transakci
        Test.startTest();
        insert consents;
        Test.stopTest();

        // Pak je všech 200 aktivních a každý má 100 kapek za profil
        Integer activeCount = [SELECT COUNT() FROM Loyalty_Member__c WHERE Id IN :members AND Status__c = :ACTIVE];
        Integer creditCount = [
            SELECT COUNT()
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c IN :members AND Source__c = :PROFILE AND Points__c = 100
        ];
        Assert.isTrue(
            activeCount == BULK_SIZE && creditCount == BULK_SIZE,
            'Všech 200 členů má být aktivních se 100 kapkami; aktivních ' + activeCount + ', připsání ' + creditCount
        );
    }

    private static void setStatus(List<PartyConsent> consents, String status) {
        for (PartyConsent consent : consents) {
            consent.PrivacyConsentStatus = status;
        }
        update consents;
    }

    private static Decimal pointsOf(Id memberId, String source) {
        AggregateResult total = [
            SELECT SUM(Points__c) points
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c = :memberId AND Source__c = :source
        ];
        Decimal points = (Decimal) total.get('points');
        return points == null ? 0 : points;
    }

    private static void grant(Loyalty_Member__c member, DataUsePurpose purpose) {
        insert KapkaTestDataFactory.makeOptInConsent(individualOf(member), purpose);
    }

    private static Id individualOf(Loyalty_Member__c member) {
        return [SELECT Account__r.PersonIndividualId FROM Loyalty_Member__c WHERE Id = :member.Id].Account__r.PersonIndividualId;
    }
}
