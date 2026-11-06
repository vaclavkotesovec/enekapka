/**
 * Portál Kapka Klub – stránka Odměny: katalog a moje vouchery (karta portal-katalog).
 * Uplatnění odměny dělá KapkaRedeemService přes portálový controller z karty cerpani-voucher (R7).
 *
 * without sharing + SYSTEM_MODE: DEMO, sharing a práva portálu mockujeme (Rozhodnutí Q6, P2).
 * Pracuje jen s členem přihlášeného uživatele z KapkaPortalContext.
 */
public without sharing class KapkaPortalRewardController {
    private static final String EARN = 'Earn';
    private static final String POSTED = 'Posted';

    public class RewardView {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public String partnerName;
        @AuraEnabled public Decimal pointsCost;
        @AuraEnabled public Decimal valueCzk;
        @AuraEnabled public Decimal missingKapky;
    }

    public class VoucherView {
        @AuraEnabled public String code;
        @AuraEnabled public String rewardName;
        @AuraEnabled public Datetime issuedDate;
        @AuraEnabled public String status;
    }

    /** Aktivní odměny s cenou a kolik kapek členovi chybí (AC-1, AC-2). */
    @AuraEnabled
    public static List<RewardView> getRewards() {
        Decimal available = availableKapky(KapkaPortalContext.currentMember());
        List<RewardView> views = new List<RewardView>();
        for (Reward__c reward : [
            SELECT Id, Name, Description__c, Partner__r.Name, Points_Cost__c, Value_CZK__c
            FROM Reward__c
            WHERE Is_Active__c = TRUE
            WITH SYSTEM_MODE
            ORDER BY Points_Cost__c
        ]) {
            RewardView view = new RewardView();
            view.id = reward.Id;
            view.name = reward.Name;
            view.description = reward.Description__c;
            view.partnerName = reward.Partner__r.Name;
            view.pointsCost = reward.Points_Cost__c;
            view.valueCzk = reward.Value_CZK__c;
            view.missingKapky = Math.max(0, reward.Points_Cost__c - available);
            views.add(view);
        }
        return views;
    }

    /** Vouchery přihlášeného člena od nejnovějšího (AC-4). */
    @AuraEnabled
    public static List<VoucherView> getMyVouchers() {
        Loyalty_Member__c member = KapkaPortalContext.currentMember();
        List<VoucherView> views = new List<VoucherView>();
        if (member == null) {
            return views;
        }
        for (Voucher__c voucher : [
            SELECT Code__c, Reward__r.Name, Issued_Date__c, toLabel(Status__c)
            FROM Voucher__c
            WHERE Loyalty_Member__c = :member.Id
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
        ]) {
            VoucherView view = new VoucherView();
            view.code = voucher.Code__c;
            view.rewardName = voucher.Reward__r.Name;
            view.issuedDate = voucher.Issued_Date__c;
            view.status = voucher.Status__c;
            views.add(view);
        }
        return views;
    }

    /** Kapky k čerpání = součet zbytků zaúčtovaných připsání, stejně jako počítá čerpání (C2). */
    private static Decimal availableKapky(Loyalty_Member__c member) {
        if (member == null) {
            return 0;
        }
        AggregateResult total = [
            SELECT SUM(Remaining_Points__c) remaining
            FROM Points_Transaction__c
            WHERE Loyalty_Member__c = :member.Id AND Type__c = :EARN AND Status__c = :POSTED
            WITH SYSTEM_MODE
        ];
        Decimal remaining = (Decimal) total.get('remaining');
        return remaining == null ? 0 : remaining;
    }
}
