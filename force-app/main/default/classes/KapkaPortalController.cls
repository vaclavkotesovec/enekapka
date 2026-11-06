/**
 * Data portálu pro přihlášeného člena. Každá metoda portálu bere člena z resolveMemberId() (AC-3.2).
 *
 * without sharing a SYSTEM_MODE záměrně (P2, Q6): sdílení a oprávnění pro portál pro demo mockujeme,
 * člen portálu na objekty Kapka Klubu práva nemá. Izolaci dat zajišťuje, že controller pracuje
 * jen s členem přihlášeného uživatele.
 */
public without sharing class KapkaPortalController {
    public class MemberView {
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Decimal balance;
    }

    @AuraEnabled(cacheable=true)
    public static MemberView getCurrentMember() {
        Id memberId = resolveMemberId();
        if (memberId == null) {
            AuraHandledException noMember = new AuraHandledException(Label.Kapka_Portal_NoMember);
            noMember.setMessage(Label.Kapka_Portal_NoMember);
            throw noMember;
        }
        Loyalty_Member__c member = [
            SELECT Account__r.Name, Contact__r.Name, toLabel(Status__c), Points_Balance__c
            FROM Loyalty_Member__c
            WHERE Id = :memberId
            WITH SYSTEM_MODE
        ];
        MemberView view = new MemberView();
        view.name = member.Contact__c != null ? member.Contact__r.Name : member.Account__r.Name;
        view.status = member.Status__c;
        view.balance = member.Points_Balance__c;
        return view;
    }

    /** Člen přihlášeného uživatele: přednostně podle kontaktu (řidič firmy), jinak podle účtu (osoba). */
    private static Id resolveMemberId() {
        User user = [SELECT ContactId, AccountId FROM User WHERE Id = :UserInfo.getUserId() WITH SYSTEM_MODE];
        Id contactId = user.ContactId;
        Id accountId = user.AccountId;
        if (contactId == null) {
            return null;
        }
        List<Loyalty_Member__c> candidates = [
            SELECT Id, Contact__c
            FROM Loyalty_Member__c
            WHERE Contact__c = :contactId OR Account__c = :accountId
            WITH SYSTEM_MODE
        ];
        Id byAccount;
        for (Loyalty_Member__c member : candidates) {
            if (member.Contact__c == contactId) {
                return member.Id;
            }
            byAccount = member.Id;
        }
        return byAccount;
    }
}
