@isTest
private class TestDisburseLoanButtonController {
    @isTest static void test_get_disbursement_transactions() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-1), System.today());
        i.Disbursement_Method__c = 'Full disbursement at start';
        update i;
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement');
        insert t;

        List<Transaction__c> result = DisburseLoanButtonController.getDisbursementTransactions(i.Id);
        System.assertEquals(1, result.size());
        System.assertEquals(t.Id, result[0].Id);
    }

    @isTest static void test_generate_schedule_preview() {
        System.assertEquals(0, [SELECT COUNT() FROM Transaction__c WHERE Type__c = 'Disbursement']);
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-1), System.today());
        i.Setup_Fee_Charging_Method__c = 'Paid Up Front (scheduled)';
        i.Disbursement_Method__c = 'Tranched disbursement allowed';
        update i;
        
        Transaction__c t = TestUtils.createNewTransaction(i.Id, 50, 'Disbursement', System.today().addMonths(-1));
        
        Test.startTest();
        Map<String, String> status = DisburseLoanButtonController.generateSchedulePreview(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');
        Test.stopTest();
        
        // verify that transactions have not been saved
        System.assertEquals(0, [SELECT COUNT() FROM Transaction__c WHERE Type__c = 'Disbursement']);

        // perform the saveData method to verify results
        t.Status__c = 'Disbursed';
        DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');

        List<Repayment_Schedule__c> result = [
            SELECT Id, Due_Date__c, Principal_Expected__c, Interest_Expected_Standard_Loan__c, Fees_Expected__c
            FROM Repayment_Schedule__c
            WHERE Loan__c =: i.Id AND Active__c = true
        ];

        System.assert(status.containsKey('toInsert'));
        List<Repayment_Schedule__c> rsToPreview = (List<Repayment_Schedule__c>)JSON.deserialize(status.get('toInsert'), List<Repayment_Schedule__c>.class);
        System.assertEquals(result.size(), rsToPreview.size());
        for (Integer k = 0; k < result.size(); k++) {
            System.debug(result[k]);
            System.debug(rsToPreview[k]);
            System.assertEquals(result[k].Due_Date__c, rsToPreview[k].Due_Date__c);
            System.assertEquals(result[k].Principal_Expected__c, rsToPreview[k].Principal_Expected__c);
            System.assertEquals(result[k].Interest_Expected_Standard_Loan__c, rsToPreview[k].Interest_Expected_Standard_Loan__c);
            System.assertEquals(result[k].Fees_Expected__c, rsToPreview[k].Fees_Expected__c);
        }
    }

    @isTest static void test_process_disbursed_transactions() {
        // create a loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today(), System.today().addMonths(1));
        i.Setup_Fee_Charging_Method__c = 'Paid Up Front (scheduled)';
        i.Disbursement_Method__c = 'Tranched disbursement allowed';
        update i;

        // create disbursed transactions (test in bulk)
        List<Transaction__c> trToInsert = new List<Transaction__c>();
        Integer numberOfTransactions = 100;
        for (Integer k = 0; k < numberOfTransactions; k++) {
            trToInsert.add(
                TestUtils.createNewTransaction(i.Id, i.Amount__c/numberOfTransactions, 'Disbursement', System.today().addDays(k))
            );
        }
        Test.startTest();
        Map<String, String> status = DisburseLoanButtonController.saveData(i.Id, JSON.serialize(trToInsert), '[]');
		Test.stopTest();
        // in this case, for each disbursed transaction the loan must be rescheduled
        // this also means that a loan event associated with this loan must be created 
        List<Loan_Event__c> loanEvents = [
            SELECT Amount__c
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Disbursement'
            ORDER BY Amount__c DESC
        ];
        Investment__c inv = [
            SELECT Principal_Remaining__c, Fees_Remaining__c
            FROM Investment__c
            WHERE Id =: i.Id 
        ];

        System.debug(status.containsKey('error'));
        System.debug(status.get('error'));
        System.assertEquals([SELECT COUNT() FROM Transaction__c WHERE Investment__c =: i.Id AND Type__c = 'Disbursement'], loanEvents.size());
        System.assertEquals(inv.Principal_Remaining__c, 100);
        Id recordTypeId = Schema.Sobjecttype.Transaction__c.getRecordTypeInfosByName().get('Investment Transaction').getRecordTypeId();
        List<Transaction__c> trs = [SELECT RecordTypeId, Created_Using_The_Disburse_Button__c FROM Transaction__c WHERE Investment__c =: i.Id AND Type__c = 'Disbursement'];
        System.debug(trs.size());
        System.assertEquals(recordTypeId, trs[0].RecordTypeId);
        System.assert(!trs[0].Created_Using_The_Disburse_Button__c);  
    }

    @isTest static void test_process_disbursed_transactions_for_a_loan_with_no_repayment_schedules() {
        // create a loan
        Investment__c i = TestUtils.createNewLoan();
        i.Amount__c = 100;
        i.Setup_Fee_Charging_Method__c = 'Paid Up Front (scheduled)';
        i.Disbursement_Method__c = 'Tranched disbursement allowed';
        insert i;

        // create disbursed transactions
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c/2, 'Disbursement', System.today());
        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, i.Amount__c/2, 'Disbursement', System.today().addMonths(1));
        Test.startTest();
        Map<String, String> status = DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t, t2}), '[]');
		Test.stopTest();
        
        // in this case, the transactions that we tried to insert were not saved
        // it was blocked because of the 'no repayment schedule' validation 
        List<Transaction__c> trs = [
            SELECT Id
            FROM Transaction__c
            WHERE Investment__c =: i.Id AND Type__c = 'Disbursement' AND Status__c = 'Disbursed'
        ];

        System.assertEquals(0, trs.size());
        System.assert(status.containsKey('error'));
        System.assertEquals(System.Label.sfims.error_message_9, status.get('error'));
               
    }

    @isTest static void test_disburse_open_ended_loan() {
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;
        
        // create a loan
        Integer days = 100;
        Investment__c i = TestUtils.createNewScheduledOpenEndedLoan(System.today().addDays(-days), 100);
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Tranched disbursement allowed';
        update i;
        // create a disbursed transaction
        List<Transaction__c> tr = new List<Transaction__c>{
            TestUtils.createNewTransaction(i.Id, i.Amount__c/2, 'Disbursement', System.today().addDays(-days)),
            TestUtils.createNewTransaction(i.Id, i.Amount__c/2, 'Disbursement', System.today())
        };
        
        Test.startTest();
        Map<String, String> result = DisburseLoanButtonController.saveData(i.Id, JSON.serialize(tr), '[]');
        System.debug(result);
		Test.stopTest();
        
        // pay interest on the tansaction date
        Transaction__c t = TestUtils.createNewTransaction(i.Id, 0.005 * days, 'Repayment', System.today());
        insert t;
        
        // in this case, for the disbursed transaction the loan must be rescheduled
        // this also means that a loan event associated with this loan must be created 
        List<Loan_Event__c> loanEvents = [
            SELECT Amount__c
            FROM Loan_Event__c
            WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Disbursement'
            ORDER BY Amount__c DESC
        ];
        Investment__c inv = [
            SELECT Principal_Remaining__c, Fees_Remaining__c
            FROM Investment__c
            WHERE Id =: i.Id 
        ];

        System.assertEquals(tr.size(), loanEvents.size());
        
        System.assertEquals(tr.size(), [SELECT COUNT() FROM Transaction__c WHERE Type__c = 'Disbursement']);
        Id recordTypeId = Schema.Sobjecttype.Transaction__c.getRecordTypeInfosByName().get('Investment Transaction').getRecordTypeId();
        List<Transaction__c> trs = [SELECT RecordTypeId FROM Transaction__c WHERE Type__c = 'Disbursement'];
        System.assertEquals(recordTypeId, trs[0].RecordTypeId);
        System.assertEquals(inv.Principal_Remaining__c, i.Amount__c);
               
    }

    @isTest static void test_run_validations_full_disbursement_at_start() {      
        Investment__c i = TestUtils.createNewScheduledLoan();
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Status__c = 'Inactive';
        update i;

        // try to add more that 1 record
        Transaction__c t1 = TestUtils.createNewTransaction(i.Id, i.Amount__c/2, 'Disbursement', System.today());
        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, i.Amount__c/2, 'Disbursement', System.today().addDays(1));
        List<Transaction__c> transactions = new List<Transaction__c>{t1,t2};
       
        // Perform validation
        Map<String, String> result = DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t1, t2}), '[]');
        // Verify 
        // In this case the insertion should have been stopped,
        // so verify that we got back an error.
        System.assert(result.containsKey('error'));
        System.assertEquals(System.Label.sfims.error_message_14, result.get('error'));
       
        // Perform validation
        Map<String, String> result2 = DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t1}), '[]');
        // Verify 
        // In this case the insertion should have been stopped,
        // so verify that we got back an error.
        System.assert(result2.containsKey('error'));
        System.assertEquals(System.Label.sfims.error_message_16, result2.get('error'));

        i.Setup_Fee_Charging_Method__c = 'Deducted From Principal';
        update i;

        // Perform validation
        Map<String, String> result3 = DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t1}), '[]');
        // Verify 
        // In this case the insertion should have been stopped,
        // so verify that we got back an error.
        System.assert(result3.containsKey('error'));
        System.assertEquals(System.Label.sfims.error_message_15, result3.get('error'));
    }

    @isTest static void test_run_validations_tranched_disbursement_allowed() {
        Investment__c i = TestUtils.createNewScheduledLoan();
        i.Setup_Fee_Charging_Method__c = 'Paid Up Front (scheduled)';
        i.Disbursement_Method__c = 'Tranched disbursement allowed';
        i.Status__c = 'Inactive';
        update i;

        // try to add a planned transaction and a disbursed transaction, the transaction date of which is after the transaction date of the planned transaction 
        List<Transaction__c> transactions = new List<Transaction__c>();
        transactions.add(TestUtils.createNewTransaction(i.Id, i.Amount__c/2, 'Disbursement', 'Planned', System.today().addMonths(-1)));
        transactions.add(TestUtils.createNewTransaction(i.Id, i.Amount__c/2, 'Disbursement', System.today().addDays(-15)));
    
        // Perform validation
        Map<String, String> result = DisburseLoanButtonController.saveData(i.Id, JSON.serialize(transactions), '[]');
        // Verify 
        // In this case the insertion should have been stopped,
        // so verify that we got back an error.
    
        System.assert(result.containsKey('error'));
        System.assertEquals(System.Label.sfims.error_message_17, result.get('error'));

        // try to add transactions with the total amount higher tnan the loan amount
        transactions = new List<Transaction__c>();
        transactions.add(TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', System.today().addMonths(-1)));
        transactions.add(TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', System.today().addDays(1)));
        
        // Perform validation
        Map<String, String> result2 = DisburseLoanButtonController.saveData(i.Id, JSON.serialize(transactions), '[]');
        // Verify 
        // In this case the insertion should have been stopped,
        // so verify that we got back an error.
        System.assert(result2.containsKey('error'));
        System.assertEquals(System.Label.sfims.error_message_18, result2.get('error'));

        // i.Setup_Fee_Charging_Method__c = 'Deducted From Principal';
        // update i;

        // // Perform validation
        // Map<String, String> result3 = DisburseLoanButtonController.saveData(i.Id, JSON.serialize(transactions), '[]');
        // // Verify 
        // // In this case the insertion should have been stopped,
        // // so verify that we got back an error.
        // System.assert(result3.containsKey('error'));
        // System.assertEquals('The total of amounts should not be higher than the Investment Amount minus Setup Fee Expected',
        //                     result3.get('error'));

    }

    @isTest static void test_run_validations_interest_rate_not_found() {      
        // create a new interest rate source
        Interest_Rate_Source__c irs = new Interest_Rate_Source__c(Name = 'Test Interest Rate Source');
        insert irs;

        // create interest rates
        Interest_Rate__c ir1 = TestUtils.createNewInterestRate(irs.Id, System.today().addDays(-10), 1);
        Interest_Rate__c ir2 = TestUtils.createNewInterestRate(irs.Id, System.today().addDays(-5), 2);
        
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct('Test Loan Product');
        lp.Interest_Rate_Source__c = 'Variable Interest';
        lp.Interest_Reference_Rate__c = irs.Id;
        lp.Interest_Rate_Review_Frequency__c = 'Monthly';
        lp.CBO_Default_Variable_Interest_Spread__c = true;

        insert new List<SObject>{ir1, ir2, lp};

        // create a new loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-1), System.today());
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Status__c = 'Inactive';
        update i;

        // try to add a disbursement
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', System.today().addMonths(-1));
       
        // Perform validation
        Map<String, String> result = DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');
        // Verify 
        // In this case the insertion should have been stopped,
        // so verify that we got back an error.
        System.assert(result.containsKey('error'));
        System.assertEquals(System.Label.sfims.error_message_20, result.get('error'));
    
    }
}