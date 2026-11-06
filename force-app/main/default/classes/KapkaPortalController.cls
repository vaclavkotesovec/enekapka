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
        @AuraEnabled
        public Decimal expiringSoon;
    }

    /** Řádek historie kapek v portálu (karta portal-zustatek, AC-3). */
    public class HistoryRow {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public Datetime transactionDate;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public String reason;
        @AuraEnabled
        public Decimal points;
    }

    private static final Integer HISTORY_LIMIT = 50;
    private static final String CANCELLED = 'Cancelled';

    @AuraEnabled(cacheable=true)
    public static MemberView getCurrentMember() {
        Id memberId = requireMemberId();
        Loyalty_Member__c member = [
            SELECT Account__r.Name, Contact__r.Name, toLabel(Status__c), Points_Balance__c, Points_Expiring_Next_30_Days__c
            FROM Loyalty_Member__c
            WHERE Id = :memberId
            WITH SYSTEM_MODE
        ];
        MemberView view = new MemberView();
        view.name = member.Contact__c != null ? member.Contact__r.Name : member.Account__r.Name;
        view.status = member.Status__c;
        view.balance = member.Points_Balance__c == null ? 0 : member.Points_Balance__c;
        view.expiringSoon = member.Points_Expiring_Next_30_Days__c == null ? 0 : member.Points_Expiring_Next_30_Days__c;
        return view;
    }

    /** Posledních 50 nezrušených pohybů kapek člena od nejnovějšího, s důvodem složeným na serveru. */
    @AuraEnabled(cacheable=true)
    public static List<HistoryRow> getHistory() {
        Id memberId = requireMemberId();
        List<HistoryRow> rows = new List<HistoryRow>();
        for (Points_Transaction__c tx : [
            SELECT
                Id,
                Transaction_Date__c,
                toLabel(Type__c),
                toLabel(Source__c),
                Reason__c,
                Points__c,
                Order__r.Fuel_Station__c,
                Order__r.Fuel_Station__r.Name,
                (SELECT Loyalty_Campaign__r.Name FROM Applied_Campaigns__r ORDER BY CreatedDate, Id),
                (SELECT Reward__r.Name FROM Vouchers__r LIMIT 1)
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c = :memberId AND Status__c != :CANCELLED
            WITH SYSTEM_MODE
            ORDER BY Transaction_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT :HISTORY_LIMIT
        ]) {
            HistoryRow row = new HistoryRow();
            row.id = tx.Id;
            row.transactionDate = tx.Transaction_Date__c;
            row.type = tx.Type__c;
            row.reason = reasonOf(tx);
            row.points = tx.Points__c;
            rows.add(row);
        }
        return rows;
    }

    /** Důvod: nákup → stanice a kampaně; čerpání → odměna voucheru; jinak důvod pohybu nebo zdroj. */
    private static String reasonOf(Points_Transaction__c tx) {
        List<String> parts = new List<String>();
        if (tx.Order__c != null && tx.Order__r.Fuel_Station__c != null) {
            parts.add(tx.Order__r.Fuel_Station__r.Name);
        }
        for (Applied_Campaign__c applied : tx.Applied_Campaigns__r) {
            parts.add(applied.Loyalty_Campaign__r.Name);
        }
        for (Voucher__c voucher : tx.Vouchers__r) {
            parts.add(voucher.Reward__r.Name);
        }
        if (parts.isEmpty()) {
            return String.isNotBlank(tx.Reason__c) ? tx.Reason__c : tx.Source__c;
        }
        return String.join(parts, ', ');
    }

    private static Id requireMemberId() {
        Id memberId = resolveMemberId();
        if (memberId == null) {
            AuraHandledException noMember = new AuraHandledException(Label.Kapka_Portal_NoMember);
            noMember.setMessage(Label.Kapka_Portal_NoMember);
            throw noMember;
        }
        return memberId;
    }

    /** Člen přihlášeného uživatele: přednostně podle kontaktu (řidič firmy), jinak podle účtu (osoba). Bez člena null. */
    public static Id resolveMemberId() {
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
