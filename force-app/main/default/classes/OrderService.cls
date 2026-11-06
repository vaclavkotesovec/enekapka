/**
 * Služba nákupu: při vložení doplní účet nákupu z člena (rozhodnutí 6. 11. 2026, R29),
 * aby šly nákupy filtrovat a reportovat podle osoby nebo firmy bez průchodu přes člena.
 */
public with sharing class OrderService {
    /** Volá se z before insert; vyplněný účet nechá být (nákup může patřit jinému účtu, např. firmě). */
    public static void copyMemberAccount(List<Order__c> orders) {
        Set<Id> memberIds = new Set<Id>();
        for (Order__c purchase : orders) {
            if (purchase.Account__c == null && purchase.Loyalty_Member__c != null) {
                memberIds.add(purchase.Loyalty_Member__c);
            }
        }
        if (memberIds.isEmpty()) {
            return;
        }

        // SYSTEM_MODE záměrně: vazba na účet je integrita dat. Nákupy zakládá i pokladní import,
        // který nemusí vidět členy (sharing Private); výsledek musí být stejný pro každého.
        Map<Id, Loyalty_Member__c> members = new Map<Id, Loyalty_Member__c>(
            [SELECT Id, Account__c FROM Loyalty_Member__c WHERE Id IN :memberIds WITH SYSTEM_MODE]
        );
        for (Order__c purchase : orders) {
            Loyalty_Member__c member = members.get(purchase.Loyalty_Member__c);
            if (purchase.Account__c == null && member != null) {
                purchase.Account__c = member.Account__c;
            }
        }
    }
}
