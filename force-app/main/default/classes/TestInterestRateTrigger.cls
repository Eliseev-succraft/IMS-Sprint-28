@isTest
private class TestInterestRateTrigger {
	@isTest static void test_insert_interest_rate_for_standard_loan_monthly() {
        // create a new interest rate source
        Interest_Rate_Source__c irs = new Interest_Rate_Source__c(Name = 'Test Interest Rate Source');
        insert irs;

        // create interest rates
        Interest_Rate__c ir1 = TestUtils.createNewInterestRate(irs.Id, System.today().addMonths(-2), 1);
        Interest_Rate__c ir2 = TestUtils.createNewInterestRate(irs.Id, System.today().addDays(-45), 3);
        
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct('Test Loan Product');
        lp.Interest_Rate_Source__c = 'Variable Interest';
        lp.Interest_Reference_Rate__c = irs.Id;
        lp.Interest_Rate_Review_Frequency__c = 'Monthly';
        lp.CBO_Default_Variable_Interest_Spread__c = true;

        insert new List<SObject>{ir1, ir2, lp};
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-2), System.today().addMonths(-1));
        i.Status__c = 'Active';
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Variable_Interest_Spread__c = 5;
        update i;

        // create a loan event
        Loan_Event__c le = new Loan_Event__c(
            Event_Date__c = System.today().addMonths(-1),                     
            Investment__c = i.Id,
            Loan_Event_Type__c = 'Interest Rate Change',
            Loan_Product__c = lp.Id
        );
        insert le;

        Interest_Rate__c ir3 = TestUtils.createNewInterestRate(irs.Id, System.today().addDays(-5), 5);
        
        // perform test
        Test.startTest();
        insert ir3;        
        Test.stopTest();

        List<Loan_Event__c> loanEvents = [
            SELECT Id
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];

        List<Interest_Rate__c> interestRates = [
            SELECT Rate__c, Date__c
            FROM Interest_Rate__c
            WHERE Interest_Rate_Source__c =: irs.Id
            ORDER BY Name
        ];

        // compare results
        System.assertEquals(2, loanEvents.size());
        System.assertEquals(3, interestRates.size());
        System.assertEquals(ir3.Date__c, interestRates[2].Date__c);
        System.assertEquals(ir3.Rate__c, interestRates[2].Rate__c);
    }

    @isTest static void test_insert_interest_rate_for_standard_loan_quarterly() {
        // create a new interest rate source
        Interest_Rate_Source__c irs = new Interest_Rate_Source__c(Name = 'Test Interest Rate Source');
        insert irs;

        // create interest rates
        Interest_Rate__c ir1 = TestUtils.createNewInterestRate(irs.Id, System.today().addMonths(-6), 1);
        
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct('Test Loan Product');
        lp.Interest_Rate_Source__c = 'Variable Interest';
        lp.Interest_Reference_Rate__c = irs.Id;
        lp.Interest_Rate_Review_Frequency__c = 'Quarterly';
        lp.CBO_Default_Variable_Interest_Spread__c = true;

        insert new List<SObject>{ir1, lp};
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-6), System.today().addMonths(-5));
        i.Status__c = 'Active';
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Variable_Interest_Spread__c = 5;
        update i;

        // create a loan event
        Loan_Event__c le = new Loan_Event__c(
            Event_Date__c = System.today().addMonths(-3),                     
            Investment__c = i.Id,
            Loan_Event_Type__c = 'Interest Rate Change',
            Loan_Product__c = lp.Id
        );
        insert le;

        Interest_Rate__c ir2 = TestUtils.createNewInterestRate(irs.Id, System.today().addMonths(-1), 3);
        
        // perform test
        Test.startTest();
        insert ir2;        
        Test.stopTest();

        List<Loan_Event__c> loanEvents = [
            SELECT Id
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];

        List<Interest_Rate__c> interestRates = [
            SELECT Rate__c, Date__c
            FROM Interest_Rate__c
            WHERE Interest_Rate_Source__c =: irs.Id
            ORDER BY Name
        ];

        // compare results
        System.assertEquals(2, loanEvents.size());
        System.assertEquals(2, interestRates.size());
        System.assertEquals(ir2.Date__c, interestRates[1].Date__c);
        System.assertEquals(ir2.Rate__c, interestRates[1].Rate__c);
    }

    @isTest static void test_insert_interest_rate_for_standard_loan_yearly() {
        // create a new interest rate source
        Interest_Rate_Source__c irs = new Interest_Rate_Source__c(Name = 'Test Interest Rate Source');
        insert irs;

        // create interest rates
        Interest_Rate__c ir1 = TestUtils.createNewInterestRate(irs.Id, System.today().addYears(-1), 1);
        Interest_Rate__c ir2 = TestUtils.createNewInterestRate(irs.Id, System.today().addMonths(-6), 2);
        
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct('Test Loan Product');
        lp.Interest_Rate_Source__c = 'Variable Interest';
        lp.Interest_Reference_Rate__c = irs.Id;
        lp.Interest_Rate_Review_Frequency__c = 'Yearly';
        lp.CBO_Default_Variable_Interest_Spread__c = true;

        insert new List<SObject>{ir1, ir2, lp};
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addYears(-1), System.today().addMonths(-11));
        i.Status__c = 'Active';
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Variable_Interest_Spread__c = 5;
        update i;

        // create a loan event
        Loan_Event__c le = new Loan_Event__c(
            Event_Date__c = System.today(),                     
            Investment__c = i.Id,
            Loan_Event_Type__c = 'Interest Rate Change',
            Loan_Product__c = lp.Id
        );
        insert le;

        // perform test
        Test.startTest();
        ir2.Rate__c = 2.5;
        ir2.Date__c = System.today().addMonths(-4);
        update ir2;     
        Test.stopTest();

        List<Loan_Event__c> loanEvents = [
            SELECT Id
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];

        List<Interest_Rate__c> interestRates = [
            SELECT Rate__c, Date__c
            FROM Interest_Rate__c
            WHERE Interest_Rate_Source__c =: irs.Id
            ORDER BY Name
        ];

        // compare results
        System.assertEquals(1, loanEvents.size());
        System.assertEquals(2, interestRates.size());
        System.assertEquals(System.today().addMonths(-4), interestRates[1].Date__c);
        System.assertEquals(2.5, interestRates[1].Rate__c);
    }

    @isTest static void test_delete_interest_rate_for_standard_loan() {
        // create a new interest rate source
        Interest_Rate_Source__c irs = new Interest_Rate_Source__c(Name = 'Test Interest Rate Source');
        insert irs;

        // create interest rates
        Interest_Rate__c ir1 = TestUtils.createNewInterestRate(irs.Id, System.today().addMonths(-1), 1);
        Interest_Rate__c ir2 = TestUtils.createNewInterestRate(irs.Id, System.today().addDays(-1), 3);
        
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct('Test Loan Product');
        lp.Interest_Rate_Source__c = 'Variable Interest';
        lp.Interest_Reference_Rate__c = irs.Id;
        lp.Interest_Rate_Review_Frequency__c = 'Monthly';
        lp.CBO_Default_Variable_Interest_Spread__c = true;

        insert new List<SObject>{ir1, ir2, lp};
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-1), System.today());
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Variable_Interest_Spread__c = 5;
        update i;

        // create a loan event
        Loan_Event__c le = new Loan_Event__c(
            Event_Date__c = System.today(),                     
            Investment__c = i.Id,
            Loan_Event_Type__c = 'Interest Rate Change',
            Loan_Product__c = lp.Id
        );
        insert le;

        // perform test
        Test.startTest();
        delete ir2;        
        Test.stopTest();

        List<Loan_Event__c> loanEvents = [
            SELECT Id
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];

        List<Interest_Rate__c> interestRates = [
            SELECT Id
            FROM Interest_Rate__c
            WHERE Interest_Rate_Source__c =: irs.Id
        ];

        // compare results
        System.assert(loanEvents.isEmpty());
        System.assertEquals(1, interestRates.size());
        System.assertEquals(ir1.Id, interestRates[0].Id);
        
    }

    @isTest static void test_delete_interest_rate_for_open_ended_loan() {
        // create a new interest rate source
        Interest_Rate_Source__c irs = new Interest_Rate_Source__c(Name = 'Test Interest Rate Source');
        insert irs;

        // create interest rates
        Interest_Rate__c ir1 = TestUtils.createNewInterestRate(irs.Id, System.today().addMonths(-1), 1);
        Interest_Rate__c ir2 = TestUtils.createNewInterestRate(irs.Id, System.today().addDays(-1), 3);
        
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct('Test Loan Product');
        lp.Interest_Rate_Source__c = 'Variable Interest';
        lp.Interest_Reference_Rate__c = irs.Id;
        lp.Interest_Rate_Review_Frequency__c = 'Monthly';
        lp.CBO_Default_Variable_Interest_Spread__c = true;

        insert new List<SObject>{ir1, ir2, lp};

        // create a new loan
        Investment__c i = TestUtils.createNewScheduledOpenEndedLoan(System.today().addMonths(-1), 100);
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Variable_Interest_Spread__c = 5;
        update i;

        // create a loan event
        Loan_Event__c le = new Loan_Event__c(
            Event_Date__c = System.today(),                     
            Investment__c = i.Id,
            Loan_Event_Type__c = 'Interest Rate Change',
            Loan_Product__c = lp.Id
        );
        insert le;

        // perform test
        Test.startTest();
        delete ir2;        
        Test.stopTest();

        List<Loan_Event__c> loanEvents = [
            SELECT Id
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];

        List<Interest_Rate__c> interestRates = [
            SELECT Id
            FROM Interest_Rate__c
            WHERE Interest_Rate_Source__c =: irs.Id
        ];

        // compare results
        System.assert(loanEvents.isEmpty());
        System.assertEquals(1, interestRates.size());
        System.assertEquals(ir1.Id, interestRates[0].Id);
        
    }
}