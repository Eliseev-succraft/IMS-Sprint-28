@isTest
private class TestPopulateLoanExpectedAmountBatch {
    @isTest static void test_batch_methods_standard_loan() {
        // create a loan starting 6 months back, so there will be some amounts due
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addmonths(-6), System.today().addmonths(-5));
        i.Status__c = 'Active';
        update i;

        // run the batch job
        Test.startTest();
        PopulateLoanExpectedAmountBatch theBatch = new PopulateLoanExpectedAmountBatch();
        Database.executebatch(theBatch);        
        Test.stopTest();

        Investment__c result = [
            SELECT Late_Repayment_Fees_Expected0__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];

        AggregateResult rsResult = [
            SELECT SUM(Late_Repayment_Fees_Expected0__c) lateRepaymentFeesExpected
            FROM Repayment_Schedule__c
            WHERE Loan__c =: i.Id
        ];
        System.debug(rsResult);
        
        System.assertEquals(result.Late_Repayment_Fees_Expected0__c, rsResult.get('lateRepaymentFeesExpected'));
    }

    @isTest static void test_batch_methods_open_ended_loan() {
        // create a loan starting 6 months back, so there will be some amounts due
        Investment__c i = TestUtils.createNewScheduledOpenEndedLoan(System.today().addDays(-7), 100);
        i.Status__c = 'Active';
        update i;

        // run the batch job
        Test.startTest();
        PopulateLoanExpectedAmountBatch theBatch = new PopulateLoanExpectedAmountBatch();
        Database.executebatch(theBatch);        
        Test.stopTest();

        Investment__c result = [
            SELECT Interest_Expected_Open_Ended_Loan__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];

        AggregateResult rsResult = [
            SELECT SUM(Interest_Expected_Open_Ended_Loan__c) interestExpected
            FROM Repayment_Schedule__c
            WHERE Loan__c =: i.Id
        ];
        System.debug(rsResult);
        
        System.assertEquals(result.Interest_Expected_Open_Ended_Loan__c, rsResult.get('interestExpected'));
    }
    
}