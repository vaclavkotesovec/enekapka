/**
 * Uplatnění kapek za voucher z katalogu odměn. Volá ho portál i back-office;
 * vše proběhne v jedné transakci, chyba vrátí vše zpět (C2).
 */
public with sharing class KapkaRedeemService {
    private static final String REDEEM = 'Redeem';
    private static final String POSTED = 'Posted';
    private static final String SOURCE_REWARD = 'Reward';
    private static final String VOUCHER_ISSUED = 'Issued';

    public static Voucher__c redeem(Id memberId, Id rewardId) {
        Loyalty_Member__c member = lockMember(memberId);
        Reward__c reward = [SELECT Id, Points_Cost__c FROM Reward__c WHERE Id = :rewardId WITH USER_MODE];

        Points_Transaction__c redemption = new Points_Transaction__c(
            Loyalty_Member__c = member.Id,
            Type__c = REDEEM,
            Status__c = POSTED,
            Source__c = SOURCE_REWARD,
            Points__c = -reward.Points_Cost__c,
            Transaction_Date__c = System.now()
        );
        // Zápis v systémovém režimu: knihu kapek a vouchery zakládá jen tahle služba,
        // člen ani loyalty manažer na ně nemají právo zápisu.
        insert redemption;

        Voucher__c voucher = new Voucher__c(
            Loyalty_Member__c = member.Id,
            Reward__c = reward.Id,
            Points_Transaction__c = redemption.Id,
            Code__c = KapkaVoucherCodeGenerator.newCode(),
            Status__c = VOUCHER_ISSUED,
            Issued_Date__c = System.now()
        );
        insert voucher;
        return voucher;
    }

    /** Zámek člena brání tomu, aby dvě současná čerpání utratila stejné kapky. */
    private static Loyalty_Member__c lockMember(Id memberId) {
        return [SELECT Id, Status__c FROM Loyalty_Member__c WHERE Id = :memberId WITH USER_MODE FOR UPDATE];
    }
}
