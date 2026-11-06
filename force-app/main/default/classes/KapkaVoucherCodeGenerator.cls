/**
 * Kód voucheru KPK-XXXX-XXXX, který jde nadiktovat do telefonu:
 * abeceda bez zaměnitelných znaků 0, O, 1, I a L (C4).
 */
public with sharing class KapkaVoucherCodeGenerator {
    private static final String ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    private static final String PREFIX = 'KPK';
    private static final Integer GROUP_LENGTH = 4;

    public static String newCode() {
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
