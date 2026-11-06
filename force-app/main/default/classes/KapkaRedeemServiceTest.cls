/**
 * Karta cerpani-voucher: uplatnění kapek za voucher.
 * Seam S1 z plánu: KapkaRedeemService.redeem.
 */
@IsTest
private class KapkaRedeemServiceTest {
    private static final String ACTIVE = 'Active';
    private static final String EARN = 'Earn';
    private static final String POSTED = 'Posted';
    private static final String PARTNER_NAME = 'EneServis, s.r.o.';
    private static final String SLEVA_NA_PREZUTI = 'Sleva 200 Kč na přezutí';
    private static final Decimal SLEVA_NA_PREZUTI_COST = 500;
    private static final String VOUCHER_CODE_FORMAT = 'KPK-[A-Z0-9]{4}-[A-Z0-9]{4}';

    // AC-1.1
    @IsTest
    static void janaRedeemsTireChangeVoucher() {
        // Pokud aktivní členka Jana má 609 kapek
        Loyalty_Member__c jana = createActiveMember('Jana', 'Nováková');
        insert KapkaTestDataFactory.makeTransaction(jana.Id, EARN, POSTED, 609);
        Reward__c prezuti = createReward(SLEVA_NA_PREZUTI, SLEVA_NA_PREZUTI_COST);

        // Když uplatní odměnu Sleva 200 Kč na přezutí za 500 kapek
        Test.startTest();
        Voucher__c voucher = KapkaRedeemService.redeem(jana.Id, prezuti.Id);
        Test.stopTest();

        // Pak dostane voucher ve stavu Vydán s kódem ve tvaru KPK-XXXX-XXXX
        Voucher__c saved = [SELECT Status__c, Code__c, Loyalty_Member__c FROM Voucher__c WHERE Id = :voucher.Id];
        Assert.isTrue(
            saved.Status__c == 'Issued' &&
                saved.Loyalty_Member__c == jana.Id &&
                Pattern.matches(VOUCHER_CODE_FORMAT, saved.Code__c),
            'Jana má dostat vydaný voucher s kódem KPK-XXXX-XXXX, dostala: ' + saved
        );
        // A má 109 kapek
        Assert.areEqual(109, balanceOf(jana.Id), 'Po uplatnění za 500 kapek má Janě zbýt 109 kapek.');
    }

    // AC-2.1
    @IsTest
    static void redeemTakesEarliestExpiringKapkyFirst() {
        // Pokud má člen připsání 300 kapek platné do 1. 3. 2027 a 400 kapek platné do 1. 6. 2027
        Loyalty_Member__c member = createActiveMember('Petr', 'Svoboda');
        Points_Transaction__c laterExpiring = makeEarn(member.Id, 400, Date.newInstance(2027, 6, 1));
        insert laterExpiring;
        Points_Transaction__c earlierExpiring = makeEarn(member.Id, 300, Date.newInstance(2027, 3, 1));
        insert earlierExpiring;
        Reward__c reward = createReward(SLEVA_NA_PREZUTI, SLEVA_NA_PREZUTI_COST);

        // Když uplatní odměnu za 500 kapek
        Test.startTest();
        KapkaRedeemService.redeem(member.Id, reward.Id);
        Test.stopTest();

        // Pak z připsání do 1. 3. 2027 zbývá 0 kapek a z připsání do 1. 6. 2027 zbývá 200 kapek
        Map<Id, Points_Transaction__c> earns = new Map<Id, Points_Transaction__c>(
            [SELECT Remaining_Points__c FROM Points_Transaction__c WHERE Type__c = :EARN]
        );
        Assert.areEqual(
            new List<Decimal>{ 0, 200 },
            new List<Decimal>{
                earns.get(earlierExpiring.Id).Remaining_Points__c,
                earns.get(laterExpiring.Id).Remaining_Points__c
            },
            'Kapky se berou nejdřív z připsání, které vyprší dřív.'
        );
    }

    // AC-3.1
    @IsTest
    static void notEnoughKapkyIsRefusedWithoutChanges() {
        // Pokud aktivní člen má 450 kapek
        Loyalty_Member__c member = createActiveMember('Petr', 'Svoboda');
        insert KapkaTestDataFactory.makeTransaction(member.Id, EARN, POSTED, 450);
        Reward__c reward = createReward(SLEVA_NA_PREZUTI, SLEVA_NA_PREZUTI_COST);

        // Když uplatní odměnu za 500 kapek
        Test.startTest();
        String refusal = refusalOf(member.Id, reward.Id);
        Test.stopTest();

        // Pak uvidí „Na tuhle odměnu ti chybí 50 kapek.“ a nevznikne voucher ani pohyb kapek
        Assert.areEqual('Na tuhle odměnu ti chybí 50 kapek.', refusal, 'Člen má vidět, kolik kapek mu chybí.');
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Voucher__c] + [SELECT COUNT() FROM Points_Transaction__c WHERE Type__c != :EARN],
            'Odmítnuté čerpání nesmí zanechat voucher ani pohyb kapek.'
        );
    }

    // AC-4.1
    @IsTest
    static void inactiveRewardIsRefused() {
        // Pokud odměna Sleva 500 Kč na servis je vypnutá
        Loyalty_Member__c member = createActiveMember('Petr', 'Svoboda');
        insert KapkaTestDataFactory.makeTransaction(member.Id, EARN, POSTED, 2000);
        Reward__c servis = createReward('Sleva 500 Kč na servis', 1200);
        servis.Is_Active__c = false;
        update servis;

        // Když ji aktivní člen s 2 000 kapkami uplatní
        Test.startTest();
        String refusal = refusalOf(member.Id, servis.Id);
        Test.stopTest();

        // Pak uvidí „Tahle odměna už není v nabídce.“
        Assert.areEqual('Tahle odměna už není v nabídce.', refusal, 'Vypnutou odměnu nejde uplatnit.');
    }

    /** Hláška odmítnutého čerpání; null, když čerpání prošlo. */
    private static String refusalOf(Id memberId, Id rewardId) {
        try {
            KapkaRedeemService.redeem(memberId, rewardId);
            return null;
        } catch (KapkaRedeemException e) {
            return e.getMessage();
        }
    }

    private static Points_Transaction__c makeEarn(Id memberId, Decimal points, Date expirationDate) {
        Points_Transaction__c earn = KapkaTestDataFactory.makeTransaction(memberId, EARN, POSTED, points);
        earn.Expiration_Date__c = expirationDate;
        return earn;
    }

    private static Loyalty_Member__c createActiveMember(String firstName, String lastName) {
        Loyalty_Member__c member = KapkaTestDataFactory.makeMember(
            KapkaTestDataFactory.createPersonAccount(firstName, lastName).Id
        );
        member.Status__c = ACTIVE;
        insert member;
        return member;
    }

    private static Reward__c createReward(String name, Decimal pointsCost) {
        Reward__c reward = KapkaTestDataFactory.makeReward(
            KapkaTestDataFactory.createPartner(PARTNER_NAME).Id,
            name,
            pointsCost
        );
        insert reward;
        return reward;
    }

    private static Decimal balanceOf(Id memberId) {
        return [SELECT Points_Balance__c FROM Loyalty_Member__c WHERE Id = :memberId].Points_Balance__c;
    }
}
