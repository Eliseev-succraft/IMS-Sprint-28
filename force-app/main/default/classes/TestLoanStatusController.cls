@isTest
private class TestLoanStatusController {

    // not in use

    // @isTest static void test_loan_writeoff() {
	// 	Account a = TestUtils.createAccount('Investee_Account','test',null);
    //     // initially total paid = 0
    //     Investment__c i = TestUtils.createNewScheduledLoan(a.Id);
    //     i.Status__c = 'Active';
    //     update i;
        
    //     LoanStatusController.loanExecuteWriteOff(i.Id);

    //     i = [Select Id, Status__c From Investment__c Where Id = :i.Id];
    //     system.assertEquals('Closed - Written Off', i.Status__c);

    //     // verify that a loan with status not-active cannot be written off
    //     try{
    //         LoanStatusController.loanExecuteWriteOff(i.Id);
    //         System.assert(false,'Expected an exception (wrong loan status');
    //     } catch (AuraHandledException e){
    //         // expected
    //         system.assertEquals(true,true);
    //     }
        


    //     // test the same with unauthorized user
	// 	User newUser = TestUtils.ensureRestrictedUser();
	// 	System.runAs(newUser){
	// 		try{
	// 			LoanStatusController.loanExecuteWriteOff(i.Id);
	// 			System.assert(false,'Expected an exception (unauthorized user');
	// 		} catch (AuraHandledException e){
    //             // expected
    //             system.assertEquals(true,true);
    //         }
    //     }          
    // }
}