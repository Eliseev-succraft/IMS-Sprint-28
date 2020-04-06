@isTest
private class TestRescheduleLoanButtonController {

    @isTest static void test_get_loan() {
        Investment__c i = TestUtils.createNewLoan();
        insert i;

        Investment__c result = RescheduleLoanButtonController.getLoan(i.Id);
        System.assertEquals(i.Id, result.Id);
        System.assertEquals(i.Amount__c, result.Amount__c);
    }
    
    @isTest static void test_reschedule_loan() {
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;

        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-7), System.today().addMonths(-6));
        i.Loan_Product__c = lp.Id;         
        Transaction__c t = TestUtils.createNewTransaction(i.Id, 2, 'Repayment');
        insert t;

        List<Repayment_Schedule__c> rsList = [
            SELECT Name, Principal_Remaining__c, Interest_Remaining__c, Fees_Remaining__c, Late_Repayment_Fees_Remaining__c, Principal_Balance__c
            FROM Repayment_Schedule__c
            ORDER BY Due_Date__c ASC
        ];
        System.debug(rsList);

        Investment__c oldInvestment = [
            SELECT Id, Number_of_Instalments__c, Repayment_Frequency__c, Repayment_Frequency_Unit__c, Interest_Rate__c, Status__c,
                Number_of_Grace_Periods__c, Grace_Period_Type__c, Capitalized_Amount__c, Capitalized_Fee_Amount__c, Amount__c, 
                First_Repayment_Date__c, Disbursement_Date__c, Loan_Product__c, Setup_Fee_Charging_Method__c, Setup_Fee_Expected__c, 
                Fees_Remaining__c, Late_Repayment_Fees_Remaining__c, Interest_Overdue__c, Principal_Remaining__c, Open_Ended_Loan__c,
                Day_Count_Convention__c, Variable_Interest_Spread__c, Non_Working_Days_Rescheduling__c, Last_Instalment_Amount__c,
                Monitoring_Fee_Percentage__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];
        
        // simulate entering new values for the loan
        oldInvestment.Number_of_Instalments__c = oldInvestment.Number_of_Instalments__c*2;
        oldInvestment.First_Repayment_Date__c = System.today().addDays(7);
        oldInvestment.Capitalized_Fee_Amount__c = 0;
        oldInvestment.Capitalized_Amount__c = oldInvestment.Principal_Remaining__c - 1 - oldInvestment.Interest_Overdue__c 
            - oldInvestment.Fees_Remaining__c - oldInvestment.Late_Repayment_Fees_Remaining__c;
        oldInvestment.Amount__c = oldInvestment.Capitalized_Amount__c;

        Map<String, Object> dataMap = new Map<String, Object>();
        dataMap.put('recordId', i.Id);
        dataMap.put('action', 'Reschedule');
        dataMap.put('selectedType', 'Manual Reschedule');
        dataMap.put('loan', JSON.serialize(oldInvestment));
        dataMap.put('rescheduleDate', System.today());
        dataMap.put('totalPrincipalWrittenOff', 1);
        dataMap.put('totalInterestWrittenOff', oldInvestment.Interest_Overdue__c);
        dataMap.put('totalFeesWrittenOff', oldInvestment.Fees_Remaining__c);
        dataMap.put('totalPenaltiesWrittenOff', oldInvestment.Late_Repayment_Fees_Remaining__c);
        dataMap.put('rationale', 'reschedule message');
        Test.startTest();

        RescheduleLoanButtonController.rescheduleLoan(dataMap);

        Test.stopTest();

        Investment__c newInvestment = [
            SELECT Id, Amount__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];
        List<Repayment_Schedule__c> inactiveRepaymentSchedules = [
            SELECT Id, Principal_Balance__c
            FROM Repayment_Schedule__c
            WHERE Loan__c =: i.Id AND Active__c = false
        ];
        Loan_Event__c newEvent = [
            SELECT Id, Amount__c, Event_Date__c, Number_of_Instalments__c, Interest_Rate__c,
                Fees_Written_Off__c, Interest_Written_Off__c, Late_Repayment_Fees_Written_Off__c, Principal_Written_Off__c
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Reschedule'
        ];

        System.assertEquals(oldInvestment.Fees_Remaining__c, newEvent.Fees_Written_Off__c);
        System.assertEquals(oldInvestment.Interest_Overdue__c, newEvent.Interest_Written_Off__c);
        System.assertEquals(oldInvestment.Late_Repayment_Fees_Remaining__c, newEvent.Late_Repayment_Fees_Written_Off__c);
        System.assertEquals(1, newEvent.Principal_Written_Off__c);
        System.assertEquals(System.today(), newEvent.Event_Date__c);
        System.assertEquals((Integer)dataMap.get('totalPrincipalWrittenOff'), rsList[0].Principal_Balance__c-inactiveRepaymentSchedules[0].Principal_Balance__c);
        System.assertEquals((Integer)dataMap.get('totalPrincipalWrittenOff'), rsList[1].Principal_Balance__c-inactiveRepaymentSchedules[1].Principal_Balance__c);
    }

    @isTest static void test_loan_write_off() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-7), System.today().addMonths(-6));    
        Transaction__c t = TestUtils.createNewTransaction(i.Id, 2, 'Repayment');
        insert t;
        
        Investment__c oldInvestment = [
            SELECT Id, Amount__c, Number_of_Instalments__c, Interest_Rate__c,
                Principal_Remaining__c, Interest_Remaining__c, Fees_Remaining__c, Late_Repayment_Fees_Remaining__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];

        Map<String, Object> dataMap = new Map<String, Object>();
        dataMap.put('recordId', i.Id);
        dataMap.put('totalPrincipalWrittenOff', oldInvestment.Principal_Remaining__c);
        dataMap.put('totalInterestWrittenOff', oldInvestment.Interest_Remaining__c);
        dataMap.put('totalFeesWrittenOff', oldInvestment.Fees_Remaining__c);
        dataMap.put('totalPenaltiesWrittenOff', oldInvestment.Late_Repayment_Fees_Remaining__c);
        dataMap.put('writeOffDate', System.today());

        Test.startTest();

        RescheduleLoanButtonController.loanWriteOff(dataMap);

        Test.stopTest();

        Investment__c newInvestment = [
            SELECT Id, Status__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];
        Loan_Event__c newEvent = [
            SELECT Id, Event_Date__c, Fees_Written_Off__c, Interest_Written_Off__c, Late_Repayment_Fees_Written_Off__c, Principal_Written_Off__c
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Closed (Written Off)'
        ];

        System.assertEquals(oldInvestment.Fees_Remaining__c, newEvent.Fees_Written_Off__c);
        System.assertEquals(oldInvestment.Interest_Remaining__c, newEvent.Interest_Written_Off__c);
        System.assertEquals(oldInvestment.Late_Repayment_Fees_Remaining__c, newEvent.Late_Repayment_Fees_Written_Off__c);
        System.assertEquals(oldInvestment.Principal_Remaining__c, newEvent.Principal_Written_Off__c);
        System.assertEquals(System.today(), newEvent.Event_Date__c);
        System.assertEquals(newInvestment.Status__c, 'Closed - Written Off');
    }

}