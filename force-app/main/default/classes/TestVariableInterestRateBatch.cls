@isTest
private class TestVariableInterestRateBatch {
    // standard loans
    @isTest static void test_daily_review() {
        // create a new interest rate source
        Interest_Rate_Source__c irs = new Interest_Rate_Source__c(Name = 'Test Interest Rate Source');
        insert irs;

        // create interest rates
        Interest_Rate__c ir1 = TestUtils.createNewInterestRate(irs.Id, System.today().addMonths(-1), 1);
        Interest_Rate__c ir2 = TestUtils.createNewInterestRate(irs.Id, System.today(), 2);
        
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct('Test Loan Product');
        lp.Interest_Rate_Source__c = 'Variable Interest';
        lp.Interest_Reference_Rate__c = irs.Id;
        lp.Interest_Rate_Review_Frequency__c = 'Daily';
        lp.CBO_Default_Variable_Interest_Spread__c = true;

        insert new List<SObject>{ir1, ir2, lp};
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-1), System.today());
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Variable_Interest_Spread__c = 5;
        i.Interest_Rate__c = null;
        update i;
        // add a disbursement
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', 'Disbursed', System.today().addMonths(-1));
        DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');

        List<Loan_Event__c> loanEvents = [
            SELECT Event_Date__c
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];

        // compare results
        System.assertEquals(1, loanEvents.size());
        System.assertEquals(System.today().addMonths(-1).addDays(1), loanEvents[0].Event_Date__c);
        
        // run the batch
        Test.startTest();
        Database.executebatch(new VariableInterestRateBatch(System.today().addDays(1)), 1);        
        Test.stopTest();

        List<Loan_Event__c> loanEvents2 = [
            SELECT Event_Date__c
            FROM Loan_Event__c
            WHERE Id NOT IN :loanEvents AND Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];

        // compare results
        System.assertEquals(1, loanEvents2.size());
        System.assertEquals(System.today().addDays(1), loanEvents2[0].Event_Date__c);
    }
    
    @isTest static void test_monthly_review() {
        // create a new interest rate source
        Interest_Rate_Source__c irs = new Interest_Rate_Source__c(Name = 'Test Interest Rate Source');
        insert irs;

        // create interest rates
        Interest_Rate__c ir1 = TestUtils.createNewInterestRate(irs.Id, System.today().addMonths(-1), 1);
        Interest_Rate__c ir2 = TestUtils.createNewInterestRate(irs.Id, System.today(), 2);
        
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
        i.Interest_Rate__c = null;
        update i;
        // add a disbursement
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', 'Disbursed', System.today().addMonths(-1));
        DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');

        List<Loan_Event__c> loanEvents = [
            SELECT Event_Date__c
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];

        // compare results
        System.assertEquals(1, loanEvents.size());
        System.assertEquals(System.today(), loanEvents[0].Event_Date__c);
        
        // run the batch
        Test.startTest();
        Database.executebatch(new VariableInterestRateBatch(System.today().addMonths(1)), 1);        
        Test.stopTest();

        List<Loan_Event__c> loanEvents2 = [
            SELECT Event_Date__c
            FROM Loan_Event__c
            WHERE Id NOT IN :loanEvents AND Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];

        // compare results
        System.assertEquals(1, loanEvents2.size());
        System.assertEquals(System.today().addMonths(1), loanEvents2[0].Event_Date__c);
    }

    @isTest static void test_quarterly_review() {
        // create a new interest rate source
        Interest_Rate_Source__c irs = new Interest_Rate_Source__c(Name = 'Test Interest Rate Source');
        insert irs;

        // create interest rates
        Interest_Rate__c ir1 = TestUtils.createNewInterestRate(irs.Id, System.today().addMonths(-3), 1);
        Interest_Rate__c ir2 = TestUtils.createNewInterestRate(irs.Id, System.today(), 2);
        
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct('Test Loan Product');
        lp.Interest_Rate_Source__c = 'Variable Interest';
        lp.Interest_Reference_Rate__c = irs.Id;
        lp.Interest_Rate_Review_Frequency__c = 'Quarterly';
        lp.CBO_Default_Variable_Interest_Spread__c = true;

        insert new List<SObject>{ir1, ir2, lp};
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-3), System.today().addMonths(-2));
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Variable_Interest_Spread__c = 5;
        i.Interest_Rate__c = null;
        update i;
        // add a disbursement
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', 'Disbursed', System.today().addMonths(-3));
        DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');

        List<Loan_Event__c> loanEvents = [
            SELECT Event_Date__c
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];

        // compare results
        System.assertEquals(1, loanEvents.size());
        System.assertEquals(System.today(), loanEvents[0].Event_Date__c);
        
        // run the batch
        Test.startTest();
        Database.executebatch(new VariableInterestRateBatch(System.today().addMonths(3)), 1);        
        Test.stopTest();

        List<Loan_Event__c> loanEvents2 = [
            SELECT Event_Date__c
            FROM Loan_Event__c
            WHERE Id NOT IN :loanEvents AND Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];

        // compare results
        System.assertEquals(1, loanEvents2.size());
        System.assertEquals(System.today().addMonths(3), loanEvents2[0].Event_Date__c);
    }

    @isTest static void test_yearly_review() {
        // create a new interest rate source
        Interest_Rate_Source__c irs = new Interest_Rate_Source__c(Name = 'Test Interest Rate Source');
        insert irs;

        // create interest rates
        Interest_Rate__c ir1 = TestUtils.createNewInterestRate(irs.Id, System.today().addYears(-1), 1);
        Interest_Rate__c ir2 = TestUtils.createNewInterestRate(irs.Id, System.today(), 2);
        
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct('Test Loan Product');
        lp.Interest_Rate_Source__c = 'Variable Interest';
        lp.Interest_Reference_Rate__c = irs.Id;
        lp.Interest_Rate_Review_Frequency__c = 'Yearly';
        lp.CBO_Default_Variable_Interest_Spread__c = true;

        insert new List<SObject>{ir1, ir2, lp};
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addYears(-1), System.today().addMonths(-11));
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Variable_Interest_Spread__c = 5;
        i.Interest_Rate__c = null;
        update i;

        // add a disbursement
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', 'Disbursed', System.today().addYears(-1));
        DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');

        List<Loan_Event__c> loanEvents = [
            SELECT Event_Date__c
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];

        // compare results
        System.assertEquals(1, loanEvents.size());
        System.assertEquals(System.today(), loanEvents[0].Event_Date__c);

        // run the batch
        Test.startTest();
        Database.executebatch(new VariableInterestRateBatch(System.today().addYears(1)), 1);        
        Test.stopTest();

        List<Loan_Event__c> loanEvents2 = [
            SELECT Event_Date__c
            FROM Loan_Event__c
            WHERE Id NOT IN :loanEvents AND Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];
        System.debug(loanEvents2.size());

        // compare results
        System.assertEquals(0, loanEvents2.size());
    }

    // open-ended loans
    @isTest static void test_open_ended_review() {
        // create a new interest rate source
        Interest_Rate_Source__c irs = new Interest_Rate_Source__c(Name = 'Test Interest Rate Source');
        insert irs;

        Date entryDate = Date.newInstance(System.today().year(), System.today().month(), 1);

        // create interest rates
        Interest_Rate__c ir1 = TestUtils.createNewInterestRate(irs.Id, entryDate.addMonths(-1), 1);
        Interest_Rate__c ir2 = TestUtils.createNewInterestRate(irs.Id, entryDate.addDays(-15), 2);
        Interest_Rate__c ir3 = TestUtils.createNewInterestRate(irs.Id, entryDate.addDays(-1), 3);
        
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct('Test Loan Product');
        lp.Interest_Rate_Source__c = 'Variable Interest';
        lp.Interest_Reference_Rate__c = irs.Id;
        lp.Interest_Rate_Review_Frequency__c = 'Monthly';
        lp.CBO_Default_Variable_Interest_Spread__c = true;

        insert new List<SObject>{ir1, ir2, ir3, lp};

        // create a new loan
        Investment__c i = TestUtils.createNewScheduledOpenEndedLoan(entryDate.addMonths(-1), 100);
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Variable_Interest_Spread__c = 5;
        i.Interest_Rate__c = null;
        update i;

        // add a disbursement
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', 'Disbursed', entryDate.addMonths(-1));
        DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');

        // run the batch
        Test.startTest();
        Database.executebatch(new VariableInterestRateBatch(entryDate), 1);        
        Test.stopTest();

        List<Loan_Event__c> loanEvents = [
            SELECT Event_Date__c
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Interest Rate Change'
        ];

        List<Repayment_Schedule__c> repaymentSchedules = [
            SELECT Interest_Rate__c
            FROM Repayment_Schedule__c
            WHERE Loan__c = :i.Id
            ORDER BY Due_Date__c ASC
        ];

        // compare results
        System.assertEquals(1, loanEvents.size());
        System.assertEquals(entryDate, loanEvents[0].Event_Date__c);
        System.assertEquals(ir3.Rate__c + i.Variable_Interest_Spread__c, repaymentSchedules[0].Interest_Rate__c);
        
    }
}