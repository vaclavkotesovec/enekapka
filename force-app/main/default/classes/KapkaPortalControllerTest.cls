/**
 * Karta portal-site: portál ukazuje člena přihlášeného uživatele.
 * Seam S1 z plánu: KapkaPortalController.getCurrentMember přes System.runAs portálového uživatele.
 */
@IsTest
private class KapkaPortalControllerTest {
    private static final String EARN = 'Earn';
    private static final String POSTED = 'Posted';
    private static final String REDEEM = 'Redeem';
    private static final String CANCELLED = 'Cancelled';

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

    // AC-3.2
    @IsTest
    static void controllerNeverReturnsOtherMember() {
        // Pokud je přihlášena Jana a existuje člen Petr s 2 000 kapkami
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        User petr = KapkaTestDataFactory.createPortalMember('Petr', 'Svoboda');
        insert new List<Points_Transaction__c>{
            KapkaTestDataFactory.makeTransaction(KapkaTestDataFactory.memberOf(jana).Id, EARN, POSTED, 109),
            KapkaTestDataFactory.makeTransaction(KapkaTestDataFactory.memberOf(petr).Id, EARN, POSTED, 2000)
        };

        // Když portál načte data člena
        KapkaPortalController.MemberView shown;
        Test.startTest();
        System.runAs(jana) {
            shown = KapkaPortalController.getCurrentMember();
        }
        Test.stopTest();

        // Pak dostane jen data Jany
        Assert.areEqual(
            new List<Object>{ 'Jana Nováková', (Decimal) 109 },
            new List<Object>{ shown.name, shown.balance },
            'Portál nesmí Janě ukázat data jiného člena.'
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

    // ---- karta portal-zustatek ----

    // portal-zustatek AC-1.1
    @IsTest
    static void janaSeesBalanceOf109() {
        // Pokud Jana má zaúčtované připsání 109 kapek
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        insert KapkaTestDataFactory.makeTransaction(KapkaTestDataFactory.memberOf(jana).Id, EARN, POSTED, 109);

        // Když otevře v portálu Domů
        KapkaPortalController.MemberView shown;
        Test.startTest();
        System.runAs(jana) {
            shown = KapkaPortalController.getCurrentMember();
        }
        Test.stopTest();

        // Pak vidí zůstatek 109 kapek
        Assert.areEqual((Decimal) 109, shown.balance, 'Jana má vidět zůstatek 109 kapek.');
    }

    // portal-zustatek AC-2.1, AC-2.2
    @IsTest
    static void expiringKapkyAreReturned() {
        // Pokud Janě vyprší do 30 dnů 40 kapek a Petrovi žádné
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        User petr = KapkaTestDataFactory.createPortalMember('Petr', 'Svoboda');
        Loyalty_Member__c janaMember = KapkaTestDataFactory.memberOf(jana);
        janaMember.Points_Expiring_Next_30_Days__c = 40;
        update janaMember;

        // Když otevřou Domů
        KapkaPortalController.MemberView janaShown;
        KapkaPortalController.MemberView petrShown;
        Test.startTest();
        System.runAs(jana) {
            janaShown = KapkaPortalController.getCurrentMember();
        }
        System.runAs(petr) {
            petrShown = KapkaPortalController.getCurrentMember();
        }
        Test.stopTest();

        // Pak Jana dostane 40 expirujících kapek a Petr 0 (upozornění neuvidí)
        Assert.areEqual(
            new List<Object>{ (Decimal) 40, (Decimal) 0 },
            new List<Object>{ janaShown.expiringSoon, petrShown.expiringSoon },
            'Expirující kapky mají odpovídat členovi; bez expirace je hodnota 0.'
        );
    }

    // portal-zustatek AC-3.1
    @IsTest
    static void historyShowsNewestFirstWithReason() {
        // Pokud Jana má připsání 109 z nákupu s kampaněmi a čerpání -500 za odměnu
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        Id memberId = KapkaTestDataFactory.memberOf(jana).Id;
        Fuel_Station__c station = KapkaTestDataFactory.createStation('Kapka Brno – Vídeňská', 'BRN01');
        Order__c order = KapkaTestDataFactory.makeOrder(memberId, station.Id, 'R-HIST-1');
        insert order;
        List<Loyalty_Campaign__c> campaigns = new List<Loyalty_Campaign__c>{
            KapkaTestDataFactory.makeCampaign('Zastávka na cestě', 'Min Fuel Liters', 40, 'Fixed Points', 10),
            KapkaTestDataFactory.makeCampaign('Natankuj plnou', 'Min Fuel Liters', 40, 'Fixed Points', 50)
        };
        insert campaigns;
        Points_Transaction__c earn = KapkaTestDataFactory.makeTransaction(memberId, EARN, POSTED, 109);
        earn.Order__c = order.Id;
        earn.Transaction_Date__c = Datetime.newInstance(2026, 11, 6, 10, 0, 0);
        Points_Transaction__c redeem = KapkaTestDataFactory.makeTransaction(memberId, REDEEM, POSTED, -500);
        redeem.Transaction_Date__c = Datetime.newInstance(2026, 11, 6, 11, 0, 0);
        insert new List<Points_Transaction__c>{ earn, redeem };
        insert KapkaTestDataFactory.makeAppliedCampaign(earn.Id, campaigns[0].Id, 10);
        insert KapkaTestDataFactory.makeAppliedCampaign(earn.Id, campaigns[1].Id, 50);
        Reward__c reward = KapkaTestDataFactory.makeReward(
            KapkaTestDataFactory.createPartner('Pneuservis').Id,
            'Sleva 200 Kč na přezutí',
            500
        );
        insert reward;
        Voucher__c voucher = KapkaTestDataFactory.makeVoucher(memberId, reward.Id, 'KPK-HIST-0001');
        voucher.Points_Transaction__c = redeem.Id;
        insert voucher;

        // Když otevře Domů
        List<KapkaPortalController.HistoryRow> history;
        Test.startTest();
        System.runAs(jana) {
            history = KapkaPortalController.getHistory();
        }
        Test.stopTest();

        // Pak vidí oba pohyby od nejnovějšího s typem, důvodem a kapkami
        List<String> shown = new List<String>();
        for (Integer i = 0; i < 2; i++) {
            shown.add(history[i].type + ' | ' + history[i].reason + ' | ' + history[i].points);
        }
        Assert.areEqual(
            new List<String>{
                'Čerpání | Sleva 200 Kč na přezutí | -500',
                'Připsání | Kapka Brno – Vídeňská, Zastávka na cestě, Natankuj plnou | 109'
            },
            shown,
            'Historie má ukázat čerpání a nákup od nejnovějšího s důvodem.'
        );
        Assert.isNotNull(history[0].transactionDate, 'Pohyb má mít datum.');
    }

    // portal-zustatek AC-3.2
    @IsTest
    static void cancelledTransactionsAreHidden() {
        // Pokud má Jana zrušený pohyb a jeden zaúčtovaný
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        Id memberId = KapkaTestDataFactory.memberOf(jana).Id;
        Points_Transaction__c posted = KapkaTestDataFactory.makeTransaction(memberId, EARN, POSTED, 109);
        insert new List<Points_Transaction__c>{
            posted,
            KapkaTestDataFactory.makeTransaction(memberId, EARN, CANCELLED, 77)
        };

        // Když otevře Domů
        List<KapkaPortalController.HistoryRow> history;
        Test.startTest();
        System.runAs(jana) {
            history = KapkaPortalController.getHistory();
        }
        Test.stopTest();

        // Pak zrušený pohyb v historii nevidí
        List<Id> shownIds = new List<Id>();
        for (KapkaPortalController.HistoryRow row : history) {
            shownIds.add(row.id);
        }
        Assert.areEqual(new List<Id>{ posted.Id }, shownIds, 'Zrušený pohyb se v historii nesmí ukázat.');
    }

    // portal-zustatek AC-3.3
    @IsTest
    static void newMemberHasEmptyHistory() {
        // Pokud člen nemá žádný pohyb
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');

        // Když otevře Domů
        KapkaPortalController.MemberView shown;
        List<KapkaPortalController.HistoryRow> history;
        Test.startTest();
        System.runAs(jana) {
            shown = KapkaPortalController.getCurrentMember();
            history = KapkaPortalController.getHistory();
        }
        Test.stopTest();

        // Pak vidí zůstatek 0 kapek a prázdnou historii (UI ukáže výzvu)
        Assert.areEqual(
            new List<Object>{ (Decimal) 0, 0 },
            new List<Object>{ shown.balance, history.size() },
            'Nový člen má zůstatek 0 a prázdnou historii.'
        );
    }

    // portal-zustatek P3
    @IsTest
    static void historyIsLimitedTo50() {
        // Pokud má Jana 55 pohybů
        User jana = KapkaTestDataFactory.createPortalMember('Jana', 'Nováková');
        Id memberId = KapkaTestDataFactory.memberOf(jana).Id;
        List<Points_Transaction__c> transactions = new List<Points_Transaction__c>();
        for (Integer i = 0; i < 55; i++) {
            Points_Transaction__c tx = KapkaTestDataFactory.makeTransaction(memberId, EARN, POSTED, 1);
            tx.Transaction_Date__c = Datetime.newInstance(2026, 10, 1, 8, 0, 0).addHours(i);
            transactions.add(tx);
        }
        insert transactions;

        // Když otevře Domů
        List<KapkaPortalController.HistoryRow> history;
        Test.startTest();
        System.runAs(jana) {
            history = KapkaPortalController.getHistory();
        }
        Test.stopTest();

        // Pak vidí jen posledních 50, první je nejnovější
        Assert.areEqual(
            new List<Object>{ 50, transactions[54].Id },
            new List<Object>{ history.size(), history[0].id },
            'Historie má ukázat posledních 50 pohybů od nejnovějšího.'
        );
    }
}
