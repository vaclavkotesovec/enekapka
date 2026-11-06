/**
 * Kapky za aktivity a aktivace člena (karta aktivity, rozhodnutí A1–A6).
 * Udělený souhlas Loyalty (PartyConsent Opt In) aktivuje člena.
 */
public with sharing class KapkaActivityService {
    private static final String OPT_IN = 'OptIn';
    private static final String LOYALTY = 'Loyalty';
    private static final String REGISTERED = 'Registered';
    private static final String ACTIVE = 'Active';

    /** Volá trigger po insertu a updatu souhlasu; zpracuje jen souhlasy, které jsou nově Opt In. */
    public static void handleConsents(List<PartyConsent> records, Map<Id, PartyConsent> oldMap) {
        List<PartyConsent> granted = newlyGranted(records, oldMap);
        if (granted.isEmpty()) {
            return;
        }
        Map<Id, String> purposeNames = purposeNames(granted);
        Map<Id, Loyalty_Member__c> membersByIndividual = membersByIndividual(granted);

        Map<Id, Loyalty_Member__c> membersToUpdate = new Map<Id, Loyalty_Member__c>();
        for (PartyConsent consent : granted) {
            Loyalty_Member__c member = membersByIndividual.get(consent.PartyId);
            if (member == null) {
                continue;
            }
            if (purposeNames.get(consent.DataUsePurposeId) == LOYALTY && member.Status__c == REGISTERED) {
                membersToUpdate.put(member.Id, new Loyalty_Member__c(Id = member.Id, Status__c = ACTIVE));
            }
        }
        // SYSTEM_MODE záměrně: souhlas zakládá i portálový uživatel, který na členy a knihu kapek
        // práva nemá; aktivaci a kapky generuje systém (stejný vzor jako KapkaEarnService).
        Database.update(membersToUpdate.values(), AccessLevel.SYSTEM_MODE);
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
