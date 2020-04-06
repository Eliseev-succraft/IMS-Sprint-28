@isTest
private class TestSecurityTrigger {
    @isTest static void test_populate_investment_fields() {
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;
        
        // create a new loan
        Investment__c i1 = TestUtils.createNewScheduledLoan();
        i1.Loan_Product__c = lp.Id;
        i1.Disbursement_Method__c = 'Full disbursement at start';
        update i1;

        // create securities
        Security__c s1 = TestUtils.createCollateral(i1.Id);
        Security__c s2 = TestUtils.createGuarantee(i1.Id);
        insert new List<Security__c>{ s1, s2 };

        Investment__c result = [
            SELECT Total_Collateral__c, Total_Guarantee__c
            FROM Investment__c
            WHERE Id = :i1.Id
        ];
        
        // check results
        System.assertEquals(s1.Amount__c, result.Total_Collateral__c);
        System.assertEquals(s2.Amount__c, result.Total_Guarantee__c);

        // create a new loan
        Investment__c i2 = TestUtils.createNewScheduledLoan();
        i2.Loan_Product__c = lp.Id;
        i2.Disbursement_Method__c = 'Full disbursement at start';
        update i2;

        //update securities
        s1.Amount__c = 500;
        s2.Investment__c = i2.Id;
        update new List<Security__c>{ s1, s2 };

        Investment__c result2 = [
            SELECT Total_Collateral__c, Total_Guarantee__c
            FROM Investment__c
            WHERE Id = :i1.Id
        ];

        Investment__c result3 = [
            SELECT Total_Collateral__c, Total_Guarantee__c
            FROM Investment__c
            WHERE Id = :i2.Id
        ];
        
        // check results
        System.assertEquals(s1.Amount__c, result2.Total_Collateral__c);
        System.assertEquals(0, result2.Total_Guarantee__c);
        System.assertEquals(null, result3.Total_Collateral__c);
        System.assertEquals(s2.Amount__c, result3.Total_Guarantee__c);
        
        // change recordtype
        s1.RecordTypeId = Utility.guaranteeRecordTypeId;
        update s1;

        Investment__c result4 = [
            SELECT Total_Collateral__c, Total_Guarantee__c
            FROM Investment__c
            WHERE Id = :i1.Id
        ];

        // check results
        System.assertEquals(0, result4.Total_Collateral__c);
        System.assertEquals(s1.Amount__c, result4.Total_Guarantee__c);
        
        // change status
        s1.Status__c = 'Requested';
        update s1;

        Investment__c result5 = [
            SELECT Total_Collateral__c, Total_Guarantee__c
            FROM Investment__c
            WHERE Id = :i1.Id
        ];

        // check results
        System.assertEquals(0, result5.Total_Collateral__c);
        System.assertEquals(0, result5.Total_Guarantee__c);

        // return status
        s1.Status__c = 'Confirmed';
        update s1;

        Investment__c result6 = [
            SELECT Total_Collateral__c, Total_Guarantee__c
            FROM Investment__c
            WHERE Id = :i1.Id
        ];

        // check results
        System.assertEquals(0, result6.Total_Collateral__c);
        System.assertEquals(s1.Amount__c, result6.Total_Guarantee__c);

        // delete a security
        delete s1;

        Investment__c result7 = [
            SELECT Total_Collateral__c, Total_Guarantee__c
            FROM Investment__c
            WHERE Id = :i1.Id
        ];

        // check results
        System.assertEquals(0, result7.Total_Collateral__c);
        System.assertEquals(0, result7.Total_Guarantee__c);
    }
}