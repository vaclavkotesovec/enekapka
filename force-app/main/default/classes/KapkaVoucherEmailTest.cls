/**
 * Karta cerpani-email: příjemce e-mailu s kódem voucheru a vydání voucheru bez e-mailu.
 * Doručení e-mailu (flow + Email Alert) se ověřuje ručně v orgu (seam S2).
 */
@IsTest
private class KapkaVoucherEmailTest {
    private static final String REWARD_NAME = 'Sleva 200 Kč na přezutí';

    private static Voucher__c issueVoucher(Id memberId, String code) {
        Account partner = KapkaTestDataFactory.createPartner('EneServis');
        Reward__c reward = KapkaTestDataFactory.makeReward(partner.Id, REWARD_NAME, 400);
        insert reward;
        Voucher__c voucher = KapkaTestDataFactory.makeVoucher(memberId, reward.Id, code);
        insert voucher;
        return [SELECT Id, Code__c, Member_Email__c, Reward_Name__c FROM Voucher__c WHERE Id = :voucher.Id];
    }

    @IsTest
    static void personMemberEmailIsVoucherRecipient() {
        Account jana = KapkaTestDataFactory.createPersonAccount('Jana', 'Nováková');
        jana.PersonEmail = 'jana.novakova@example.com';
        update jana;
        Loyalty_Member__c member = KapkaTestDataFactory.makeMember(jana.Id);
        insert member;

        Test.startTest();
        Voucher__c voucher = issueVoucher(member.Id, 'KPK-TEST-0001');
        Test.stopTest();

        Assert.areEqual('jana.novakova@example.com', voucher.Member_Email__c, 'E-mail jde osobě');
        Assert.areEqual(REWARD_NAME, voucher.Reward_Name__c, 'Šablona zná název odměny');
    }

    @IsTest
    static void companyMemberEmailGoesToDriver() {
        Account company = KapkaTestDataFactory.createCompany('Doprava Brno s.r.o.');
        Contact driver = KapkaTestDataFactory.createDriver(company.Id, 'Petr', 'Řidič');
        driver.Email = 'petr.ridic@example.com';
        update driver;
        Loyalty_Member__c member = new Loyalty_Member__c(Account__c = company.Id, Contact__c = driver.Id);
        insert member;

        Test.startTest();
        Voucher__c voucher = issueVoucher(member.Id, 'KPK-TEST-0002');
        Test.stopTest();

        Assert.areEqual('petr.ridic@example.com', voucher.Member_Email__c, 'E-mail firmy jde řidiči');
    }

    @IsTest
    static void voucherWithoutEmailIsIssued() {
        Loyalty_Member__c member = KapkaTestDataFactory.createMember('Bez', 'Emailu');

        Test.startTest();
        Voucher__c voucher = issueVoucher(member.Id, 'KPK-TEST-0003');
        Test.stopTest();

        Assert.isNotNull(voucher.Id, 'Voucher je vydán i bez e-mailu');
        Assert.isNull(voucher.Member_Email__c, 'Bez e-mailu není komu poslat');
    }
}
