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
