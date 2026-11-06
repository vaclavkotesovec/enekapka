/**
 * Karta cerpani-voucher: čerpání z portálu.
 * Seam S2 z plánu: KapkaPortalRedeemController.redeem přes System.runAs portálového uživatele.
 */
@IsTest
private class KapkaPortalRedeemControllerTest {
    private static final String ACTIVE = 'Active';
    private static final String EARN = 'Earn';
    private static final String POSTED = 'Posted';

    // AC-5.1
    @IsTest
    static void portalRedeemUsesLoggedInMember() {
        // Pokud je v portálu přihlášena Jana s 609 kapkami a v programu je i Petr s 2 000 kapkami
        User owner = KapkaTestDataFactory.createAccountOwnerWithRole();
        Account janaAccount;
        Loyalty_Member__c jana;
        Loyalty_Member__c petr;
        Reward__c prezuti;
        User portalJana;
        System.runAs(owner) {
            janaAccount = KapkaTestDataFactory.createPersonAccount('Jana', 'Nováková');
            jana = createActiveMember(janaAccount.Id, 609);
            petr = createActiveMember(KapkaTestDataFactory.createPersonAccount('Petr', 'Svoboda').Id, 2000);
            prezuti = KapkaTestDataFactory.makeReward(
                KapkaTestDataFactory.createPartner('EneServis, s.r.o.').Id,
                'Sleva 200 Kč na přezutí',
                500
            );
            insert prezuti;
            portalJana = KapkaTestDataFactory.createPortalUser(janaAccount.Id);
        }

        // Když uplatní odměnu
        Voucher__c voucher;
        Test.startTest();
        System.runAs(portalJana) {
            voucher = KapkaPortalRedeemController.redeem(prezuti.Id);
        }
        Test.stopTest();

        // Pak se kapky odečtou Janě a voucher patří Janě
        Map<Id, Loyalty_Member__c> members = new Map<Id, Loyalty_Member__c>(
            [SELECT Points_Balance__c FROM Loyalty_Member__c WHERE Id IN (:jana.Id, :petr.Id)]
        );
        Assert.areEqual(
            new List<Object>{ jana.Id, 109, 2000 },
            new List<Object>{
                [SELECT Loyalty_Member__c FROM Voucher__c WHERE Id = :voucher.Id].Loyalty_Member__c,
                members.get(jana.Id).Points_Balance__c,
                members.get(petr.Id).Points_Balance__c
            },
            'Voucher má patřit Janě a kapky se mají odečíst jen jí.'
        );
    }

    private static Loyalty_Member__c createActiveMember(Id accountId, Decimal kapky) {
        Loyalty_Member__c member = KapkaTestDataFactory.makeMember(accountId);
        member.Status__c = ACTIVE;
        insert member;
        insert KapkaTestDataFactory.makeTransaction(member.Id, EARN, POSTED, kapky);
        return member;
    }
}
