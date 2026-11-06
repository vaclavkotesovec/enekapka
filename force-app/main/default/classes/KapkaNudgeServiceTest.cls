@IsTest
private class KapkaNudgeServiceTest {
    private static final String ACTIVE = 'Active';

    private static Loyalty_Member__c memberWithBalance(String lastName, Decimal balance, String status) {
        Loyalty_Member__c member = KapkaTestDataFactory.makeMember(
            KapkaTestDataFactory.createPersonAccount('Jana', lastName).Id
        );
        member.Status__c = status;
        insert member;
        insert KapkaTestDataFactory.makeTransaction(member.Id, 'Earn', 'Posted', balance);
        return member;
    }

    private static Reward__c createReward(String name, Decimal cost, Boolean active) {
        Account partner = KapkaTestDataFactory.createPartner('Partner ' + name);
        Reward__c reward = KapkaTestDataFactory.makeReward(partner.Id, name, cost);
        reward.Is_Active__c = active;
        insert reward;
        return reward;
    }

    private static Loyalty_Member__c reload(Id memberId) {
        return [
            SELECT Nudge_Reward__c, Nudge_Points_Missing__c, Nudge_Date__c
            FROM Loyalty_Member__c
            WHERE Id = :memberId
        ];
    }

    @IsTest
    static void memberWithinTenPercentGetsNudge() {
        Reward__c reward = createReward('Sleva 200 Kč na přezutí', 500, true);
        Loyalty_Member__c jana = memberWithBalance('Nováková', 450, ACTIVE);

        Test.startTest();
        KapkaNudgeService.evaluate(new List<Loyalty_Member__c>{ jana });
        Test.stopTest();

        Loyalty_Member__c result = reload(jana.Id);
        Assert.areEqual(reward.Id, result.Nudge_Reward__c, 'Jana má odměnu na dosah');
        Assert.areEqual(50, result.Nudge_Points_Missing__c, 'chybí 50 kapek');
        Assert.areEqual(Date.today(), result.Nudge_Date__c, 'datum připomínky je dnes');
    }

    @IsTest
    static void memberFarFromRewardGetsNoNudge() {
        createReward('Sleva 200 Kč na přezutí', 500, true);
        Loyalty_Member__c member = memberWithBalance('Daleko', 400, ACTIVE);

        Test.startTest();
        KapkaNudgeService.evaluate(new List<Loyalty_Member__c>{ member });
        Test.stopTest();

        Assert.isNull(reload(member.Id).Nudge_Reward__c, 'chybí 100 kapek = 20 %, bez připomínky');
    }

    @IsTest
    static void nudgeTargetsCheapestRewardAboveBalance() {
        createReward('Mytí', 500, true);
        Reward__c target = createReward('Plná nádrž', 1200, true);
        Loyalty_Member__c member = memberWithBalance('Sběratel', 1150, ACTIVE);

        Test.startTest();
        KapkaNudgeService.evaluate(new List<Loyalty_Member__c>{ member });
        Test.stopTest();

        Loyalty_Member__c result = reload(member.Id);
        Assert.areEqual(target.Id, result.Nudge_Reward__c, 'cílem je nejbližší dražší odměna');
        Assert.areEqual(50, result.Nudge_Points_Missing__c, 'chybí 50 kapek');
    }

    @IsTest
    static void inactiveRewardIsIgnored() {
        createReward('Vypnutá', 500, false);
        createReward('Plná nádrž', 1200, true);
        Loyalty_Member__c member = memberWithBalance('Vypnuty', 450, ACTIVE);

        Test.startTest();
        KapkaNudgeService.evaluate(new List<Loyalty_Member__c>{ member });
        Test.stopTest();

        Assert.isNull(reload(member.Id).Nudge_Reward__c, 'vypnutá odměna se nepočítá, 1 200 je daleko');
    }

    @IsTest
    static void onlyActiveMembersAreNudged() {
        createReward('Sleva 200 Kč na přezutí', 500, true);
        Loyalty_Member__c member = memberWithBalance('Registrovany', 450, 'Registered');

        Test.startTest();
        KapkaNudgeService.evaluate(new List<Loyalty_Member__c>{ member });
        Test.stopTest();

        Assert.isNull(reload(member.Id).Nudge_Reward__c, 'neaktivní člen připomínku nedostane');
    }

    @IsTest
    static void sameRewardIsNudgedOnlyOnce() {
        createReward('Sleva 200 Kč na přezutí', 500, true);
        Loyalty_Member__c jana = memberWithBalance('Nováková', 450, ACTIVE);
        KapkaNudgeService.evaluate(new List<Loyalty_Member__c>{ jana });

        Test.startTest();
        List<Loyalty_Member__c> secondNight = KapkaNudgeService.evaluate(new List<Loyalty_Member__c>{ jana });
        Test.stopTest();

        Assert.isTrue(secondNight.isEmpty(), 'druhou noc žádná nová připomínka');
    }

    @IsTest
    static void nextRewardIsNudgedAgain() {
        createReward('Mytí', 500, true);
        Reward__c next = createReward('Plná nádrž', 1200, true);
        Loyalty_Member__c member = memberWithBalance('Sběratel', 450, ACTIVE);
        KapkaNudgeService.evaluate(new List<Loyalty_Member__c>{ member });
        insert KapkaTestDataFactory.makeTransaction(member.Id, 'Earn', 'Posted', 700);

        Test.startTest();
        List<Loyalty_Member__c> nudged = KapkaNudgeService.evaluate(new List<Loyalty_Member__c>{ member });
        Test.stopTest();

        Assert.areEqual(1, nudged.size(), 'nová odměna = nová připomínka');
        Assert.areEqual(next.Id, reload(member.Id).Nudge_Reward__c, 'připomínka na odměnu za 1 200');
    }
}
