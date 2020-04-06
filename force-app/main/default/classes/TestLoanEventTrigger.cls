@isTest
private class TestLoanEventTrigger {
	@isTest static void test_generate_loan_event_name() {
        
		Loan_Event__c newLoanEvent = new Loan_Event__c(
            Loan_Event_Type__c = 'Loan Creation',
            Event_Date__c = System.today().addDays(-1)
        );

        insert newLoanEvent;

        Loan_Event__c loanEvent = [
            SELECT Name 
            FROM Loan_Event__c
            WHERE Id =: newLoanEvent.Id
        ];
        System.assertEquals('Loan Creation - ' + System.today().addDays(-1).format(), loanEvent.Name);

        newLoanEvent.Loan_Event_Type__c = 'Reschedule';
        newLoanEvent.Event_Date__c = System.today();
        update newLoanEvent;

        Loan_Event__c loanEvent2 = [
            SELECT Name 
            FROM Loan_Event__c
            WHERE Id =: newLoanEvent.Id
        ];
        System.assertEquals('Reschedule - ' + System.today().format(), loanEvent2.Name);
    }

    @isTest static void test_delete_disbursed_transactions() {
        // create a loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(1), System.today().addMonths(2));
        i.Setup_Fee_Charging_Method__c = 'Paid Up Front (scheduled)';
        i.Disbursement_Method__c = 'Tranched disbursement allowed';
        update i;

        // create disbursed transactions
        List<Transaction__c> trToInsert = new List<Transaction__c>();
        Integer numberOfTransactions = 4;
        for (Integer k = 0; k < numberOfTransactions; k++) {
            trToInsert.add(
                TestUtils.createNewTransaction(i.Id, i.Amount__c/numberOfTransactions, 'Disbursement', 'Disbursed', System.today().addMonths(1 + k))
            );
        }
        
        Map<String, String> status = DisburseLoanButtonController.saveData(i.Id, JSON.serialize(trToInsert), '[]');
        System.debug(status);
        // in this case, for each disbursed transaction the loan must be rescheduled
        // this also means that a loan event associated with this loan must be created 
        List<Loan_Event__c> loanEvents = [
            SELECT Id
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Disbursement'
            ORDER BY Event_Date__c ASC
        ];

        // Perform test
        Database.DeleteResult result = Database.delete(loanEvents[0], false);
        // Verify 
        // In this case the deletion should have been stopped by the trigger,
        // so verify that we got back an error.
        
        System.assert(!result.isSuccess());
        System.assert(result.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.error_message_44, result.getErrors()[0].getMessage());

        System.assertEquals([SELECT COUNT() FROM Transaction__c WHERE Investment__c =: i.Id AND Type__c = 'Disbursement'], loanEvents.size());
        System.assertEquals(numberOfTransactions, loanEvents.size());

        delete loanEvents;

        System.assertEquals([SELECT COUNT() FROM Transaction__c WHERE Investment__c =: i.Id AND Type__c = 'Disbursement'], 0);
    }
}