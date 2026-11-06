@IsTest
private class KapkaNudgeBatchTest {
    @IsTest
    static void batchNudgesMembersWithoutEmail() {
        Account partner = KapkaTestDataFactory.createPartner('Pneuservis');
        Reward__c reward = KapkaTestDataFactory.makeReward(partner.Id, 'Sleva 200 Kč na přezutí', 500);
        insert reward;
        List<Loyalty_Member__c> members = new List<Loyalty_Member__c>{
            KapkaTestDataFactory.makeMember(KapkaTestDataFactory.createPersonAccount('Bez', 'Emailu').Id),
            KapkaTestDataFactory.makeMember(KapkaTestDataFactory.createPersonAccount('Jana', 'Nováková').Id)
        };
        for (Loyalty_Member__c member : members) {
            member.Status__c = 'Active';
        }
        insert members;
        List<Points_Transaction__c> earns = new List<Points_Transaction__c>();
        for (Loyalty_Member__c member : members) {
            earns.add(KapkaTestDataFactory.makeTransaction(member.Id, 'Earn', 'Posted', 450));
        }
        insert earns;

        Test.startTest();
        Database.executeBatch(new KapkaNudgeBatch());
        Test.stopTest();

        for (Loyalty_Member__c member : [SELECT Nudge_Reward__c FROM Loyalty_Member__c WHERE Id IN :members]) {
            Assert.areEqual(reward.Id, member.Nudge_Reward__c, 'odměna na dosah se zaznamená i bez e-mailu');
        }
    }

    @IsTest
    static void scheduleNightlyPlansJobAtThree() {
        Test.startTest();
        Id jobId = KapkaNudgeBatch.scheduleNightly();
        Test.stopTest();

        CronTrigger job = [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual('0 0 3 * * ?', job.CronExpression, 'kontrola běží každou noc ve 3:00');
    }
}
