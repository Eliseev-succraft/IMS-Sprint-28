@isTest
private class TestCreateRemainingScheduleBatch {
    @isTest static void test_batch() {
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;
        
        // create a new loan
        Investment__c i = TestUtils.createNewLoan(System.today().addMonths(-1), System.today());
        i.Loan_Product__c = lp.Id;
        i.Setup_Fee_Charging_Method__c = null;
        i.Disbursement_Method__c = 'Full disbursement at start';
        insert i;

        // generate schedule
        List<Repayment_Schedule__c> expectedRS = LoanScheduler.generateScheduleById(i.Id);
        
        // populate migrated fields
        Repayment_Schedule__c rs = expectedRS[0];
        i.Migrated_Outstanding_Capital__c = i.Amount__c;
        i.Migrated_Instalment_Amount__c = rs.Principal_Expected__c + rs.Interest_Expected_Standard_Loan__c + rs.Fees_Expected__c;
        i.Migrated_Next_First_Repayment_Date__c = i.First_Repayment_Date__c;
        i.Create_Remaining_Schedule__c = true;
        update i;

        // pefrorm test
        Test.startTest();
        Database.executeBatch(new CreateRemainingScheduleBatch(), 1);
		Test.stopTest();

        List<Repayment_Schedule__c> actualRS = [
            SELECT Due_Date__c, Principal_Expected__c, Interest_Expected0__c, Fees_Expected__c, Principal_Balance__c
            FROM Repayment_Schedule__c
            WHERE Loan__c = :i.Id
            ORDER BY Due_Date__c ASC
        ];

        // compare results
        System.assertEquals(expectedRS.size(), actualRS.size());
        for (Integer k = 0; k < actualRS.size(); k++) {
            System.assertEquals(expectedRS[k].Principal_Expected__c.setscale(2), actualRS[k].Principal_Expected__c.setscale(2));
            System.assertEquals(expectedRS[k].Interest_Expected_Standard_Loan__c.setscale(2), actualRS[k].Interest_Expected0__c.setscale(2));
            System.assertEquals(expectedRS[k].Fees_Expected__c.setscale(2), actualRS[k].Fees_Expected__c.setscale(2));
            System.assertEquals(expectedRS[k].Principal_Balance__c.setscale(2), actualRS[k].Principal_Balance__c.setscale(2));
        }
    }

}