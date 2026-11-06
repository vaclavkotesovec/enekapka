@IsTest
private class KapkaPortalRewardControllerTest {
    private static final String TIRES = 'Sleva 200 Kč na přezutí';
    private static final String SERVICE = 'Sleva 500 Kč na servis';
    private static final String INSPECTION = 'Servisní prohlídka zdarma';
    private static final String OLD_REWARD = 'Mytí zdarma';

    @IsTest
    static void catalogShowsOnlyActiveRewards() {
        // Pokud
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        insertCatalog();

        // Když
        Set<String> names = new Set<String>();
        System.runAs(jana) {
            Test.startTest();
            for (KapkaPortalRewardController.RewardView reward : KapkaPortalRewardController.getRewards()) {
                names.add(reward.name);
            }
            Test.stopTest();
        }

        // Pak
        Assert.areEqual(new Set<String>{ TIRES, SERVICE, INSPECTION }, names, 'Jen aktivní odměny EneServis');
    }

    @IsTest
    static void catalogShowsMissingKapky() {
        // Pokud
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        insertCatalog();
        insert KapkaTestDataFactory.makeTransaction(KapkaTestDataFactory.memberOf(jana).Id, 'Earn', 'Posted', 609);

        // Když
        Map<String, Decimal> missingByName = new Map<String, Decimal>();
        System.runAs(jana) {
            Test.startTest();
            for (KapkaPortalRewardController.RewardView reward : KapkaPortalRewardController.getRewards()) {
                missingByName.put(reward.name, reward.missingKapky);
            }
            Test.stopTest();
        }

        // Pak
        Assert.areEqual(591, missingByName.get(SERVICE), 'Na servis za 1 200 kapek chybí 591 kapek');
    }

    @IsTest
    static void memberSeesOwnVouchersOnly() {
        // Pokud
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        User petr = KapkaTestDataFactory.createPortalMember('Petr', 'Svoboda');
        Reward__c tiresReward = insertCatalog().get(TIRES);
        insert new List<Voucher__c>{
            KapkaTestDataFactory.makeVoucher(KapkaTestDataFactory.memberOf(jana).Id, tiresReward.Id, 'KPK-JANA-0001'),
            KapkaTestDataFactory.makeVoucher(KapkaTestDataFactory.memberOf(petr).Id, tiresReward.Id, 'KPK-PETR-0001')
        };

        // Když
        List<KapkaPortalRewardController.VoucherView> vouchers;
        System.runAs(jana) {
            Test.startTest();
            vouchers = KapkaPortalRewardController.getMyVouchers();
            Test.stopTest();
        }

        // Pak
        Assert.areEqual('KPK-JANA-0001|' + TIRES, vouchers[0].code + '|' + vouchers[0].rewardName, 'Jana vidí jen svůj voucher');
    }

    private static Map<String, Reward__c> insertCatalog() {
        Account eneServis = KapkaTestDataFactory.createPartner('EneServis, s.r.o.');
        Map<String, Reward__c> rewards = new Map<String, Reward__c>{
            TIRES => KapkaTestDataFactory.makeReward(eneServis.Id, TIRES, 500),
            SERVICE => KapkaTestDataFactory.makeReward(eneServis.Id, SERVICE, 1200),
            INSPECTION => KapkaTestDataFactory.makeReward(eneServis.Id, INSPECTION, 5000),
            OLD_REWARD => KapkaTestDataFactory.makeReward(eneServis.Id, OLD_REWARD, 300)
        };
        rewards.get(OLD_REWARD).Is_Active__c = false;
        insert rewards.values();
        return rewards;
    }
}
