@IsTest
private class KapkaPortalCampaignControllerTest {
    private static final String FULL_TANK = 'Natankuj plnou';
    private static final String ROAD_STOP = 'Zastávka na cestě';
    private static final String SUMMER_RIDE = 'Letní jízda';
    private static final String WINTER_DRAFT = 'Zimní koncept';
    private static final String NEW_PHONE = '+420 777 123 456';

    @IsTest
    static void onlyCampaignsValidTodayAreShown() {
        // Pokud
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        Loyalty_Campaign__c fullTank = activeCampaign(FULL_TANK);
        Loyalty_Campaign__c roadStop = activeCampaign(ROAD_STOP);
        Loyalty_Campaign__c summerRide = activeCampaign(SUMMER_RIDE);
        summerRide.Valid_To__c = Date.today().addDays(-1);
        Loyalty_Campaign__c winterDraft = activeCampaign(WINTER_DRAFT);
        winterDraft.Is_Active__c = false;
        insert new List<Loyalty_Campaign__c>{ fullTank, roadStop, summerRide, winterDraft };

        // Když
        List<KapkaPortalCampaignController.CampaignView> shown;
        System.runAs(jana) {
            Test.startTest();
            shown = KapkaPortalCampaignController.getActiveCampaigns();
            Test.stopTest();
        }

        // Pak
        Set<String> names = new Set<String>();
        for (KapkaPortalCampaignController.CampaignView campaign : shown) {
            names.add(campaign.name);
        }
        Assert.areEqual(new Set<String>{ FULL_TANK, ROAD_STOP }, names, 'Jen kampaně aktivní a platné dnes');
    }

    @IsTest
    static void activitiesShowDoneByKapkySource() {
        // Pokud
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        Loyalty_Member__c member = KapkaTestDataFactory.memberOf(jana);
        Points_Transaction__c profileEarn = KapkaTestDataFactory.makeTransaction(member.Id, 'Earn', 'Posted', 100);
        profileEarn.Source__c = 'Profile';
        insert profileEarn;

        // Když
        Map<String, Boolean> doneBySource = new Map<String, Boolean>();
        System.runAs(jana) {
            Test.startTest();
            for (KapkaPortalCampaignController.ActivityView activity : KapkaPortalCampaignController.getActivities()) {
                doneBySource.put(activity.source, activity.done);
            }
            Test.stopTest();
        }

        // Pak
        Assert.areEqual(
            new Map<String, Boolean>{ 'Profile' => true, 'Consent' => false },
            doneBySource,
            'Profil splněný, souhlas s marketingem ne'
        );
    }

    @IsTest
    static void enablingMarketingConsentCreatesOptIn() {
        // Pokud
        KapkaTestDataFactory.createDataUsePurposes();
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');

        // Když
        System.runAs(jana) {
            Test.startTest();
            KapkaPortalCampaignController.setConsent(KapkaTestDataFactory.MARKETING_PURPOSE, true);
            Test.stopTest();
        }

        // Pak
        Assert.areEqual('OptIn', marketingConsentStatus(jana), 'Souhlas s marketingem je Opt In');
    }

    @IsTest
    static void withdrawingConsentRecordsOptOutAndKeepsKapky() {
        // Pokud
        Map<String, DataUsePurpose> purposes = KapkaTestDataFactory.createDataUsePurposes();
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        Loyalty_Member__c member = KapkaTestDataFactory.memberOf(jana);
        insert KapkaTestDataFactory.makeOptInConsent(
            individualOf(jana),
            purposes.get(KapkaTestDataFactory.MARKETING_PURPOSE)
        );
        Points_Transaction__c consentEarn = KapkaTestDataFactory.makeTransaction(member.Id, 'Earn', 'Posted', 50);
        consentEarn.Source__c = 'Consent';
        insert consentEarn;
        Decimal balanceBefore = balanceOf(member.Id);

        // Když
        System.runAs(jana) {
            Test.startTest();
            KapkaPortalCampaignController.setConsent(KapkaTestDataFactory.MARKETING_PURPOSE, false);
            Test.stopTest();
        }

        // Pak
        Assert.areEqual(
            'OptOut|' + balanceBefore,
            marketingConsentStatus(jana) + '|' + balanceOf(member.Id),
            'Souhlas je Opt Out a kapky zůstaly'
        );
    }

    @IsTest
    static void memberUpdatesOwnPhone() {
        // Pokud
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');

        // Když
        System.runAs(jana) {
            Test.startTest();
            KapkaPortalCampaignController.ProfileView profile = KapkaPortalCampaignController.getProfile();
            profile.phone = NEW_PHONE;
            KapkaPortalCampaignController.saveProfile(profile);
            Test.stopTest();
        }

        // Pak
        Assert.areEqual(
            NEW_PHONE,
            [SELECT Phone FROM Account WHERE Id = :KapkaTestDataFactory.memberOf(jana).Account__c].Phone,
            'Jana má na účtu nový telefon'
        );
    }

    @IsTest
    static void userWithoutMembershipSeesNoActivities() {
        // Pokud
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        delete KapkaTestDataFactory.memberOf(jana);

        // Když
        List<KapkaPortalCampaignController.ActivityView> activities;
        System.runAs(jana) {
            Test.startTest();
            activities = KapkaPortalCampaignController.getActivities();
            Test.stopTest();
        }

        // Pak
        Assert.isTrue(activities.isEmpty(), 'Bez členství nejsou žádné aktivity');
    }

    private static Loyalty_Campaign__c activeCampaign(String name) {
        Loyalty_Campaign__c campaign = KapkaTestDataFactory.makeCampaign(name, 'Min Fuel Liters', 40, 'Fixed Points', 50);
        campaign.Valid_From__c = Date.today().addDays(-30);
        return campaign;
    }

    private static Decimal balanceOf(Id memberId) {
        return [SELECT Points_Balance__c FROM Loyalty_Member__c WHERE Id = :memberId].Points_Balance__c;
    }

    private static Id individualOf(User portalUser) {
        Id accountId = KapkaTestDataFactory.memberOf(portalUser).Account__c;
        return [SELECT PersonIndividualId FROM Account WHERE Id = :accountId].PersonIndividualId;
    }

    private static String marketingConsentStatus(User portalUser) {
        List<PartyConsent> consents = [
            SELECT PrivacyConsentStatus
            FROM PartyConsent
            WHERE PartyId = :individualOf(portalUser) AND DataUsePurpose.Name = :KapkaTestDataFactory.MARKETING_PURPOSE
            ORDER BY LastModifiedDate DESC
        ];
        return consents.isEmpty() ? null : consents[0].PrivacyConsentStatus;
    }
}
