/**
 * Noční expirace kapek (karta bonus: expirace, X1–X4): zbytky balíčků s Expiration_Date__c
 * před dneškem propadnou jedním pohybem Expirace na člena s alokací na každý balíček.
 *
 * without sharing záměrně (review T1): noční systémový proces nad VŠEMI členy. Plánuje ho loyalty
 * manažer, který členy vidí (View All), ale nevlastní; zápis expirace nesmí záviset na sdílení
 * toho, kdo job naplánoval, jinak by celá dávka spadla a nic by neodepsala.
 */
public without sharing class KapkaExpirationBatch implements Database.Batchable<SObject>, Schedulable {
    private static final String JOB_NAME = 'Kapka – expirace kapek';
    private static final String NIGHTLY_AT_TWO = '0 0 2 * * ?';
    private static final String EXPIRE = 'Expire';
    private static final String POSTED = 'Posted';
    private static final String SOURCE_EXPIRATION = 'Expiration';
    private static final Integer EXPIRING_SOON_DAYS = 30;

    /** Naplánuje expiraci na každou noc ve 2:00 (X1, AC-4.1); existující job stejného jména nahradí (review T2). */
    public static Id scheduleNightly() {
        for (CronTrigger existing : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :JOB_NAME]) {
            System.abortJob(existing.Id);
        }
        return System.schedule(JOB_NAME, NIGHTLY_AT_TWO, new KapkaExpirationBatch());
    }

    /** Spuštění plánovačem: pustí batch přes všechny členy. */
    public void execute(SchedulableContext context) {
        Database.executeBatch(new KapkaExpirationBatch());
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id FROM Loyalty_Member__c WITH SYSTEM_MODE]);
    }

    public void execute(Database.BatchableContext context, List<Loyalty_Member__c> members) {
        Set<Id> memberIds = new Map<Id, Loyalty_Member__c>(members).keySet();
        KapkaPointsLedger.lockMembers(memberIds);
        Map<Id, List<Points_Transaction__c>> creditsByMember = KapkaPointsLedger.creditsByMember(memberIds);
        writeOffExpired(expiredCreditsByMember(creditsByMember));
        update expiringSoon(memberIds, creditsByMember);
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

    /** Zbytky balíčků s expirací dnes až za EXPIRING_SOON_DAYS dnů, u členů bez nich 0 (X4). */
    private static List<Loyalty_Member__c> expiringSoon(
        Set<Id> memberIds,
        Map<Id, List<Points_Transaction__c>> creditsByMember
    ) {
        Date today = Date.today();
        Date horizon = today.addDays(EXPIRING_SOON_DAYS);
        List<Loyalty_Member__c> members = new List<Loyalty_Member__c>();
        for (Id memberId : memberIds) {
            Decimal expiring = 0;
            List<Points_Transaction__c> credits = creditsByMember.containsKey(memberId)
                ? creditsByMember.get(memberId)
                : new List<Points_Transaction__c>();
            for (Points_Transaction__c credit : credits) {
                Date expirationDate = credit.Expiration_Date__c;
                if (expirationDate != null && expirationDate >= today && expirationDate <= horizon) {
                    expiring += credit.Remaining_Points__c;
                }
            }
            // Zápis v systémovém režimu: pole plní jen tento batch, uživatelé ho jen čtou.
            members.add(new Loyalty_Member__c(Id = memberId, Points_Expiring_Next_30_Days__c = expiring));
        }
        return members;
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
