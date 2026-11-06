/**
 * Služba položek nákupu: při vložení zmrazí cenu a kategorii produktu na položce (AC-2),
 * aby pozdější změna ceníku neměnila historické nákupy ani z nich připsané kapky.
 */
public with sharing class OrderItemService {
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
}
