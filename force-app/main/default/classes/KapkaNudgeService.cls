/**
 * Kapky na dosah (karta kapky-na-dosah, N1–N2): členovi, kterému do nejbližší dražší aktivní
 * odměny chybí nejvýš THRESHOLD_PERCENT % její ceny, zapíše odměnu na dosah. E-mail pošle Flow.
 */
public with sharing class KapkaNudgeService {
    private static final Integer THRESHOLD_PERCENT = 10;
    private static final Integer ONE_HUNDRED_PERCENT = 100;
    private static final String ACTIVE = 'Active';

    /** Vyhodnotí členy a uloží ty, kterým vznikla nová připomínka; vrací je. */
    public static List<Loyalty_Member__c> evaluate(List<Loyalty_Member__c> members) {
        List<Reward__c> rewards = activeRewardsByCost();
        List<Loyalty_Member__c> nudged = new List<Loyalty_Member__c>();
        for (Loyalty_Member__c member : freshMembers(members)) {
            Loyalty_Member__c nudge = nudgeFor(member, rewards);
            if (nudge != null) {
                nudged.add(nudge);
            }
        }
        // Noční systémová úloha zapisuje systémová pole připomínky – běží v system mode (bez FLS).
        update nudged;
        return nudged;
    }

    private static Loyalty_Member__c nudgeFor(Loyalty_Member__c member, List<Reward__c> rewards) {
        Decimal balance = member.Points_Balance__c == null ? 0 : member.Points_Balance__c;
        Reward__c target = cheapestAbove(balance, rewards);
        if (target == null || target.Id == member.Nudge_Reward__c) {
            return null;
        }
        Decimal missing = target.Points_Cost__c - balance;
        if (missing * ONE_HUNDRED_PERCENT > target.Points_Cost__c * THRESHOLD_PERCENT) {
            return null;
        }
        return new Loyalty_Member__c(
            Id = member.Id,
            Nudge_Reward__c = target.Id,
            Nudge_Points_Missing__c = missing,
            Nudge_Date__c = Date.today()
        );
    }

    /** Odměny jsou seřazené vzestupně podle ceny – první dražší než zůstatek je cíl (N1). */
    private static Reward__c cheapestAbove(Decimal balance, List<Reward__c> rewards) {
        for (Reward__c reward : rewards) {
            if (reward.Points_Cost__c > balance) {
                return reward;
            }
        }
        return null;
    }

    private static List<Reward__c> activeRewardsByCost() {
        return [
            SELECT Id, Points_Cost__c
            FROM Reward__c
            WHERE Is_Active__c = TRUE AND Points_Cost__c != NULL
            WITH USER_MODE
            ORDER BY Points_Cost__c ASC
        ];
    }

    private static List<Loyalty_Member__c> freshMembers(List<Loyalty_Member__c> members) {
        Set<Id> memberIds = new Map<Id, Loyalty_Member__c>(members).keySet();
        return [
            SELECT Id, Points_Balance__c, Nudge_Reward__c
            FROM Loyalty_Member__c
            WHERE Id IN :memberIds AND Status__c = :ACTIVE
        ];
    }
}
