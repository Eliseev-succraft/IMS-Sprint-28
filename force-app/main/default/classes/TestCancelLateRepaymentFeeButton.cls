@isTest
private class TestCancelLateRepaymentFeeButton {
    @isTest static void test_cancel_Late_Repayment_Fee() {
        // create a loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;

        // create a loan in the past
        Investment__c i = TestUtils.createNewLoan(System.today().addmonths(-2), System.today().addmonths(-1));
        i.Loan_Product__c = lp.Id;
        i.Status__c = 'Inactive';
        i.Late_Repayment_Calculation_Method__c = 'Fixed Fee';
        i.Late_Repayment_Fixed_Fee__c = 1;
        i.Late_Repayment_Interest_Rate__c = null;
        i.Late_Repayment_Tolerance_Period__c = 5;
        i.Disbursement_Method__c = 'Full disbursement at start';
        insert i;
        
        // generate repayment schedules
        List<Repayment_Schedule__c> schedules = LoanScheduler.generateScheduleById(i.Id);
        insert schedules;

        Repayment_Schedule__c rs = [
            SELECT Late_Repayment_Fees_Expected0__c, Cancel_Late_Repayment_Fee__c, Due_Date__c 
            FROM Repayment_Schedule__c
            WHERE Loan__c = :i.Id 
            ORDER BY Due_Date__c
            LIMIT 1
        ];
        System.debug(rs);
        
        System.assert(rs.Late_Repayment_Fees_Expected0__c > 0);
        System.assert(!rs.Cancel_Late_Repayment_Fee__c);

        // cancel late repayment fee on the first repayment schedule
        CancelLateRepaymentFeeButtonController.cancelLateRepaymentFee(rs.Id);

        // check the creation of a loan event
        List<Loan_Event__c> les = [
            SELECT Approval_Status__c
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Fee Cancelled'
        ];
        System.assertEquals(1, les.size());
        
        Loan_Event__c le = les[0];
        if (le.Approval_Status__c == 'Pending Approval') {
            le.Approval_Status__c = 'Approved';
            update le;
        }
        
        Loan_Event_Detail__c led = [
            SELECT Due_Date__c
            FROM Loan_Event_Detail__c
            WHERE Loan_Event__c = :le.Id
            LIMIT 1
        ];
        System.assertEquals(rs.Due_Date__c, led.Due_Date__c);
       
        // check if repayment schedule was updated
        Repayment_Schedule__c rs1 = [
            SELECT Late_Repayment_Fees_Expected0__c, Cancel_Late_Repayment_Fee__c, Due_Date__c 
            FROM Repayment_Schedule__c
            WHERE Id = :rs.Id 
        ];
        System.debug(rs1);

        System.assert(rs1.Late_Repayment_Fees_Expected0__c == 0);
        System.assert(rs1.Cancel_Late_Repayment_Fee__c);

    }

}