/**
 * Kód voucheru KPK-XXXX-XXXX, který jde nadiktovat do telefonu:
 * abeceda bez zaměnitelných znaků 0, O, 1, I a L (C4).
 *
 * without sharing záměrně: kolize se musí hledat ve všech voucherech, nejen v těch,
 * které volající vidí (člen v portálu cizí vouchery nevidí). Třída vrací jen nové kódy, žádná data.
 */
public without sharing class KapkaVoucherCodeGenerator {
    private static final String ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    private static final String PREFIX = 'KPK';
    private static final Integer GROUP_LENGTH = 4;
    private static final Integer MAX_ROUNDS = 5;

    public class CodeExhaustedException extends Exception {
    }

    /** Nové kódy, které se neshodují s žádným existujícím voucherem ani mezi sebou. */
    public static List<String> newCodes(Integer count) {
        Set<String> codes = new Set<String>();
        for (Integer round = 0; round < MAX_ROUNDS; round++) {
            while (codes.size() < count) {
                codes.add(randomCode());
            }
            codes.removeAll(existingCodes(codes));
            if (codes.size() == count) {
                return new List<String>(codes);
            }
        }
        throw new CodeExhaustedException('Po ' + MAX_ROUNDS + ' pokusech se nepodařilo vygenerovat unikátní kód voucheru.');
    }

    private static Set<String> existingCodes(Set<String> candidates) {
        Set<String> existing = new Set<String>();
        for (Voucher__c voucher : [SELECT Code__c FROM Voucher__c WHERE Code__c IN :candidates WITH SYSTEM_MODE]) {
            existing.add(voucher.Code__c);
        }
        return existing;
    }

    private static String randomCode() {
        return PREFIX + '-' + randomGroup() + '-' + randomGroup();
    }

    private static String randomGroup() {
        String result = '';
        for (Integer i = 0; i < GROUP_LENGTH; i++) {
            Integer index = Math.mod(Math.abs(Crypto.getRandomInteger()), ALPHABET.length());
            result += ALPHABET.substring(index, index + 1);
        }
        return result;
    }
}
