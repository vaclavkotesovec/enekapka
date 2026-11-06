trigger OrderTrigger on Order__c(after update) {
    KapkaEarnService.earnForCompletedOrders(Trigger.new, Trigger.oldMap);
}
