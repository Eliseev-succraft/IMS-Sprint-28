@isTest
private class TestRecalculateInterestRollupLoansBatch {
    @isTest static void test_batch() {
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
        lp.Interest_Rate_Review_Frequency__c = 'Daily';
        lp.CBO_Default_Variable_Interest_Spread__c = true;

        insert new List<SObject>{ir1, ir2, lp};
        
        // create a new loan
        Investment__c i = TestUtils.createNewLoan(System.today().addYears(-1), System.today().addMonths(-11));
        i.Loan_Product__c = lp.Id;
        i.Setup_Fee_Charging_Method__c = 'No Setup Fee';
        i.Number_of_Instalments__c = 60;
        i.Grace_Period_Type__c = 'Interest Rollup';
        i.Number_of_Grace_Periods__c = 12;    
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Variable_Interest_Spread__c = 5;
        i.Interest_Rate__c = null;
        insert i;

        // generate schedule
        insert LoanScheduler.generateScheduleById(i.Id);

        // add a disbursement
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', System.today().addYears(-1));
        DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');

        // run the batch
        Test.startTest();
        Database.executeBatch(new RecalculateInterestRollupLoansBatch(System.today()), 1);
        Test.stopTest();

        Date entryDate = System.today();
        System.assertEquals(1, [
            SELECT COUNT()
            FROM Loan_Event__c
            WHERE Investment__c = :i.Id AND Loan_Event_Type__c = 'Interest Rollup Recalculation' AND Event_Date__c = :entryDate
        ]);

        System.assertEquals(i.Number_of_Grace_Periods__c, [
            SELECT COUNT()
            FROM Repayment_Schedule__c
            WHERE Loan__c = :i.Id AND Status__c = 'Grace'
        ]);
    }
}