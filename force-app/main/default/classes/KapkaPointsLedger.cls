/**
 * Společná pravidla knihy kapek pro odpisy z balíčků (čerpání, expirace):
 * zámek člena (C2, X3) a FIFO alokace podle data expirace.
 */
public with sharing class KapkaPointsLedger {
    private static final String EARN = 'Earn';
    private static final String POSTED = 'Posted';

    /** Zámek členů brání tomu, aby dva souběžné odpisy vzaly stejné kapky. */
    public static List<Loyalty_Member__c> lockMembers(Set<Id> memberIds) {
        return [SELECT Id, Status__c FROM Loyalty_Member__c WHERE Id IN :memberIds WITH USER_MODE FOR UPDATE];
    }

    /** Zaúčtovaná připsání se zbytkem kapek po členech v pořadí FIFO: nejdřív ta, která vyprší dřív. */
    public static Map<Id, List<Points_Transaction__c>> creditsByMember(Set<Id> memberIds) {
        Map<Id, List<Points_Transaction__c>> creditsByMember = new Map<Id, List<Points_Transaction__c>>();
        for (Points_Transaction__c credit : [
            SELECT Id, Loyalty_Member__c, Remaining_Points__c, Expiration_Date__c
            FROM Points_Transaction__c
            WHERE
                Loyalty_Member__c IN :memberIds
                AND Type__c = :EARN
                AND Status__c = :POSTED
                AND Remaining_Points__c > 0
            WITH USER_MODE
            ORDER BY Expiration_Date__c ASC NULLS LAST, Transaction_Date__c ASC
        ]) {
            if (!creditsByMember.containsKey(credit.Loyalty_Member__c)) {
                creditsByMember.put(credit.Loyalty_Member__c, new List<Points_Transaction__c>());
            }
            creditsByMember.get(credit.Loyalty_Member__c).add(credit);
        }
        return creditsByMember;
    }

    /** Součet zbytků balíčků. */
    public static Decimal remainingPoints(List<Points_Transaction__c> credits) {
        Decimal total = 0;
        for (Points_Transaction__c credit : credits) {
            total += credit.Remaining_Points__c;
        }
        return total;
    }

    /** Rozepíše odpis na balíčky v pořadí, v jakém přišly (FIFO). */
    public static List<Points_Allocation__c> allocateFifo(
        List<Points_Transaction__c> credits,
        Id debitId,
        Decimal pointsNeeded
    ) {
        List<Points_Allocation__c> allocations = new List<Points_Allocation__c>();
        Decimal stillNeeded = pointsNeeded;
        for (Points_Transaction__c credit : credits) {
            if (stillNeeded <= 0) {
                break;
            }
            Decimal taken = Math.min(credit.Remaining_Points__c, stillNeeded);
            allocations.add(
                new Points_Allocation__c(Credit_Transaction__c = credit.Id, Debit_Transaction__c = debitId, Points__c = taken)
            );
            stillNeeded -= taken;
        }
        return allocations;
    }
}
