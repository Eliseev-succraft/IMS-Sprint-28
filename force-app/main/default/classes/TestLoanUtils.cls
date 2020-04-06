@isTest
private class TestLoanUtils {
	
	@isTest static void test_getLoanSchedule() {
	
        // initially total paid = 0
        Investment__c i = TestUtils.createNewScheduledLoan(System.today(), System.today().addMonths(1));

        List<Repayment_Schedule__c> repList = LoanUtils.getLoanSchedule(i.Id);
        System.assertEquals([SELECT COUNT() FROM Repayment_Schedule__c WHERE Loan__c =: i.Id],repList.size());

        // test the same with unauthorized user
		User newUser = TestUtils.ensureRestrictedUser();
		System.runAs(newUser){
            List<Repayment_Schedule__c> repList2;
			try{
				repList2 = LoanUtils.getLoanSchedule(i.Id);
				System.assert(false,'Expected an exception (unauthorized user');
			} catch (AuraHandledException e){
                // expected
                system.assertEquals(repList2,null);
            }
        }         

    }

	@isTest static void test_getLoanScheduleWrappers() {
	
        // initially total paid = 0
        Investment__c i = TestUtils.createNewScheduledLoan(System.today(), System.today().addMonths(1));

        List<RepaymentScheduleWrapper> repList = LoanUtils.getLoanScheduleWrappers(i.Id);
        system.assertEquals([SELECT COUNT() FROM Repayment_Schedule__c WHERE Loan__c =: i.Id],repList.size());


        // test the same with unauthorized user
		User newUser = TestUtils.ensureRestrictedUser();
		System.runAs(newUser){
            List<RepaymentScheduleWrapper> repList2;
			try{
				repList2 = LoanUtils.getLoanScheduleWrappers(i.Id);
				System.assert(false,'Expected an exception (unauthorized user');
			} catch (AuraHandledException e){
                // expected
                system.assertEquals(repList2,null);
            }
        }  
    }

	@isTest static void test_updateLoanSchedule() {
		
        // initially total paid = 0
        Investment__c i = TestUtils.createNewScheduledLoan(System.today(), System.today().addMonths(1));
        List<Repayment_Schedule__c> rsList = [SELECT Fees_Expected__c FROM Repayment_Schedule__c WHERE Loan__c =: i.Id];
        rsList[0].Fees_Expected__c = 10;

        Boolean success = LoanUtils.updateLoanSchedule(rsList);
        system.assertEquals(10,[SELECT Fees_Expected__c FROM Repayment_Schedule__c WHERE Id = :rsList[0].Id].Fees_Expected__c);
        
        // test the same with unauthorized user
		User newUser = TestUtils.ensureRestrictedUser();
		System.runAs(newUser){
            Boolean success2;
			try{
				success2 = LoanUtils.updateLoanSchedule(rsList);
				System.assert(false,'Expected an exception (unauthorized user');
			} catch (AuraHandledException e){
                // expected
                system.assertEquals(success2,null);
            }
        }  
    }    
}