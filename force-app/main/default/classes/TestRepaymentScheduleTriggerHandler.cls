@isTest
private class TestRepaymentScheduleTriggerHandler {
	
	@isTest static void test_field_update_methods() {
		User platformUser = TestUtils.createPlatformUser();

        System.runAs(platformUser){     
            // initially total paid = 0
            Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-1), System.today());
            
            // take the first schedule and check the status
            Repayment_Schedule__c rs = [Select Id, Status__c, Total_Expected__c, Total_Paid__c From Repayment_Schedule__C Where Loan__c = :i.Id ORDER BY Due_Date__c ASC LIMIT 1];
            System.debug(rs);
            System.assertEquals('Late', rs.Status__c);
        }
    }

    @isTest static void test_delete_methods() {
		User platformUser = TestUtils.createPlatformUser();

        System.runAs(platformUser){        
            // default number of instalments - 12
            Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-1), System.today());
            
            // take the first schedule and delete it
            Repayment_Schedule__c rs = [Select Id, Status__c, Total_Expected__c, Total_Paid__c From Repayment_Schedule__c Where Loan__c = :i.Id ORDER BY Due_Date__c ASC LIMIT 1];
            delete rs;
            System.assertEquals(11,[Select Id, Status__c, Total_Expected__c, Total_Paid__c From Repayment_Schedule__C Where Loan__c = :i.Id].size());
        }
    }   

    @isTest static void test_populate_late_repayment_fixed_fee() {
        // create a loan in the past
        Investment__c i = TestUtils.createNewLoan(System.today().addmonths(-2), System.today().addmonths(-1));
        i.Status__c = 'Active';
        i.Late_Repayment_Calculation_Method__c = 'Fixed Fee';
        i.Late_Repayment_Fixed_Fee__c = 1;
        i.Late_Repayment_Interest_Rate__c = null;
        i.Late_Repayment_Tolerance_Period__c = 5;
        insert i;
        
        // generate repayment schedules
        List<Repayment_Schedule__c> schedules = LoanScheduler.generateScheduleById(i.Id);
        insert schedules;

        Repayment_Schedule__c rs = [
            SELECT Late_Repayment_Fixed_Fee__c 
            FROM Repayment_Schedule__c 
            WHERE Loan__c = :i.Id 
            ORDER BY Due_Date__c ASC 
            LIMIT 1
        ];

        // verify if Late Repayment Fixed Fee was calculated
        System.assertEquals(i.Late_Repayment_Fixed_Fee__c, rs.Late_Repayment_Fixed_Fee__c);
    } 
}