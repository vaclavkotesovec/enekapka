/**
 * Kapky za aktivity a aktivace člena (karta aktivity, rozhodnutí A1–A6).
 * Udělený souhlas Loyalty (PartyConsent Opt In) aktivuje člena.
 */
public with sharing class KapkaActivityService {
    private static final String OPT_IN = 'OptIn';
    private static final String LOYALTY = 'Loyalty';
    private static final String REGISTERED = 'Registered';
    private static final String ACTIVE = 'Active';
    private static final String EARN = 'Earn';
    private static final String POSTED = 'Posted';
    private static final String SOURCE_PROFILE = 'Profile';
    private static final String SOURCE_CONSENT = 'Consent';
    private static final String MARKETING = 'Marketing';

    /** Volá trigger po insertu a updatu souhlasu; zpracuje jen souhlasy, které jsou nově Opt In. */
    public static void handleConsents(List<PartyConsent> records, Map<Id, PartyConsent> oldMap) {
        List<PartyConsent> granted = newlyGranted(records, oldMap);
        if (granted.isEmpty()) {
            return;
        }
        Map<Id, String> purposeNames = purposeNames(granted);
        Map<Id, Loyalty_Member__c> membersByIndividual = membersByIndividual(granted);

        Map<String, Kapka_Activity_Reward__mdt> rewards = rewardsBySource();
        Set<String> rewarded = rewardedActivities(membersByIndividual.values());

        Map<Id, Loyalty_Member__c> membersToUpdate = new Map<Id, Loyalty_Member__c>();
        List<Points_Transaction__c> credits = new List<Points_Transaction__c>();
        for (PartyConsent consent : granted) {
            Loyalty_Member__c member = membersByIndividual.get(consent.PartyId);
            if (member == null) {
                continue;
            }
            Datetime grantedAt = consent.CaptureDate == null ? Datetime.now() : consent.CaptureDate;
            Loyalty_Member__c touched = touch(membersToUpdate, member.Id, grantedAt.date());
            String purpose = purposeNames.get(consent.DataUsePurposeId);
            if (purpose == LOYALTY) {
                if (member.Status__c == REGISTERED) {
                    touched.Status__c = ACTIVE;
                }
                addOnce(credits, rewarded, member.Id, rewards.get(SOURCE_PROFILE), grantedAt);
            } else if (purpose == MARKETING) {
                addOnce(credits, rewarded, member.Id, rewards.get(SOURCE_CONSENT), grantedAt);
            }
        }
        // SYSTEM_MODE záměrně: souhlas zakládá i portálový uživatel, který na členy a knihu kapek
        // práva nemá; aktivaci a kapky generuje systém (stejný vzor jako KapkaEarnService).
        Database.update(membersToUpdate.values(), AccessLevel.SYSTEM_MODE);
        Database.insert(credits, AccessLevel.SYSTEM_MODE);
    }

    /** Každá aktivita nejvýš jednou za členství (A2): přeskoč, co člen už má nebo dostal v této dávce. */
    private static void addOnce(
        List<Points_Transaction__c> credits,
        Set<String> rewarded,
        Id memberId,
        Kapka_Activity_Reward__mdt reward,
        Datetime grantedAt
    ) {
        if (rewarded.add(activityKey(memberId, reward.Source__c))) {
            credits.add(credit(memberId, reward, grantedAt));
        }
    }

    /** Aktivity, za které už člen kapky dostal, jako klíče člen|zdroj. */
    private static Set<String> rewardedActivities(List<Loyalty_Member__c> members) {
        Set<String> rewarded = new Set<String>();
        for (Points_Transaction__c earned : [
            SELECT Loyalty_Member__c, Source__c
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c IN :members AND Type__c = :EARN AND Source__c IN (:SOURCE_PROFILE, :SOURCE_CONSENT)
            WITH SYSTEM_MODE
        ]) {
            rewarded.add(activityKey(earned.Loyalty_Member__c, earned.Source__c));
        }
        return rewarded;
    }

    private static String activityKey(Id memberId, String source) {
        return memberId + '|' + source;
    }

    /** Aktualizace člena: poslední aktivita = nejpozdější datum souhlasu v dávce (A6). */
    private static Loyalty_Member__c touch(Map<Id, Loyalty_Member__c> membersToUpdate, Id memberId, Date activityDate) {
        Loyalty_Member__c touched = membersToUpdate.get(memberId);
        if (touched == null) {
            touched = new Loyalty_Member__c(Id = memberId);
            membersToUpdate.put(memberId, touched);
        }
        if (touched.Last_Activity_Date__c == null || touched.Last_Activity_Date__c < activityDate) {
            touched.Last_Activity_Date__c = activityDate;
        }
        return touched;
    }

    /** Earn za aktivitu: hned zaúčtované, datum souhlasu, expirace podle metadat (A6). */
    private static Points_Transaction__c credit(Id memberId, Kapka_Activity_Reward__mdt reward, Datetime grantedAt) {
        Date expiresOn = reward.Expiration_Months__c == null
            ? null
            : grantedAt.date().addMonths(reward.Expiration_Months__c.intValue());
        return new Points_Transaction__c(
            Loyalty_Member__c = memberId,
            Type__c = EARN,
            Status__c = POSTED,
            Source__c = reward.Source__c,
            Base_Points__c = reward.Points__c,
            Points__c = reward.Points__c,
            Transaction_Date__c = grantedAt,
            Expiration_Date__c = expiresOn
        );
    }

    /** Částky za aktivity jsou data (A1): klíčem je Source__c. */
    private static Map<String, Kapka_Activity_Reward__mdt> rewardsBySource() {
        Map<String, Kapka_Activity_Reward__mdt> rewards = new Map<String, Kapka_Activity_Reward__mdt>();
        for (Kapka_Activity_Reward__mdt reward : Kapka_Activity_Reward__mdt.getAll().values()) {
            rewards.put(reward.Source__c, reward);
        }
        return rewards;
    }

    private static List<PartyConsent> newlyGranted(List<PartyConsent> records, Map<Id, PartyConsent> oldMap) {
        List<PartyConsent> granted = new List<PartyConsent>();
        for (PartyConsent consent : records) {
            Boolean wasOptIn = oldMap != null && oldMap.get(consent.Id).PrivacyConsentStatus == OPT_IN;
            if (consent.PrivacyConsentStatus == OPT_IN && !wasOptIn && consent.PartyId != null) {
                granted.add(consent);
            }
        }
        return granted;
    }

    private static Map<Id, String> purposeNames(List<PartyConsent> consents) {
        Set<Id> purposeIds = new Set<Id>();
        for (PartyConsent consent : consents) {
            purposeIds.add(consent.DataUsePurposeId);
        }
        Map<Id, String> names = new Map<Id, String>();
        for (DataUsePurpose purpose : [SELECT Id, Name FROM DataUsePurpose WHERE Id IN :purposeIds WITH SYSTEM_MODE]) {
            names.put(purpose.Id, purpose.Name);
        }
        return names;
    }

    /** Člen podle Individual: osoba přes Account.PersonIndividualId. */
    private static Map<Id, Loyalty_Member__c> membersByIndividual(List<PartyConsent> consents) {
        Set<Id> individualIds = new Set<Id>();
        for (PartyConsent consent : consents) {
            individualIds.add(consent.PartyId);
        }
        Map<Id, Loyalty_Member__c> members = new Map<Id, Loyalty_Member__c>();
        for (Loyalty_Member__c member : [
            SELECT Id, Status__c, Account__r.PersonIndividualId
            FROM Loyalty_Member__c
            WHERE Account__r.PersonIndividualId IN :individualIds
            WITH SYSTEM_MODE
        ]) {
            members.put(member.Account__r.PersonIndividualId, member);
        }
        return members;
    }
}
