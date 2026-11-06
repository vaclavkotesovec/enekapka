trigger OrderItemTrigger on Order_Item__c(before insert, before delete) {
    if (Trigger.isInsert) {
        OrderItemService.copyProductSnapshot(Trigger.new);
    } else if (Trigger.isDelete) {
        OrderItemService.preventDeleteFromCompletedOrders(Trigger.old);
    }
}
