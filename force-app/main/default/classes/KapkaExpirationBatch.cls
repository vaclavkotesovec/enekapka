/**
 * Noční expirace kapek (karta bonus: expirace, X1–X4): zbytky balíčků s Expiration_Date__c
 * před dneškem propadnou jedním pohybem Expirace na člena s alokací na každý balíček.
 */
public with sharing class KapkaExpirationBatch implements Database.Batchable<SObject> {
    private static final String EXPIRE = 'Expire';
    private static final String POSTED = 'Posted';
    private static final String SOURCE_EXPIRATION = 'Expiration';

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id FROM Loyalty_Member__c WITH USER_MODE]);
    }

    public void execute(Database.BatchableContext context, List<Loyalty_Member__c> members) {
        Set<Id> memberIds = new Map<Id, Loyalty_Member__c>(members).keySet();
        KapkaPointsLedger.lockMembers(memberIds);
        Map<Id, List<Points_Transaction__c>> creditsByMember = KapkaPointsLedger.creditsByMember(memberIds);
        writeOffExpired(expiredCreditsByMember(creditsByMember));
    }

    public void finish(Database.BatchableContext context) {
    }

    /** Kapky platí i v den expirace (X2): propadají jen balíčky s expirací před dneškem. */
    private static Map<Id, List<Points_Transaction__c>> expiredCreditsByMember(
        Map<Id, List<Points_Transaction__c>> creditsByMember
    ) {
        Date today = Date.today();
        Map<Id, List<Points_Transaction__c>> expiredByMember = new Map<Id, List<Points_Transaction__c>>();
        for (Id memberId : creditsByMember.keySet()) {
            List<Points_Transaction__c> expired = new List<Points_Transaction__c>();
            for (Points_Transaction__c credit : creditsByMember.get(memberId)) {
                if (credit.Expiration_Date__c != null && credit.Expiration_Date__c < today) {
                    expired.add(credit);
                }
            }
            if (!expired.isEmpty()) {
                expiredByMember.put(memberId, expired);
            }
        }
        return expiredByMember;
    }

    private static void writeOffExpired(Map<Id, List<Points_Transaction__c>> expiredByMember) {
        Map<Id, Points_Transaction__c> expirationByMember = new Map<Id, Points_Transaction__c>();
        for (Id memberId : expiredByMember.keySet()) {
            expirationByMember.put(
                memberId,
                new Points_Transaction__c(
                    Loyalty_Member__c = memberId,
                    Type__c = EXPIRE,
                    Status__c = POSTED,
                    Source__c = SOURCE_EXPIRATION,
                    Points__c = -KapkaPointsLedger.remainingPoints(expiredByMember.get(memberId)),
                    Transaction_Date__c = System.now()
                )
            );
        }
        // Zápis v systémovém režimu: knihu kapek zakládají jen služby programu, ne uživatelé.
        insert expirationByMember.values();

        List<Points_Allocation__c> allocations = new List<Points_Allocation__c>();
        for (Id memberId : expirationByMember.keySet()) {
            Points_Transaction__c expiration = expirationByMember.get(memberId);
            allocations.addAll(
                KapkaPointsLedger.allocateFifo(expiredByMember.get(memberId), expiration.Id, -expiration.Points__c)
            );
        }
        insert allocations;
    }
}
