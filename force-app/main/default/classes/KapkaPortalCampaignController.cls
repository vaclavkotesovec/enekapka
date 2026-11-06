/**
 * Portál Kapka Klub – stránky Kampaně a aktivity a Profil (karta portal-kampane).
 *
 * without sharing: DEMO. Sharing sety pro portál mockujeme (Rozhodnutí Q6, P2). Každá metoda pracuje
 * výhradně s členem přihlášeného uživatele z KapkaPortalContext; Id člena ani účtu z klienta nepřijímá.
 */
public without sharing class KapkaPortalCampaignController {
    private static final String EARN = 'Earn';
    private static final String SOURCE_PROFILE = 'Profile';
    private static final String SOURCE_CONSENT = 'Consent';
    private static final String OPT_IN = 'OptIn';
    private static final String OPT_OUT = 'OptOut';
    private static final String CONSENT_ACTION = 'Data Collection';
    private static final String MARKETING_PURPOSE = 'Marketing';
    private static final String LOYALTY_PURPOSE = 'Loyalty';

    public class CampaignView {
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public Date validFrom;
        @AuraEnabled public Date validTo;
    }

    public class ActivityView {
        @AuraEnabled public String source;
        @AuraEnabled public Decimal points;
        @AuraEnabled public Boolean done;
    }

    public class ProfileView {
        @AuraEnabled public Boolean isPerson;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String phone;
        @AuraEnabled public Date birthdate;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String postalCode;
        @AuraEnabled public Boolean marketingConsent;
        @AuraEnabled public Boolean loyaltyConsent;
    }

    /** Kampaně aktivní a platné dnes (AC-1). Kampaně platí pro všechny členy, proto bez vazby na člena. */
    @AuraEnabled(cacheable=true)
    public static List<CampaignView> getActiveCampaigns() {
        Date today = Date.today();
        List<CampaignView> views = new List<CampaignView>();
        for (Loyalty_Campaign__c campaign : [
            SELECT Name, Description__c, Valid_From__c, Valid_To__c
            FROM Loyalty_Campaign__c
            WHERE Is_Active__c = TRUE AND Valid_From__c <= :today AND (Valid_To__c = NULL OR Valid_To__c >= :today)
            WITH SYSTEM_MODE
            ORDER BY Valid_From__c, Name
        ]) {
            CampaignView view = new CampaignView();
            view.name = campaign.Name;
            view.description = campaign.Description__c;
            view.validFrom = campaign.Valid_From__c;
            view.validTo = campaign.Valid_To__c;
            views.add(view);
        }
        return views;
    }

    /** Aktivity za kapky a jestli je člen splnil – podle připsání se zdrojem Profil / Souhlas (AC-2, A2). */
    @AuraEnabled
    public static List<ActivityView> getActivities() {
        Loyalty_Member__c member = KapkaPortalContext.currentMember();
        if (member == null) {
            return new List<ActivityView>();
        }
        Set<String> doneSources = new Set<String>();
        for (Points_Transaction__c earn : [
            SELECT Source__c
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c = :member.Id AND Type__c = :EARN AND Source__c IN (:SOURCE_PROFILE, :SOURCE_CONSENT) WITH SYSTEM_MODE]) {
            doneSources.add(earn.Source__c);
        }
        Map<String, Decimal> rewards = activityRewards();
        List<ActivityView> views = new List<ActivityView>();
        for (String source : new List<String>{ SOURCE_PROFILE, SOURCE_CONSENT }) {
            ActivityView view = new ActivityView();
            view.source = source;
            view.points = rewards.get(source);
            view.done = doneSources.contains(source);
            views.add(view);
        }
        return views;
    }

    /** Profil a souhlasy osoby; firemní členové profil v portálu neupravují (P4). */
    @AuraEnabled
    public static ProfileView getProfile() {
        ProfileView view = new ProfileView();
        Account person = currentPersonAccount();
        view.isPerson = person != null;
        if (person == null) {
            return view;
        }
        view.firstName = person.FirstName;
        view.lastName = person.LastName;
        view.phone = person.Phone;
        view.birthdate = person.PersonBirthdate;
        view.street = person.PersonMailingStreet;
        view.city = person.PersonMailingCity;
        view.postalCode = person.PersonMailingPostalCode;
        Map<String, PartyConsent> consents = latestConsents(person.PersonIndividualId);
        view.marketingConsent = isOptIn(consents.get(MARKETING_PURPOSE));
        view.loyaltyConsent = isOptIn(consents.get(LOYALTY_PURPOSE));
        return view;
    }

    /** Uloží kontaktní údaje osoby (AC-4). Jméno a souhlasy se tudy nemění. */
    @AuraEnabled
    public static void saveProfile(ProfileView profile) {
        Account person = requirePersonAccount();
        person.Phone = profile.phone;
        person.PersonBirthdate = profile.birthdate;
        person.PersonMailingStreet = profile.street;
        person.PersonMailingCity = profile.city;
        person.PersonMailingPostalCode = profile.postalCode;
        Database.update(person, AccessLevel.SYSTEM_MODE);
    }

    /**
     * Udělí nebo odvolá souhlas s účelem Marketing / Loyalty (AC-3). Existující souhlas se přepne
     * (Opt In ↔ Opt Out), jinak vznikne nový. Kapky za souhlas připisuje trigger z karty aktivity.
     */
    @AuraEnabled
    public static void setConsent(String purposeName, Boolean optIn) {
        if (purposeName != MARKETING_PURPOSE && purposeName != LOYALTY_PURPOSE) {
            throw new AuraHandledException(System.Label.Kapka_Portal_UnknownConsent);
        }
        Account person = requirePersonAccount();
        String status = optIn == true ? OPT_IN : OPT_OUT;
        PartyConsent existing = latestConsents(person.PersonIndividualId).get(purposeName);
        if (existing != null) {
            existing.PrivacyConsentStatus = status;
            existing.CaptureDate = Datetime.now();
            Database.update(existing, AccessLevel.SYSTEM_MODE);
            return;
        }
        DataUsePurpose purpose = [SELECT Id, Name FROM DataUsePurpose WHERE Name = :purposeName WITH SYSTEM_MODE
            LIMIT 1];
        Database.insert(new PartyConsent(
            Name = purpose.Name + ' – ' + status,
            PartyId = person.PersonIndividualId,
            DataUsePurposeId = purpose.Id,
            Action = CONSENT_ACTION,
            PrivacyConsentStatus = status,
            CaptureDate = Datetime.now()
        ), AccessLevel.SYSTEM_MODE);
    }

    private static Account currentPersonAccount() {
        Loyalty_Member__c member = KapkaPortalContext.currentMember();
        if (member == null || member.Contact__c != null) {
            return null;
        }
        List<Account> accounts = [
            SELECT Id, FirstName, LastName, Phone, PersonBirthdate, PersonMailingStreet, PersonMailingCity,
                PersonMailingPostalCode, PersonIndividualId
            FROM Account
            WHERE Id = :member.Account__c AND IsPersonAccount = TRUE WITH SYSTEM_MODE];
        return accounts.isEmpty() ? null : accounts[0];
    }

    private static Account requirePersonAccount() {
        Account person = currentPersonAccount();
        if (person == null) {
            throw new AuraHandledException(System.Label.Kapka_Portal_ProfileOnlyPerson);
        }
        return person;
    }

    /** Poslední souhlas osoby pro každý účel (klíčem je název účelu). */
    private static Map<String, PartyConsent> latestConsents(Id individualId) {
        Map<String, PartyConsent> byPurpose = new Map<String, PartyConsent>();
        if (individualId == null) {
            return byPurpose;
        }
        for (PartyConsent consent : [
            SELECT Id, PrivacyConsentStatus, DataUsePurpose.Name
            FROM PartyConsent
            WHERE PartyId = :individualId AND DataUsePurpose.Name IN (:MARKETING_PURPOSE, :LOYALTY_PURPOSE)
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
        ]) {
            if (!byPurpose.containsKey(consent.DataUsePurpose.Name)) {
                byPurpose.put(consent.DataUsePurpose.Name, consent);
            }
        }
        return byPurpose;
    }

    private static Boolean isOptIn(PartyConsent consent) {
        return consent != null && consent.PrivacyConsentStatus == OPT_IN;
    }

    /**
     * Kapky za aktivity z Custom Metadata Kapka_Activity_Reward__mdt (karta aktivity, A1).
     * Dynamický dotaz, aby portál šel nasadit i před kartou aktivity; bez metadat jsou kapky prázdné.
     */
    private static Map<String, Decimal> activityRewards() {
        Map<String, Decimal> rewards = new Map<String, Decimal>();
        try {
            for (SObject reward : Database.query('SELECT Source__c, Points__c FROM Kapka_Activity_Reward__mdt', AccessLevel.SYSTEM_MODE)) {
                rewards.put((String) reward.get('Source__c'), (Decimal) reward.get('Points__c'));
            }
        } catch (QueryException missingMetadata) {
            // Kapka_Activity_Reward__mdt ještě není nasazený (karta aktivity) – aktivity se ukážou bez kapek.
        }
        return rewards;
    }
}
