/**
 * Uplatnění kapek za voucher z katalogu odměn. Volá ho portál i back-office;
 * vše proběhne v jedné transakci, chyba vrátí vše zpět (C2).
 */
public with sharing class KapkaRedeemService {
    private static final String EARN = 'Earn';
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
        insert allocate(creditsOf(member.Id), redemption.Id, reward.Points_Cost__c);

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

    /** Zaúčtovaná připsání se zbytkem kapek v pořadí FIFO: nejdřív ta, která vyprší dřív. */
    private static List<Points_Transaction__c> creditsOf(Id memberId) {
        return [
            SELECT Id, Remaining_Points__c
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c = :memberId AND Type__c = :EARN AND Status__c = :POSTED AND Remaining_Points__c > 0
            WITH USER_MODE
            ORDER BY Expiration_Date__c ASC NULLS LAST, Transaction_Date__c ASC
        ];
    }

    private static List<Points_Allocation__c> allocate(
        List<Points_Transaction__c> credits,
        Id debitId,
        Decimal pointsNeeded
    ) {
        List<Points_Allocation__c> allocations = new List<Points_Allocation__c>();
        Decimal stillNeeded = pointsNeeded;
        for (Points_Transaction__c credit : credits) {
            if (stillNeeded <= 0) {
                break;
            }
            Decimal taken = Math.min(credit.Remaining_Points__c, stillNeeded);
            allocations.add(
                new Points_Allocation__c(Credit_Transaction__c = credit.Id, Debit_Transaction__c = debitId, Points__c = taken)
            );
            stillNeeded -= taken;
        }
        return allocations;
    }

    /** Zámek člena brání tomu, aby dvě současná čerpání utratila stejné kapky. */
    private static Loyalty_Member__c lockMember(Id memberId) {
        return [SELECT Id, Status__c FROM Loyalty_Member__c WHERE Id = :memberId WITH USER_MODE FOR UPDATE];
    }
}
