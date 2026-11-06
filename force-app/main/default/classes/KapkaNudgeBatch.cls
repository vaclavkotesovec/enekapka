/**
 * Noční kontrola Kapky na dosah (karta kapky-na-dosah, N4): ve 3:00, po expiraci ve 2:00,
 * aby počítala s čerstvým zůstatkem. Logika je v KapkaNudgeService, e-mail pošle Flow.
 */
public with sharing class KapkaNudgeBatch implements Database.Batchable<SObject>, Schedulable {
    private static final String JOB_NAME = 'Kapka – kapky na dosah';
    private static final String NIGHTLY_AT_THREE = '0 0 3 * * ?';
    private static final String ACTIVE = 'Active';

    /** Naplánuje kontrolu kapek na dosah na každou noc ve 3:00 (N4). */
    public static Id scheduleNightly() {
        return System.schedule(JOB_NAME, NIGHTLY_AT_THREE, new KapkaNudgeBatch());
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new KapkaNudgeBatch());
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id FROM Loyalty_Member__c WHERE Status__c = :ACTIVE WITH USER_MODE]);
    }

    public void execute(Database.BatchableContext context, List<Loyalty_Member__c> members) {
        KapkaNudgeService.evaluate(members);
    }

    public void finish(Database.BatchableContext context) {
    }
}
