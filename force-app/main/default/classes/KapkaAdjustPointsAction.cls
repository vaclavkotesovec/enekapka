/**
 * Ruční úprava kapek z akce „Upravit kapky“ na členovi (karta bonus: ruční úprava kapek).
 * Kniha kapek je neměnná, takže úprava vždy zapíše nový pohyb se zdrojem Ručně a důvodem:
 * plus = připsání (Earn) platné 12 měsíců, aby šlo utratit; minus = úprava (Adjustment)
 * s FIFO alokací přes KapkaPointsLedger, sdílenou s čerpáním a expirací (M3).
 */
public with sharing class KapkaAdjustPointsAction {
    private static final String ADJUST_PERMISSION = 'Kapka_Adjust_Points';
    private static final String EARN = 'Earn';
    private static final String ADJUSTMENT = 'Adjustment';
    private static final String POSTED = 'Posted';
    private static final String SOURCE_MANUAL = 'Manual';
    private static final Integer KAPKY_VALIDITY_MONTHS = 12;

    public class Request {
        @InvocableVariable(label='Člen' required=true)
        public Id memberId;
        @InvocableVariable(label='Kapky (+ přidat, − ubrat)' required=true)
        public Decimal points;
        @InvocableVariable(label='Důvod')
        public String reason;
    }

    /** Hodiny pro testy: datum úpravy určuje i expiraci přidaných kapek. */
    @TestVisible
    private static Datetime now = null;

    /**
     * Zapíše úpravy kapek; vrací Id vzniklých pohybů ve stejném pořadí jako požadavky.
     * @throws KapkaAdjustPointsException s hláškou pro manažera; nic se neuloží
     */
    @InvocableMethod(label='Upravit kapky' description='Ručně přidá nebo ubere kapky členovi s důvodem.')
    public static List<Id> adjust(List<Request> requests) {
        if (!FeatureManagement.checkPermission(ADJUST_PERMISSION)) {
            throw new KapkaAdjustPointsException(Label.Kapka_Adjust_No_Permission);
        }
        for (Request request : requests) {
            validate(request);
        }
        rejectRepeatedDebits(requests);
        Savepoint beforeAdjust = Database.setSavepoint();
        try {
            return write(requests);
        } catch (Exception e) {
            Database.rollback(beforeAdjust);
            throw e;
        }
    }

    private static void validate(Request request) {
        if (String.isBlank(request.reason)) {
            throw new KapkaAdjustPointsException(Label.Kapka_Adjust_Reason_Required);
        }
        if (request.points == null || request.points == 0) {
            throw new KapkaAdjustPointsException(Label.Kapka_Adjust_Zero_Points);
        }
    }

    /**
     * Odpisy jednoho člena v jedné dávce by se porovnaly se stejným zůstatkem a alokovaly ze stejných
     * zbytků balíčků (Remaining_Points__c je vzorec, v paměti se nesníží), takže se dávka odmítne celá.
     */
    private static void rejectRepeatedDebits(List<Request> requests) {
        Set<Id> debitedMembers = new Set<Id>();
        for (Request request : requests) {
            if (request.points < 0 && !debitedMembers.add(request.memberId)) {
                throw new KapkaAdjustPointsException(Label.Kapka_Adjust_Multiple_Debits);
            }
        }
    }

    private static List<Id> write(List<Request> requests) {
        Datetime adjustedAt = now != null ? now : System.now();
        Set<Id> debitedMembers = new Set<Id>();
        for (Request request : requests) {
            if (request.points < 0) {
                debitedMembers.add(request.memberId);
            }
        }
        Map<Id, List<Points_Transaction__c>> creditsByMember = new Map<Id, List<Points_Transaction__c>>();
        if (!debitedMembers.isEmpty()) {
            KapkaPointsLedger.lockMembers(debitedMembers);
            creditsByMember = KapkaPointsLedger.creditsByMember(debitedMembers);
        }

        List<Points_Transaction__c> movements = new List<Points_Transaction__c>();
        for (Request request : requests) {
            movements.add(request.points > 0 ? manualEarn(request, adjustedAt) : manualDebit(request, adjustedAt, creditsByMember));
        }
        LedgerWriter writer = new LedgerWriter();
        writer.insertAll(movements);

        List<Points_Allocation__c> allocations = new List<Points_Allocation__c>();
        for (Integer i = 0; i < requests.size(); i++) {
            Request request = requests[i];
            if (request.points < 0) {
                allocations.addAll(
                    KapkaPointsLedger.allocateFifo(creditsOf(creditsByMember, request.memberId), movements[i].Id, -request.points)
                );
            }
        }
        writer.insertAll(allocations);

        List<Id> movementIds = new List<Id>();
        for (Points_Transaction__c movement : movements) {
            movementIds.add(movement.Id);
        }
        return movementIds;
    }

    /** Přidané kapky jsou připsání, protože čerpání a expirace berou kapky jen z připsání. */
    private static Points_Transaction__c manualEarn(Request request, Datetime adjustedAt) {
        Points_Transaction__c earn = movement(request, EARN, adjustedAt);
        earn.Expiration_Date__c = adjustedAt.date().addMonths(KAPKY_VALIDITY_MONTHS);
        return earn;
    }

    private static Points_Transaction__c manualDebit(
        Request request,
        Datetime adjustedAt,
        Map<Id, List<Points_Transaction__c>> creditsByMember
    ) {
        Decimal available = KapkaPointsLedger.remainingPoints(creditsOf(creditsByMember, request.memberId));
        if (-request.points > available) {
            throw new KapkaAdjustPointsException(String.format(Label.Kapka_Adjust_Insufficient, new List<Object>{ available }));
        }
        return movement(request, ADJUSTMENT, adjustedAt);
    }

    private static Points_Transaction__c movement(Request request, String type, Datetime adjustedAt) {
        return new Points_Transaction__c(
            Loyalty_Member__c = request.memberId,
            Type__c = type,
            Status__c = POSTED,
            Source__c = SOURCE_MANUAL,
            Points__c = request.points,
            Reason__c = request.reason.trim(),
            Transaction_Date__c = adjustedAt
        );
    }

    /**
     * without sharing záměrně: členové jsou Private a manažer má na cizí členy jen čtení (view all),
     * pohyb pod člena (master-detail) ale vyžaduje zápis do rodiče. Kniha se mění jen tady,
     * až po kontrole custom permission Kapka_Adjust_Points v adjust(). SYSTEM_MODE explicitně:
     * v tomhle orgu Apex DML jinak vynucuje oprávnění uživatele (viz karta model-jadro).
     */
    private without sharing class LedgerWriter {
        void insertAll(List<SObject> records) {
            Database.insert(records, AccessLevel.SYSTEM_MODE);
        }
    }

    private static List<Points_Transaction__c> creditsOf(Map<Id, List<Points_Transaction__c>> creditsByMember, Id memberId) {
        List<Points_Transaction__c> credits = creditsByMember.get(memberId);
        return credits != null ? credits : new List<Points_Transaction__c>();
    }
}
