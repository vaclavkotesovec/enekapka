/**
 * Jediný zdroj testovacích dat Kapka Klubu. Metody make* vrací neuložené záznamy,
 * metody create* je rovnou vloží. Hodnoty z AC patří do testů, ne sem.
 */
@IsTest
public class KapkaTestDataFactory {
    public static final Date DEFAULT_VALID_FROM = Date.newInstance(2026, 1, 1);

    public static Earning_Rule__c makeEarningRule(
        String productFamily,
        String basis,
        Decimal unitSize,
        Decimal pointsPerUnit,
        Date validFrom
    ) {
        return new Earning_Rule__c(
            Name = productFamily + ' ' + basis,
            Product_Family__c = productFamily,
            Basis__c = basis,
            Unit_Size__c = unitSize,
            Points_Per_Unit__c = pointsPerUnit,
            Valid_From__c = validFrom
        );
    }

    public static Loyalty_Campaign__c makeCampaign(
        String name,
        String conditionType,
        Decimal threshold,
        String rewardType,
        Decimal rewardValue
    ) {
        return new Loyalty_Campaign__c(
            Name = name,
            Condition_Type__c = conditionType,
            Threshold__c = threshold,
            Reward_Type__c = rewardType,
            Reward_Value__c = rewardValue,
            Valid_From__c = DEFAULT_VALID_FROM,
            Is_Active__c = true
        );
    }

    public static Account createPartner(String name) {
        Account partner = new Account(Name = name);
        insert partner;
        return partner;
    }

    public static Reward__c makeReward(Id partnerId, String name, Decimal pointsCost) {
        return new Reward__c(Name = name, Partner__c = partnerId, Points_Cost__c = pointsCost);
    }
}
