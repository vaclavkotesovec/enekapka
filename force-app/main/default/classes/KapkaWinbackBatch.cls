/**
 * Win-back neaktivních členů (karta winback, W1–W4): aktivní člen bez aktivity INACTIVE_DAYS a více dní
 * dostane jednu připomínku za období nečinnosti. Batch zapíše Winback_Date__c, e-mail pošle Flow.
 */
public with sharing class KapkaWinbackBatch implements Database.Batchable<SObject>, Schedulable {
    private static final String JOB_NAME = 'Kapka – win-back neaktivních členů';
    private static final String NIGHTLY_AT_HALF_PAST_THREE = '0 30 3 * * ?';
    private static final String ACTIVE = 'Active';
    private static final Integer INACTIVE_DAYS = 30;

    /** Naplánuje kontrolu na každou noc ve 3:30 (W4). */
    public static Id scheduleNightly() {
        return System.schedule(JOB_NAME, NIGHTLY_AT_HALF_PAST_THREE, new KapkaWinbackBatch());
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new KapkaWinbackBatch());
    }

    /** W1: jen aktivní členové s poslední aktivitou před INACTIVE_DAYS a více dny; prázdné datum se přeskočí. */
    public Database.QueryLocator start(Database.BatchableContext context) {
        Date threshold = Date.today().addDays(-INACTIVE_DAYS);
        return Database.getQueryLocator(
            [
                SELECT Id, Last_Activity_Date__c, Winback_Date__c
                FROM Loyalty_Member__c
                WHERE Status__c = :ACTIVE AND Last_Activity_Date__c != NULL AND Last_Activity_Date__c <= :threshold
                WITH USER_MODE
            ]
        );
    }

    public void execute(Database.BatchableContext context, List<Loyalty_Member__c> members) {
        List<Loyalty_Member__c> reminded = new List<Loyalty_Member__c>();
        for (Loyalty_Member__c member : members) {
            if (!alreadyReminded(member)) {
                reminded.add(new Loyalty_Member__c(Id = member.Id, Winback_Date__c = Date.today()));
            }
        }
        // Zápis v systémovém režimu: pole plní jen tento batch, uživatelé ho jen čtou.
        update reminded;
    }

    public void finish(Database.BatchableContext context) {
    }

    /** W2: připomínka po poslední aktivitě už odešla – za jedno období jen jedna. */
    private static Boolean alreadyReminded(Loyalty_Member__c member) {
        return member.Winback_Date__c != null && member.Winback_Date__c >= member.Last_Activity_Date__c;
    }
}
