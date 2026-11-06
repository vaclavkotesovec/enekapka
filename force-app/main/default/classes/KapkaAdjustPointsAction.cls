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
    /** Délka pole Points_Transaction__c.Reason__c. */
    private static final Integer REASON_MAX_LENGTH = 255;
    /** Ukončené členství (rozhodnutí v plánu): kapky se neupravují; Registrován, Aktivní a Pozastaven ano. */
    private static final String MEMBER_CLOSED = 'Closed';
    private static final String LOCK_TIMEOUT = 'UNABLE_TO_LOCK_ROW';
    private static final String LOCK_TIMEOUT_QUERY = 'Record Currently Unavailable';

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
            if (isLockTimeout(e)) {
                throw new KapkaAdjustPointsException(Label.Kapka_Adjust_Member_Locked);
            }
            throw e;
        }
    }

    /** Člena právě upravuje jiná transakce a zámek (FOR UPDATE nebo DML) nedočkal. */
    private static Boolean isLockTimeout(Exception e) {
        if (e instanceof DmlException) {
            return ((DmlException) e).getDmlType(0) == StatusCode.UNABLE_TO_LOCK_ROW;
        }
        return e instanceof QueryException &&
            (e.getMessage().contains(LOCK_TIMEOUT) || e.getMessage().contains(LOCK_TIMEOUT_QUERY));
    }

    private static void validate(Request request) {
        if (String.isBlank(request.reason)) {
            throw new KapkaAdjustPointsException(Label.Kapka_Adjust_Reason_Required);
        }
        if (request.reason.trim().length() > REASON_MAX_LENGTH) {
            throw new KapkaAdjustPointsException(Label.Kapka_Adjust_Reason_Too_Long);
        }
        if (request.points == null || request.points == 0) {
            throw new KapkaAdjustPointsException(Label.Kapka_Adjust_Zero_Points);
        }
        // Points__c má 0 desetinných míst: necelé kapky by se při uložení zaokrouhlily jinak než v alokaci.
        if (request.points != request.points.round(System.RoundingMode.DOWN)) {
            throw new KapkaAdjustPointsException(Label.Kapka_Adjust_Whole_Points);
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
        Set<Id> memberIds = new Set<Id>();
        Set<Id> debitedMembers = new Set<Id>();
        for (Request request : requests) {
            memberIds.add(request.memberId);
            if (request.points < 0) {
                debitedMembers.add(request.memberId);
            }
        }
        // Zamyká i členy s přidáním: jejich zůstatek (roll-up) se mění stejně, a ověří se tím existence a stav.
        checkMembers(requests, new Map<Id, Loyalty_Member__c>(KapkaPointsLedger.lockMembers(memberIds)));
        Map<Id, List<Points_Transaction__c>> creditsByMember = new Map<Id, List<Points_Transaction__c>>();
        if (!debitedMembers.isEmpty()) {
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

    /** Člen musí existovat, být pro manažera viditelný (zámek WITH USER_MODE) a nesmí mít ukončené členství. */
    private static void checkMembers(List<Request> requests, Map<Id, Loyalty_Member__c> members) {
        for (Request request : requests) {
            Loyalty_Member__c member = members.get(request.memberId);
            if (member == null) {
                throw new KapkaAdjustPointsException(Label.Kapka_Adjust_Member_Not_Found);
            }
            if (member.Status__c == MEMBER_CLOSED) {
                throw new KapkaAdjustPointsException(Label.Kapka_Adjust_Member_Closed);
            }
        }
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
