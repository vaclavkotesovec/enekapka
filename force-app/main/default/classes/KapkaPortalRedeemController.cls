/**
 * Čerpání kapek z portálu. Člen se bere vždy z přihlášeného uživatele, nikdy z parametru (AC-5).
 *
 * without sharing záměrně (rozhodnutí P2, Q6): sdílení pro portál je mimo rozsah, člen portálu
 * nevidí vlastní záznam člena. Přístup omezuje to, že controller pracuje jen s členem přihlášeného uživatele.
 */
public without sharing class KapkaPortalRedeemController {
    @AuraEnabled
    public static Voucher__c redeem(Id rewardId) {
        try {
            return KapkaRedeemService.redeem(loggedInMemberId(), rewardId);
        } catch (KapkaRedeemException e) {
            AuraHandledException refusal = new AuraHandledException(e.getMessage());
            refusal.setMessage(e.getMessage());
            throw refusal;
        }
    }

    /** Člen přihlášeného uživatele: přednostně podle kontaktu (řidič firmy), jinak podle účtu (osoba). */
    private static Id loggedInMemberId() {
        User user = [SELECT ContactId, AccountId FROM User WHERE Id = :UserInfo.getUserId()];
        Id byAccount;
        for (Loyalty_Member__c member : [
            SELECT Id, Contact__c
            FROM Loyalty_Member__c
            WHERE (Contact__c != NULL AND Contact__c = :user.ContactId) OR (Account__c != NULL AND Account__c = :user.AccountId)
        ]) {
            if (member.Contact__c != null && member.Contact__c == user.ContactId) {
                return member.Id;
            }
            byAccount = member.Id;
        }
        if (byAccount == null) {
            throw new KapkaRedeemException(Label.Kapka_Redeem_MemberInactive);
        }
        return byAccount;
    }
}
