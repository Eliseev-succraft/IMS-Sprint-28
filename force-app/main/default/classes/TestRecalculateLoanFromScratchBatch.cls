@isTest
private class TestRecalculateLoanFromScratchBatch {
    @isTest static void test_batch() {
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-2), System.today().addMonths(-1));
        i.Loan_Product__c = lp.Id;
        i.Setup_Fee_Charging_Method__c = 'Paid Up Front (scheduled)';
        i.Disbursement_Method__c = 'Tranched disbursement allowed';
        update i;
        // add a disbursement
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c/2, 'Disbursement', System.today().addMonths(-2));
        DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');

        // add a repayment
        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, i.Amount__c/12, 'Repayment', System.today().addMonths(-1));
        insert t2;

        List<Repayment_Schedule__c> expectedRS = [
            SELECT Principal_Expected__c, Interest_Expected0__c, Principal_Paid__c, Interest_Paid__c, Active__c
            FROM Repayment_Schedule__c
            WHERE Loan__c = :i.Id
            ORDER BY Due_Date__c ASC
        ];

        i.Recalculation_Status__c = 'Pending Recalculation';
        update i;

        // pefrorm test
        Test.startTest();
        Database.executeBatch(new RecalculateLoanFromScratchBatch(), 1);
		Test.stopTest();

        List<Repayment_Schedule__c> actualRS = [
            SELECT Principal_Expected__c, Interest_Expected0__c, Principal_Paid__c, Interest_Paid__c, Active__c
            FROM Repayment_Schedule__c
            WHERE Loan__c = :i.Id
            ORDER BY Due_Date__c ASC
        ];

        // compare results
        System.assertEquals(expectedRS.size(), actualRS.size());
        for (Integer k = 0; k < actualRS.size(); k++) {
            System.assertEquals(expectedRS[k].Principal_Expected__c.setscale(2), actualRS[k].Principal_Expected__c.setscale(2));
            System.assertEquals(expectedRS[k].Interest_Expected0__c.setscale(2), actualRS[k].Interest_Expected0__c.setscale(2));
            System.assertEquals(expectedRS[k].Principal_Paid__c.setscale(2), actualRS[k].Principal_Paid__c.setscale(2));
            System.assertEquals(expectedRS[k].Interest_Paid__c.setscale(2), actualRS[k].Interest_Paid__c.setscale(2));
            System.assertEquals(expectedRS[k].Active__c, actualRS[k].Active__c);
        }
    }
}