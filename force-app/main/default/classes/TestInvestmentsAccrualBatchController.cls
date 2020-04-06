@isTest
private class TestInvestmentsAccrualBatchController {
    @isTest static void test_batch_methods() {
        // create a loan starting 6 months back, so there will be some amounts due
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addmonths(-6), System.today().addmonths(-5));
        i.Status__c = 'Active';
        update i;

        // run the batch job
        Test.startTest();
        InvestmentsAccrualBatchController theBatch = new InvestmentsAccrualBatchController();
        Database.executebatch(theBatch);        
        Test.stopTest();

        // take the first schedule and check if the total amount due has been set
        Repayment_Schedule__c rs = [Select Id, Total_Expected__c, Total_Due__c From Repayment_Schedule__C Where Loan__c = :i.Id ORDER BY Due_Date__c ASC LIMIT 1];
        system.debug(rs);
        system.assertEquals(rs.Total_Expected__c, rs.Total_Due__c);
    }
    
    @isTest static void test_scheduler_methods(){
        Test.startTest();
        NightlyBatchScheduler nbs = new NightlyBatchScheduler();
        String cronExpr = '0 0 0 15 3 ? 2099';
        String jobId = System.schedule('myJobTestJobName', cronExpr, nbs);
        
        system.assert([SELECT count() FROM CronTrigger] > 0, 'A job should be scheduled');
        
        nbs.execute(null);
        
        Test.stopTest();        
    }
}