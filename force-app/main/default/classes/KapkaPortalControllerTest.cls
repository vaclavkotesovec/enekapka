/**
 * Karta portal-site: portál ukazuje člena přihlášeného uživatele.
 * Seam S1 z plánu: KapkaPortalController.getCurrentMember přes System.runAs portálového uživatele.
 */
@IsTest
private class KapkaPortalControllerTest {
    private static final String EARN = 'Earn';
    private static final String POSTED = 'Posted';

    // AC-1.1
    @IsTest
    static void janaSeesHerMembership() {
        // Pokud Jana Nováková má portálový účet, je aktivní členkou a má 109 kapek
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        insert KapkaTestDataFactory.makeTransaction(KapkaTestDataFactory.memberOf(jana).Id, EARN, POSTED, 109);

        // Když se přihlásí do portálu
        KapkaPortalController.MemberView shown;
        Test.startTest();
        System.runAs(jana) {
            shown = KapkaPortalController.getCurrentMember();
        }
        Test.stopTest();

        // Pak vidí své jméno, stav členství a kapky
        Assert.areEqual(
            new List<Object>{ 'Jana Nováková', 'Aktivní', (Decimal) 109 },
            new List<Object>{ shown.name, shown.status, shown.balance },
            'Jana má v portálu vidět sebe jako aktivní členku se 109 kapkami.'
        );
    }

    // AC-3.1
    @IsTest
    static void userWithoutMembershipGetsNoMember() {
        // Pokud portálový uživatel nemá přiřazeného člena Kapka Klubu
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        delete KapkaTestDataFactory.memberOf(jana);

        // Když se přihlásí
        String shownMessage;
        Test.startTest();
        System.runAs(jana) {
            try {
                KapkaPortalController.getCurrentMember();
            } catch (AuraHandledException e) {
                shownMessage = e.getMessage();
            }
        }
        Test.stopTest();

        // Pak vidí hlášku, že k účtu není přiřazené členství
        Assert.areEqual(
            'K tomuto účtu zatím není přiřazené členství v Kapka Klubu.',
            shownMessage,
            'Uživatel bez členství má vidět srozumitelnou hlášku.'
        );
    }
}
