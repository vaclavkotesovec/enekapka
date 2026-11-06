/**
 * Vyhodnocení kampaní nad nákupem (karta earn-kampane, rozhodnutí E2 a E4).
 * Kampaně jsou data: podmínka (typ + práh) a odměna (typ + hodnota); platí ty aktivní k datu nákupu.
 */
public with sharing class KapkaCampaignEvaluator {
    private static final String MIN_FUEL_LITERS = 'Min Fuel Liters';
    private static final String MIN_OTHER_AMOUNT = 'Min Other Amount';
    private static final String BASE_MULTIPLIER = 'Base Multiplier';

    /** Kapky z jedné uplatněné kampaně. */
    public class Award {
        public Id campaignId;
        public Decimal points;

        Award(Id campaignId, Decimal points) {
            this.campaignId = campaignId;
            this.points = points;
        }
    }

    private final List<Loyalty_Campaign__c> campaigns;

    /** Načte jedním dotazem aktivní kampaně, které mohou platit v rozsahu dat nákupů dávky. */
    public KapkaCampaignEvaluator(Date firstDay, Date lastDay) {
        // SYSTEM_MODE záměrně: kampaně vyhodnocuje systém i při pokladním importu bez práv na kampaně.
        campaigns = [
            SELECT Id, Condition_Type__c, Threshold__c, Reward_Type__c, Reward_Value__c, Valid_From__c, Valid_To__c
            FROM Loyalty_Campaign__c
            WHERE
                Is_Active__c = TRUE
                AND (Valid_From__c = NULL OR Valid_From__c <= :lastDay)
                AND (Valid_To__c = NULL OR Valid_To__c >= :firstDay)
            WITH SYSTEM_MODE
        ];
    }

    /** Všechny splněné kampaně; každá se počítá z čistého základu (E4). */
    public List<Award> evaluate(Decimal basePoints, Decimal fuelLiters, Decimal otherAmount, Date purchaseDay) {
        List<Award> awards = new List<Award>();
        for (Loyalty_Campaign__c campaign : campaigns) {
            if (!isValidOn(campaign, purchaseDay) || !conditionMet(campaign, fuelLiters, otherAmount)) {
                continue;
            }
            Decimal points = reward(campaign, basePoints);
            if (points > 0) {
                awards.add(new Award(campaign.Id, points));
            }
        }
        return awards;
    }

    private static Boolean isValidOn(Loyalty_Campaign__c campaign, Date day) {
        return (campaign.Valid_From__c == null || campaign.Valid_From__c <= day) &&
            (campaign.Valid_To__c == null || campaign.Valid_To__c >= day);
    }

    private static Boolean conditionMet(Loyalty_Campaign__c campaign, Decimal fuelLiters, Decimal otherAmount) {
        Decimal threshold = campaign.Threshold__c == null ? 0 : campaign.Threshold__c;
        if (campaign.Condition_Type__c == MIN_FUEL_LITERS) {
            return fuelLiters >= threshold;
        }
        if (campaign.Condition_Type__c == MIN_OTHER_AMOUNT) {
            return otherAmount >= threshold;
        }
        return false;
    }

    /** Pevná kampaň přidá hodnotu; násobící přidá floor(základ × k) − základ. */
    private static Decimal reward(Loyalty_Campaign__c campaign, Decimal basePoints) {
        Decimal value = campaign.Reward_Value__c == null ? 0 : campaign.Reward_Value__c;
        if (campaign.Reward_Type__c == BASE_MULTIPLIER) {
            return Math.floor(basePoints * value) - basePoints;
        }
        return value;
    }
}
