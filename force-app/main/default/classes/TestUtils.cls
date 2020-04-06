/**
 *  @Decription     This class contains utility methods to support the unit tests for validating the behavior of Apex classes
 *                  and triggers.
 *  @author         Singlify - Guy Clairbois
 *
 */
@IsTest
public class TestUtils {

    /**
     * autoCommit property.
     * If the auto commit property of this class is set True then all the create functions in this class
     * will automatically insert the created objects into the database, otherwise only the created object is returned.
     * The default value is True.
     */
    public static Boolean autoCommit {
        get {
            if (autoCommit == null) {
                autoCommit = true;
            }
            return autoCommit;
        }
        set;
    }

    // create a 'normal' singlify user.
    public static User thePlatformUser { get; set; }
    public static User createPlatformUser() {
        User testUser;
        UserRole adminRole = [SELECT Id FROM UserRole WHERE Name = 'CEO' LIMIT 1];
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Singlify Standard Platform User' LIMIT 1];
        testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Alias = 'TestUser',
            Email = 'testUser@singlify.com',
            Username = 'testdealer@singlify.com',
            CommunityNickname = 'TestUser',
            //UserRoleId = adminRole.Id,
            TimeZoneSidKey = 'Europe/Amsterdam',
            LocaleSidKey = 'nl_NL',
            EmailEncodingKey = 'ISO-8859-1',
            ProfileId = profile.Id,
            LanguageLocaleKey = 'en_US'
        );
        if (autoCommit) {
            insert testUser;
        }
        thePlatformUser = testUser;
        return testUser;
    }

    public static Account theAccount { get; set; }
    
    public static Account createAccount(String recordTypeDeveloperName) {
        return createAccount(recordTypeDeveloperName, 'Test Account', null);
    }

    public static Account createAccount(String recordTypeDeveloperName, String name, User owner) {
        Account acct = new Account(
            Name = name != null ? name : 'Test Account',
            OwnerId = owner != null ? owner.Id : UserInfo.getUserId(),
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(recordTypeDeveloperName).getRecordTypeId()
        );
        // if (autoCommit) {insert acct;}
        // theAccount = acct;
        return acct;
    }

    public static Application__c theApplication { get; set; }
    
    public static Application__c createNewApplication() {
        return TestUtils.createNewApplication(null);
    }
    public static Application__c createNewApplication(Id accountId) {
        Application__c newApplication = new Application__c();
        if (accountId == null) {
            Account acc = createAccount('Investee_Account');
            insert acc;
            accountId = acc.Id;
        } 
        newApplication.Organisation__c = accountId;
        newApplication.Name = 'testApplication';
        // if (autoCommit) {insert newApplication;}
        // theApplication = newApplication;
        return newApplication;
    }

    public static Milestone_Configuration__c createNewMilestoneConfiguration() {
        return TestUtils.createNewMilestoneConfiguration('Application', 'Application', 'Application', 2);
    }

    public static Milestone_Configuration__c createNewMilestoneConfiguration(String obj, String stage, String milestoneName, Decimal sequence) {
        return new Milestone_Configuration__c(
            Object__c = obj,
            Stage__c = stage,
            Milestone_Name__c = milestoneName,
            Sequence__c = sequence
        );
    }
    public static Milestone_History__c createNewMilestoneHistory(String milestoneName, Decimal sequence, Id applicationId) {
        return TestUtils.createNewMilestoneHistory(System.today(), milestoneName, sequence, applicationId);
    }

    public static Milestone_History__c createNewMilestoneHistory(Date milestoneDate, String milestoneName, Decimal sequence, Id applicationId) {
        return new Milestone_History__c(
            Milestone_Date__c = milestoneDate,
            Milestone__c = milestoneName,
            Sequence__c = sequence,
            Application__c = applicationId
        );
    }

    public static Loan_Product__c createNewLoanProduct() {
        return TestUtils.createNewLoanProduct('Test Loan Product');
    }
    
    public static Loan_Product__c createNewLoanProduct(String loanProductName) {
        return TestUtils.createNewLoanProduct(loanProductName, 'Schedule-based', 'Interest;Late Repayment Fees;Fees;Principal');
    }

    public static Loan_Product__c createNewLoanProduct(String loanProductName, String type, String order) {
        Loan_Product__c loanProduct = new Loan_Product__c(
            Name = loanProductName,
            Active__c = true,
            Repayment_Allocation_Type__c = type,
            Repayment_Allocation_Order__c = order,
            Grace_Period_Types__c = 'No Grace;Pay Admin Fees Only;Pay Interest Only;Full Grace;Interest Rollup;',
            Interest_Rate_Source__c = 'Fixed Interest',
            CBO_Day_Count_Convention__c = true,
            CBO_Default_Interest_Rate__c = true,
            CBO_Default_Loan_Amount__c = true,
            CBO_Default_Monitoring_Fee_Percentage__c = true,
            CBO_Default_number_of_installments__c = true,
            CBO_Disbursement_Method__c = true,
            CBO_Early_Payment_Method__c = true,
            CBO_Flat_Amount__c = true,
            CBO_Late_Repayment_Calculation_Method__c = true,
            CBO_Late_Repayment_Interest_Rate__c = true,
            CBO_Late_Repayment_Tolerance_Period__c = true,
            CBO_Open_Ended_Loan__c = true,
            CBO_Percent_Of_Disbursement_Amount__c = true,
            CBO_Repayment_Frequency_Unit__c = true,
            CBO_Repayment_Frequency__c = true,
            CBO_Setup_Fee_Charging_Method__c = true,
            CBO_Setup_Fee__c = true
        );
        return loanProduct;
    }

    public static Investment__c theLoan { get; set; }
    public static Investment__c createNewLoan() {
        Account acc = createAccount('Investee_Account');
        insert acc;
        return TestUtils.createNewLoan(acc.Id, System.today().addMonths(-1), System.today());
    }

    public static Investment__c createNewLoan(Id accountId) {
        return TestUtils.createNewLoan(accountId, System.today().addMonths(-1), System.today());
    }

    public static Investment__c createNewLoan(Date disbursementDate, Date firstRepaymentDate) {
        Account acc = createAccount('Investee_Account');
        insert acc;
        return TestUtils.createNewLoan(acc.Id, disbursementDate, firstRepaymentDate);
    }

    public static Investment__c createNewLoan(Id accountId, Date disbursementDate, Date firstRepaymentDate) {
        Investment__c i = new Investment__c(
            Name = 'Test Loan',
            RecordTypeId = Utility.loanRecordTypeId,
            Number_of_Instalments__c = 12,
            Amount__c = 100,
            Interest_Rate__c = 5,
            Repayment_Frequency__c = 1,
            Repayment_Frequency_Unit__c = 'Months',
            Number_of_Grace_Periods__c = 0,
            Grace_Period_Type__c = 'None',
            Late_Repayment_Calculation_Method__c = 'Principal+Interest',
            Late_Repayment_Interest_Rate__c = 2,
            Late_Repayment_Tolerance_Period__c = 0,
            Setup_Fee__c = '% of Disbursement Amount',
            Percent_of_Disbursement_Amount__c = 2,
            Disbursement_Date__c = disbursementDate,
            First_Repayment_Date__c = firstRepaymentDate,
            Early_Payment_Method__c = 'interestDueToDate',
            Setup_Fee_Charging_Method__c = 'Capitalized'
        );
        if (accountId == null) {
            Account acc = createAccount('Investee_Account');
            insert acc;
            accountId = acc.Id;
        }
        i.Account__c = accountId;
        
        return i;
    }

    public static User ensureRestrictedUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Read Only'];

        User newUser = new User(Alias = 'standt', Email = 'standarduser@testorg.com',
            EmailEncodingKey = 'UTF-8', LastName = 'Testing', LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', Username = 'crudmanageruser1@testorg.com');

        insert newUser;
        return newUser;
    }

    public static Investment__c createNewScheduledLoan() {
        return TestUtils.createNewScheduledLoan(System.today(), System.today());
    }

    public static Investment__c createNewScheduledLoan(String accountId) {
        return TestUtils.createNewScheduledLoan(accountId, System.today(), System.today());
    }

    public static Investment__c createNewScheduledLoan(Date disbursementDate, Date firstRepaymentDate) {
        return TestUtils.createNewScheduledLoan(null, disbursementDate, firstRepaymentDate);
    }

    public static Investment__c createNewScheduledLoan(String accountId, Date disbursementDate, Date firstRepaymentDate) {
        Investment__c i = TestUtils.createNewLoan(accountId, disbursementDate, firstRepaymentDate);
        insert i;

        List<Repayment_Schedule__c> schedules = LoanScheduler.generateScheduleById(i.Id);
        insert schedules;

        return i;
    }

    public static Investment__c createOpenEndedLoan() {
        return TestUtils.createOpenEndedLoan(System.today());
    }

    public static Investment__c createOpenEndedLoan(Date disbursementDate) {
        return TestUtils.createOpenEndedLoan(disbursementDate, 100);
    }

    public static Investment__c createOpenEndedLoan(Date disbursementDate, Decimal amount) {
        Account acc = createAccount('Investee_Account');
        insert acc;
    
        Investment__c i = new Investment__c(
            Name = 'Test Loan',
            RecordTypeId = Utility.loanRecordTypeId,
            Account__c = acc.Id,
            Open_Ended_Loan__c = true,
            Disbursement_Date__c = disbursementDate,
            Amount__c = amount,
            Interest_Rate__c = 3.65
        );

        return i;
    }

    public static Investment__c createNewScheduledOpenEndedLoan() {
        return TestUtils.createNewScheduledOpenEndedLoan(System.today(), 100);
    }

    public static Investment__c createNewScheduledOpenEndedLoan(Date disbursementDate, Decimal amount) {
        Investment__c i = TestUtils.createOpenEndedLoan(disbursementDate, amount);
        insert i;
        List<Repayment_Schedule__c> schedules = LoanScheduler.generateScheduleById(i.Id);
        insert schedules;
        return i;
    }

    public static Transaction__c createNewTransaction(String investmentId, Decimal amount, String type) {
        return TestUtils.createNewTransaction(investmentId, amount, type, System.today());
    }

    public static Transaction__c createNewTransaction(String investmentId, Decimal amount, String type, Date transactionDate) {
        String status;
        switch on type {
            when 'Disbursement' {
                status = 'Disbursed';
            }
            when 'Repayment' {
                status = 'Received';
            }
        }
        return TestUtils.createNewTransaction(investmentId, amount, type, status, transactionDate);
    }

    public static Transaction__c createNewTransaction(String investmentId, Decimal amount, String type, String status, Date transactionDate) {
        Transaction__c tr = new Transaction__c(
            Investment__c = investmentId,
            Transaction_Date__c = transactionDate,
            Type__c = type,
            Status__c = status,
            Amount__c = amount
        );
        return tr;
    }

    public static Interest_Rate__c createNewInterestRate(String interestRateSource, Date interestRateDate, Decimal interestRate) {
        Interest_Rate__c ir = new Interest_Rate__c(
            Interest_Rate_Source__c = interestRateSource,
            Date__c = interestRateDate,
            Rate__c = interestRate
        );
        return ir;
    }

    public static Fund__c createFund(String fundName) {
        return new Fund__c(Name = fundName);
    }

    public static Fund_Assessor__c createFundAssessor(Fund__c fund) {
        return new Fund_Assessor__c(Fund__c = fund.Id);
    }

    public static Assessment_Stage_Definition__c createAssessmentStageDefinition(Fund__c fund, String applicationStage, String applicationAssessmentStage, String assessors, Integer NumberOfAssessments) {
        return new Assessment_Stage_Definition__c(
            Fund__c = fund.Id,
            Application_Stage__c = applicationStage,
            Application_Assessment_Stage__c = applicationAssessmentStage,
            Assessors__c = assessors,
            Number_of_Assessments__c = NumberOfAssessments
        ); 
    }

    public static Assessment_Stage_Definition__c createAssessmentStageDefinition(Fund__c fund, String applicationStage, String applicationAssessmentStage, String assessors) {
        return createAssessmentStageDefinition(fund, applicationStage, applicationAssessmentStage, assessors, null);
    }

    public static Assessment_Criteria_Definition__c createAssessmentCriteriaDefinition(Assessment_Stage_Definition__c assessmentStageDefinition, String type) {
        return new Assessment_Criteria_Definition__c(
            Assessment_Stage_Definition__c = assessmentStageDefinition.Id,
            Type__c = type
        );
    }

    public static Security__c createCollateral(String investmentId) {
        return createCollateral('Test Collateral', investmentId, 'Real estate', 'Confirmed', 1000);
    }

    public static Security__c createCollateral(String name, String investmentId) {
        return createCollateral(name, investmentId, 'Real estate', 'Confirmed', 1000);
    }

    public static Security__c createCollateral(String name, String investmentId, String type, String status, Decimal amount) {
        return new Security__c(
            Name = name,
            RecordTypeId = Utility.collateralRecordTypeId,
            Investment__c = investmentId,
            Type__c = type,
            Status__c = status,
            Amount__c = amount
        );
    }

    public static Security__c createGuarantee(String investmentId) {
        return createGuarantee('Test Collateral', investmentId, 'Individual', 'Confirmed', 1000);
    }

    public static Security__c createGuarantee(String name, String investmentId) {
        return createGuarantee(name, investmentId, 'Individual', 'Confirmed', 1000);
    }

    public static Security__c createGuarantee(String name, String investmentId, String type, String status, Decimal amount) {
        return new Security__c(
            Name = name,
            RecordTypeId = Utility.guaranteeRecordTypeId,
            Investment__c = investmentId,
            Type__c = type,
            Status__c = status,
            Amount__c = amount
        );
    } 
}