@isTest
private class TestBalloonRepaymentButtonController {
    @isTest static void test_get_repayment_schedules() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-2), System.today().addMonths(-1));

        List<Repayment_Schedule__c> result = BalloonRepaymentButtonController.getRepaymentSchedules(i.Id).Repayment_Schedules__r;
        System.assertEquals(10, result.size());
    }

    @isTest static void test_schedule_balloon_repayment() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-2), System.today().addMonths(-1));

        List<Repayment_Schedule__c> rsToProcess = BalloonRepaymentButtonController.getRepaymentSchedules(i.Id).Repayment_Schedules__r;
        Integer listSize = rsToProcess.size();
        
        Decimal principal = rsToProcess[listSize - 1].Principal_Expected__c + rsToProcess[listSize - 2].Principal_Expected__c;
        Decimal fees = rsToProcess[listSize - 1].Fees_Expected__c + rsToProcess[listSize - 2].Fees_Expected__c;

        BalloonRepaymentButtonController.scheduleBalloonRepayment(JSON.serialize(rsToProcess), listSize - 2, i.Id);
        
        List<Repayment_Schedule__c> actualRS = [
            SELECT Fees_Expected__c, Principal_Expected__c 
            FROM Repayment_Schedule__c
            WHERE Loan__c =: i.Id AND Active__c = true AND Migration__c = false
                AND Due_Date__c > TODAY
            ORDER BY Due_Date__c
        ];

        List<Loan_Event__c> loanEvents = [
            SELECT Balloon_Repayment_Period__c
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Bullet Repayment'
        ];
        System.assertEquals(listSize - 1, actualRS.size());
        System.assertEquals(1, loanEvents.size());
        System.assertEquals(listSize - 2, loanEvents[0].Balloon_Repayment_Period__c);
        System.assertEquals(principal.setScale(2), actualRS[listSize - 2].Principal_Expected__c.setScale(2));
        System.assertEquals(fees.setScale(2), actualRS[listSize - 2].Fees_Expected__c.setScale(2));

    }

}