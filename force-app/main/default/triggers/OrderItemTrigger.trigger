trigger OrderItemTrigger on Order_Item__c(before insert) {
    OrderItemService.copyProductSnapshot(Trigger.new);
}
