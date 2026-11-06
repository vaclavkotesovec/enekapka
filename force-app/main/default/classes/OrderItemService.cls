/**
 * Služba položek nákupu: při vložení zmrazí cenu a kategorii produktu na položce (AC-2),
 * aby pozdější změna ceníku neměnila historické nákupy ani z nich připsané kapky.
 * Položky dokončeného nákupu chrání před smazáním (ST-15).
 */
public with sharing class OrderItemService {
    private static final String COMPLETED = 'Completed';

    /**
     * Zkopíruje Product2.Price__c a Product2.Family do Unit_Price__c a Product_Family__c.
     * Volá se z before insert, takže nepotřebuje DML.
     */
    public static void copyProductSnapshot(List<Order_Item__c> items) {
        Set<Id> productIds = new Set<Id>();
        for (Order_Item__c item : items) {
            if (item.Product__c != null) {
                productIds.add(item.Product__c);
            }
        }
        if (productIds.isEmpty()) {
            return;
        }

        // SYSTEM_MODE záměrně: snímek ceny je integrita dat, ne zobrazení. Položky zakládá i pokladní
        // integrace, která nemusí mít FLS na ceně produktu, a položka bez ceny by zkreslila součty i kapky.
        Map<Id, Product2> products = new Map<Id, Product2>(
            [SELECT Id, Price__c, Family FROM Product2 WHERE Id IN :productIds WITH SYSTEM_MODE]
        );
        for (Order_Item__c item : items) {
            Product2 product = products.get(item.Product__c);
            if (product != null) {
                item.Unit_Price__c = product.Price__c;
                item.Product_Family__c = product.Family;
            }
        }
    }

    /**
     * Zamkne položky dokončeného nákupu proti smazání (ST-15). Validační pravidlo na smazání nezabírá,
     * proto before delete. Platí pro všechny včetně admina; smazání celého nákupu kaskádou trigger položek nespouští.
     */
    public static void preventDeleteFromCompletedOrders(List<Order_Item__c> items) {
        Set<Id> orderIds = new Set<Id>();
        for (Order_Item__c item : items) {
            orderIds.add(item.Order__c);
        }
        // SYSTEM_MODE záměrně: zámek je integrita knihy kapek, musí platit bez ohledu na práva mazajícího.
        Map<Id, Order__c> completedOrders = new Map<Id, Order__c>(
            [SELECT Id FROM Order__c WHERE Id IN :orderIds AND Status__c = :COMPLETED WITH SYSTEM_MODE]
        );
        for (Order_Item__c item : items) {
            if (completedOrders.containsKey(item.Order__c)) {
                item.addError(System.Label.Kapka_Completed_Order_Item_Locked);
            }
        }
    }
}
