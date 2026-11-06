/**
 * Jediný zdroj testovacích dat Kapka Klubu. Metody make* vrací neuložené záznamy,
 * metody create* je rovnou vloží. Hodnoty z AC patří do testů, ne sem.
 */
@IsTest
public class KapkaTestDataFactory {
    public static final Date DEFAULT_VALID_FROM = Date.newInstance(2026, 1, 1);

    public static Earning_Rule__c makeEarningRule(
        String productFamily,
        String basis,
        Decimal unitSize,
        Decimal pointsPerUnit,
        Date validFrom
    ) {
        return new Earning_Rule__c(
            Name = productFamily + ' ' + basis,
            Product_Family__c = productFamily,
            Basis__c = basis,
            Unit_Size__c = unitSize,
            Points_Per_Unit__c = pointsPerUnit,
            Valid_From__c = validFrom
        );
    }

    public static Loyalty_Campaign__c makeCampaign(
        String name,
        String conditionType,
        Decimal threshold,
        String rewardType,
        Decimal rewardValue
    ) {
        return new Loyalty_Campaign__c(
            Name = name,
            Condition_Type__c = conditionType,
            Threshold__c = threshold,
            Reward_Type__c = rewardType,
            Reward_Value__c = rewardValue,
            Valid_From__c = DEFAULT_VALID_FROM,
            Is_Active__c = true
        );
    }

    public static Account createPartner(String name) {
        Account partner = new Account(Name = name);
        insert partner;
        return partner;
    }

    public static Reward__c makeReward(Id partnerId, String name, Decimal pointsCost) {
        return new Reward__c(Name = name, Partner__c = partnerId, Points_Cost__c = pointsCost);
    }

    public static Voucher__c makeVoucher(Id memberId, Id rewardId, String code) {
        return new Voucher__c(Loyalty_Member__c = memberId, Reward__c = rewardId, Code__c = code);
    }

    public static Applied_Campaign__c makeAppliedCampaign(Id earnTransactionId, Id campaignId, Decimal points) {
        return new Applied_Campaign__c(
            Points_Transaction__c = earnTransactionId,
            Loyalty_Campaign__c = campaignId,
            Points__c = points
        );
    }

    // ---- model-jadro: člen, nákup, kniha kapek, souhlasy ----

    public static final Datetime DEFAULT_PURCHASE_DATE = Datetime.newInstance(2026, 11, 6, 8, 30, 0);
    public static final String MARKETING_PURPOSE = 'Marketing';
    public static final String LOYALTY_PURPOSE = 'Loyalty';

    /** Person Account s navázaným Individual (kvůli souhlasům v PartyConsent). */
    public static Account createPersonAccount(String firstName, String lastName) {
        Individual person = new Individual(FirstName = firstName, LastName = lastName);
        insert person;
        Account account = new Account(
            RecordTypeId = personAccountRecordTypeId(),
            FirstName = firstName,
            LastName = lastName,
            PersonIndividualId = person.Id
        );
        insert account;
        return account;
    }

    public static Account createCompany(String name) {
        Account company = new Account(Name = name);
        insert company;
        return company;
    }

    public static Contact createContact(Id accountId, String firstName, String lastName) {
        Contact driver = new Contact(AccountId = accountId, FirstName = firstName, LastName = lastName);
        insert driver;
        return driver;
    }

    public static Loyalty_Member__c makeMember(Id accountId) {
        return new Loyalty_Member__c(Account__c = accountId);
    }

    /** Člen pro osobu – nejčastější výchozí stav testů nákupů a pohybů. */
    public static Loyalty_Member__c createMember(String firstName, String lastName) {
        Loyalty_Member__c member = makeMember(createPersonAccount(firstName, lastName).Id);
        insert member;
        return member;
    }

    public static Fuel_Station__c createStation(String name, String stationCode) {
        Fuel_Station__c station = new Fuel_Station__c(Name = name, Station_Code__c = stationCode);
        insert station;
        return station;
    }

    public static Product2 createProduct(String name, String family, Decimal price) {
        Product2 product = new Product2(Name = name, Family = family, Price__c = price, IsActive = true);
        insert product;
        return product;
    }

    public static Order__c makeOrder(Id memberId, Id stationId, String receiptNumber) {
        return new Order__c(
            Loyalty_Member__c = memberId,
            Fuel_Station__c = stationId,
            Receipt_Number__c = receiptNumber,
            Purchase_Date__c = DEFAULT_PURCHASE_DATE
        );
    }

    public static Order_Item__c makeOrderItem(Id orderId, Id productId, Decimal quantity) {
        return new Order_Item__c(Order__c = orderId, Product__c = productId, Quantity__c = quantity);
    }

    public static Points_Transaction__c makeTransaction(Id memberId, String type, String status, Decimal points) {
        return new Points_Transaction__c(
            Loyalty_Member__c = memberId,
            Type__c = type,
            Status__c = status,
            Points__c = points,
            Transaction_Date__c = DEFAULT_PURCHASE_DATE
        );
    }

    public static Points_Allocation__c makeAllocation(Id creditId, Id debitId, Decimal points) {
        return new Points_Allocation__c(Credit_Transaction__c = creditId, Debit_Transaction__c = debitId, Points__c = points);
    }

    /** Účely zpracování programu: Marketing a Loyalty (Q13), klíčem je název. */
    public static Map<String, DataUsePurpose> createDataUsePurposes() {
        Map<String, DataUsePurpose> purposes = new Map<String, DataUsePurpose>{
            MARKETING_PURPOSE => new DataUsePurpose(Name = MARKETING_PURPOSE, CanDataSubjectOptOut = true),
            LOYALTY_PURPOSE => new DataUsePurpose(Name = LOYALTY_PURPOSE, CanDataSubjectOptOut = true)
        };
        insert purposes.values();
        return purposes;
    }

    /** Udělený souhlas (Opt In) osoby s daným účelem. */
    public static PartyConsent makeOptInConsent(Id individualId, DataUsePurpose purpose) {
        return new PartyConsent(
            Name = purpose.Name + ' – Opt In',
            PartyId = individualId,
            DataUsePurposeId = purpose.Id,
            Action = 'Data Collection',
            PrivacyConsentStatus = 'OptIn',
            CaptureDate = DEFAULT_PURCHASE_DATE
        );
    }

    private static Id personAccountRecordTypeId() {
        return [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND IsPersonType = TRUE LIMIT 1].Id;
    }
}
