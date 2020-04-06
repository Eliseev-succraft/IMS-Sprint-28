@isTest
private class TestLoanHealthCheckBatch {
    @isTest static void test_populate_issues() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today(), System.today().addMonths(1));
        i.Status__c = 'Active';
        update i;

        List<String> result = LoanHealthCheckController.getLoanData(i.Id);
        System.debug(result);
        System.assertEquals(0, result.size());
        
        Repayment_Schedule__c rs = [
            SELECT Expected_Principal_Balance__c
            FROM Repayment_Schedule__c
            WHERE Loan__c =: i.Id AND Active__c = true
            ORDER BY Due_Date__c DESC
            LIMIT 1
        ];
        rs.Expected_Principal_Balance__c = 1;
        update rs;

        // run the batch job
        Test.startTest();
        LoanHealthCheckBatch theBatch = new LoanHealthCheckBatch();
        Database.executebatch(theBatch);        
        Test.stopTest();

        Investment__c inv = [
            SELECT Health_Check_Fails__c, Health_Check_Failures__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];
        System.assert(inv.Health_Check_Fails__c);
        System.assertEquals(System.Label.sfims.health_check_5, inv.Health_Check_Failures__c);
        
    }

    @isTest static void test_clear_issues() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today(), System.today().addMonths(1));
        i.Status__c = 'Active';
        update i;

        List<String> result = LoanHealthCheckController.getLoanData(i.Id);
        System.debug(result);
        System.assertEquals(0, result.size());
        
        Repayment_Schedule__c rs = [
            SELECT Expected_Principal_Balance__c
            FROM Repayment_Schedule__c
            WHERE Loan__c =: i.Id AND Active__c = true
            ORDER BY Due_Date__c DESC
            LIMIT 1
        ];
        rs.Expected_Principal_Balance__c = 1;
        update rs;

        List<String> result2 = LoanHealthCheckController.getLoanData(i.Id);
        System.debug(result2);
        System.assertEquals(1, result2.size());
        System.assertEquals(System.Label.sfims.health_check_5, result2[0]);

        i.Health_Check_Fails__c = true;
        i.Health_Check_Failures__c = System.Label.sfims.health_check_5;
        update i;
        rs.Expected_Principal_Balance__c = 0;
        update rs;

        // run the batch job
        Test.startTest();
        LoanHealthCheckBatch theBatch = new LoanHealthCheckBatch();
        Database.executebatch(theBatch);        
        Test.stopTest();

        Investment__c inv = [
            SELECT Health_Check_Fails__c, Health_Check_Failures__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];
        System.assert(!inv.Health_Check_Fails__c);
        System.assertEquals(null, inv.Health_Check_Failures__c);
        
    }
    
}