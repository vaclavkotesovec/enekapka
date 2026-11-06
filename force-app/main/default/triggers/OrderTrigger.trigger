trigger OrderTrigger on Order__c(before insert, after update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        OrderService.copyMemberAccount(Trigger.new);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        KapkaEarnService.earnForCompletedOrders(Trigger.new, Trigger.oldMap);
    }
}
