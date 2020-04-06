@isTest
private class TestLoanEarlyRepaymentButtonController {

    @isTest static void test_loan_early_repayment() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-6), System.today().addMonths(-6));
        i.Status__c = 'Active';
        update i;
    
        Investment__c oldInvestment = [
            SELECT Id, Principal_Remaining__c, Interest_Remaining__c, Fees_Remaining__c, Late_Repayment_Fees_Remaining__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];

        Map<String, Object> dataMap = new Map<String, Object>();
        dataMap.put('recordId', i.Id);
        dataMap.put('totalPrincipalWrittenOff', 0);
        dataMap.put('totalInterestWrittenOff', oldInvestment.Interest_Remaining__c);
        dataMap.put('totalFeesWrittenOff', oldInvestment.Fees_Remaining__c);
        dataMap.put('totalPenaltiesWrittenOff', oldInvestment.Late_Repayment_Fees_Remaining__c);
        dataMap.put('totalEarlyRepaymentAmount', oldInvestment.Principal_Remaining__c);
        dataMap.put('earlyRepaymentDate', System.today());

        Test.startTest();

        LoanEarlyRepaymentButtonController.loanPayOff(dataMap);

        Test.stopTest();

        Investment__c updatedInvestment = [
            SELECT Id, Status__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];
        Loan_Event__c loanEvent = [
            SELECT Id, Event_Date__c, Fees_Written_Off__c, Interest_Written_Off__c, Late_Repayment_Fees_Written_Off__c, Principal_Written_Off__c
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Closed (Early Repayment)'
        ];

        System.assertEquals(oldInvestment.Fees_Remaining__c, loanEvent.Fees_Written_Off__c);
        System.assertEquals(oldInvestment.Interest_Remaining__c, loanEvent.Interest_Written_Off__c);
        System.assertEquals(oldInvestment.Late_Repayment_Fees_Remaining__c, loanEvent.Late_Repayment_Fees_Written_Off__c);
        System.assertEquals(0, loanEvent.Principal_Written_Off__c);
        System.assertEquals(System.today(), loanEvent.Event_Date__c);
        System.assertEquals('Closed - Early Repayment', updatedInvestment.Status__c);
    }
}