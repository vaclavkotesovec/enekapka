/**
 * Připsání kapek za dokončený nákup (karta earn-zaklad, rozhodnutí E1–E6).
 * Za nákup vznikne jedno zaúčtované připsání (Earn) se základem podle pravidel platných k datu nákupu.
 */
public with sharing class KapkaEarnService {
    private static final String COMPLETED = 'Completed';
    private static final String EARN = 'Earn';
    private static final String POSTED = 'Posted';
    private static final String SOURCE_PURCHASE = 'Purchase';
    private static final String PER_LITER = 'Per Liter';
    private static final String FUEL = 'Fuel';

    /** Volá trigger po update nákupu; zpracuje jen nákupy, které právě přešly do stavu Dokončený (E1). */
    public static void earnForCompletedOrders(List<Order__c> orders, Map<Id, Order__c> oldOrders) {
        Set<Id> completedIds = new Set<Id>();
        for (Order__c purchase : orders) {
            if (purchase.Status__c == COMPLETED && oldOrders.get(purchase.Id).Status__c != COMPLETED) {
                completedIds.add(purchase.Id);
            }
        }
        if (completedIds.isEmpty()) {
            return;
        }
        earn(completedIds);
    }

    private static void earn(Set<Id> orderIds) {
        // SYSTEM_MODE záměrně: kapky generuje systém. Nákup dokončuje i pokladní import,
        // který nemá práva na knihu kapek ani na pravidla; výsledek musí být stejný pro každého.
        List<Order__c> purchases = [
            SELECT Id, Loyalty_Member__c, Purchase_Date__c, Fuel_Liters__c, Fuel_Amount__c, Other_Amount__c
            FROM Order__c
            WHERE Id IN :orderIds AND Loyalty_Member__c != NULL
            WITH SYSTEM_MODE
        ];
        List<Earning_Rule__c> rules = [
            SELECT Product_Family__c, Basis__c, Unit_Size__c, Points_Per_Unit__c, Valid_From__c, Valid_To__c, Expiration_Months__c
            FROM Earning_Rule__c
            WITH SYSTEM_MODE
        ];

        List<Points_Transaction__c> credits = new List<Points_Transaction__c>();
        Map<Id, Loyalty_Member__c> membersToTouch = new Map<Id, Loyalty_Member__c>();
        for (Order__c purchase : purchases) {
            Date purchaseDate = purchase.Purchase_Date__c.date();
            Decimal basePoints = 0;
            Integer expirationMonths;
            for (Earning_Rule__c rule : rulesValidOn(rules, purchaseDate)) {
                basePoints += pointsFor(rule, purchase);
                if (rule.Expiration_Months__c != null) {
                    Integer months = rule.Expiration_Months__c.intValue();
                    expirationMonths = expirationMonths == null ? months : Math.min(expirationMonths, months);
                }
            }
            credits.add(
                new Points_Transaction__c(
                    Loyalty_Member__c = purchase.Loyalty_Member__c,
                    Order__c = purchase.Id,
                    Type__c = EARN,
                    Status__c = POSTED,
                    Source__c = SOURCE_PURCHASE,
                    Base_Points__c = basePoints,
                    Points__c = basePoints,
                    Transaction_Date__c = purchase.Purchase_Date__c,
                    Expiration_Date__c = expirationMonths == null ? null : purchaseDate.addMonths(expirationMonths)
                )
            );
            membersToTouch.put(
                purchase.Loyalty_Member__c,
                new Loyalty_Member__c(Id = purchase.Loyalty_Member__c, Last_Activity_Date__c = purchaseDate)
            );
        }
        Database.insert(credits, AccessLevel.SYSTEM_MODE);
        Database.update(membersToTouch.values(), AccessLevel.SYSTEM_MODE);
    }

    private static List<Earning_Rule__c> rulesValidOn(List<Earning_Rule__c> rules, Date day) {
        List<Earning_Rule__c> valid = new List<Earning_Rule__c>();
        for (Earning_Rule__c rule : rules) {
            Boolean started = rule.Valid_From__c == null || rule.Valid_From__c <= day;
            Boolean notEnded = rule.Valid_To__c == null || rule.Valid_To__c >= day;
            if (started && notEnded) {
                valid.add(rule);
            }
        }
        return valid;
    }

    /** floor(množství / velikost jednotky) × kapky za jednotku (E3); množství jsou součty za celý nákup. */
    private static Decimal pointsFor(Earning_Rule__c rule, Order__c purchase) {
        Decimal quantity = rule.Basis__c == PER_LITER
            ? valueOrZero(purchase.Fuel_Liters__c)
            : (rule.Product_Family__c == FUEL ? valueOrZero(purchase.Fuel_Amount__c) : valueOrZero(purchase.Other_Amount__c));
        Decimal unitSize = rule.Unit_Size__c == null || rule.Unit_Size__c == 0 ? 1 : rule.Unit_Size__c;
        return Math.floor(quantity / unitSize) * valueOrZero(rule.Points_Per_Unit__c);
    }

    private static Decimal valueOrZero(Decimal value) {
        return value == null ? 0 : value;
    }
}
