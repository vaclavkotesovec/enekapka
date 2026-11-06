/**
 * Člen Kapka Klubu přihlášeného portálového uživatele – jediné místo, kde portál určuje „čí data“.
 *
 * without sharing: DEMO. Sharing sety pro portál mockujeme (Rozhodnutí Q6, Q15, P2), takže portálový
 * uživatel záznamy člena přes sharing nevidí. Bezpečnost drží to, že se vrací výhradně člen
 * navázaný na kontakt přihlášeného uživatele; Id člena nikdy nepřichází z klienta.
 */
public without sharing class KapkaPortalContext {
    /** Člen přihlášeného uživatele, nebo null, když uživatel členství nemá. */
    public static Loyalty_Member__c currentMember() {
        User current = [SELECT ContactId, Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() WITH SYSTEM_MODE];
        if (current.ContactId == null) {
            return null;
        }
        // Řidič firmy je na členovi jako Contact__c; osoba (Person Account) jako Account__c bez řidiče.
        List<Loyalty_Member__c> members = [
            SELECT Id, Account__c, Contact__c, Status__c, Points_Balance__c
            FROM Loyalty_Member__c
            WHERE Contact__c = :current.ContactId
                OR (Contact__c = NULL AND Account__c = :current.Contact.AccountId)
            WITH SYSTEM_MODE
            ORDER BY CreatedDate
            LIMIT 1
        ];
        return members.isEmpty() ? null : members[0];
    }
}
