@isTest
private class TestTransactionTriggerHandler {
    
    @isTest static void test_process_transaction_methods() {
        User platformUser = TestUtils.createPlatformUser();
        System.runAs(platformUser){        
            // create a new loan product
            Loan_Product__c lp = TestUtils.createNewLoanProduct();
            insert lp;

            // initially total paid = 0
            Investment__c i = TestUtils.createNewScheduledLoan();
            i.Loan_Product__c = lp.Id;
            update i;

            // take the first schedule and check the status
            Repayment_Schedule__c rs = [SELECT Id, Status__c, Total_Expected__c, Total_Paid__c FROM Repayment_Schedule__C WHERE Loan__c = :i.Id ORDER BY Due_Date__c ASC LIMIT 1];
            System.assertEquals('Late', rs.Status__c);


            // partly repay the first schedule
            Transaction__c t = TestUtils.createNewTransaction(i.Id, rs.Total_Expected__c/2, 'Repayment');
            insert t;
            // refresh the schedule record
            rs = [SELECT Id, Status__c, Total_Expected__c,Total_Paid__c FROM Repayment_Schedule__c WHERE Id = :rs.Id];
            System.assertEquals('Partially Paid (On Time)', rs.Status__c);


            // repay the rest of the first schedule
            Transaction__c t2 = TestUtils.createNewTransaction(i.Id, rs.Total_Expected__c/2, 'Repayment');
            insert t2;

            // refresh the schedule record
            rs = [SELECT Id, Status__c, Total_Expected__c,Total_Paid__c FROM Repayment_Schedule__C WHERE Id = :rs.Id];
            System.debug(rs);
            System.assertEquals('Paid (On Time)', rs.Status__c);
        }
    }


    @isTest static void test_bulk_process_transaction_for_large_loan() {
        User platformUser = TestUtils.createPlatformUser();
        System.runAs(platformUser){        
            // create a new loan product
            Loan_Product__c lp = TestUtils.createNewLoanProduct();
            insert lp;

            // create a huge loan (30 years, monthly periods)
            Investment__c inv = TestUtils.createNewLoan(System.today(), System.today());
            inv.Disbursement_Method__c = 'Full disbursement at start';
            inv.Loan_Product__c = lp.Id;
            inv.Number_of_Instalments__c = 360;
            insert inv;
            
            List<Repayment_Schedule__c> schedules = LoanScheduler.generateScheduleById(inv.Id);
            insert schedules;

            Test.startTest();

            // create a huge set of transactions (200). One on each consecutive day
            List<Transaction__c> transToInsert = new List<Transaction__c>();
            for(Integer i=0;i<200;i++){
                Transaction__c t = TestUtils.createNewTransaction(inv.Id, 2, 'Repayment', System.today().addDays(i));
                transToInsert.add(t);
            }
            insert transToInsert;
            
            Test.stopTest();

            // refresh the loan record and check that 400 has been repaid 
            Investment__c inv2 = [SELECT Id, Status__c, Interest_Paid__c ,Fees_Paid__c, Principal_Paid__c FROM Investment__c WHERE Id = :inv.Id];
            System.debug(inv2);
            System.assertEquals(400, inv2.Interest_Paid__c+inv2.Fees_Paid__c+inv2.Principal_Paid__c);

        }
    }

    @IsTest static void test_populate_fund_fields() {
        // User platformUser = TestUtils.createPlatformUser();
        // System.runAs(platformUser){
        Fund__c f = new Fund__c(Name = 'test Fund');
        insert f;
        Investment__c i = TestUtils.createNewScheduledLoan();
        i.Loan_Fund__c = f.Id;
        update i;
        Repayment_Schedule__c rs = [SELECT Id, Status__c, Total_Expected__c, Total_Paid__c FROM Repayment_Schedule__c WHERE Loan__c = :i.Id ORDER BY Due_Date__c ASC LIMIT 1];
        List<Transaction__c> transactions = new List<Transaction__c>();
        Transaction__c t1 = TestUtils.createNewTransaction(i.Id, rs.Total_Expected__c, 'Repayment');
        transactions.add(t1);
        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', 'Planned', System.today());
        t2.Fund__c = f.Id;
        transactions.add(t2);
        Transaction__c t3 = TestUtils.createNewTransaction(i.Id, 1, 'Fund Drawdown', 'Requested', System.today());
        t3.Fund__c = f.Id;
        transactions.add(t3);
        Transaction__c t4 = TestUtils.createNewTransaction(i.Id, 5, 'Fund Repayment', 'Requested', System.today());
        t4.Fund__c = f.Id;
        transactions.add(t4);
        Test.startTest();
        insert transactions;
        Test.stopTest();
        transactions = [
                SELECT Amount__c, Fund_Cashflow_Amount__c, Interest_Amount__c, Fee_Amount__c, Late_Repayment_Fee_Amount__c, Fund__c, Type__c
                FROM Transaction__c
                WHERE Id = :NEW List<Id>{
                        t1.Id, t2.Id, t3.Id, t4.Id
                } AND Fund__c = :f.Id
                ORDER BY Id
        ];
        Fund__c fund = [
                SELECT Investment_Principal_Disbursed__c, Total_Draw_Down__c, Total_Fund_Repayments__c, Fund_Balance__c, Interest_Repaid__c, Fees_Paid__c, Penalties_Paid__c
                FROM Fund__c
                WHERE Id = :f.Id
        ];
        System.assertEquals(fund.Investment_Principal_Disbursed__c, i.Amount__c);
        System.assertEquals(fund.Total_Draw_Down__c, transactions[2].Amount__c);
        System.assertEquals(fund.Total_Fund_Repayments__c, transactions[0].Amount__c + transactions[3].Amount__c);
        System.assertEquals(fund.Fund_Balance__c, transactions[0].Fund_Cashflow_Amount__c + transactions[1].Fund_Cashflow_Amount__c + transactions[2].Fund_Cashflow_Amount__c + transactions[3].Fund_Cashflow_Amount__c);
        System.assertEquals(fund.Interest_Repaid__c, transactions[0].Interest_Amount__c);
        System.assertEquals(fund.Fees_Paid__c, transactions[0].Fee_Amount__c);
        System.assertEquals(fund.Penalties_Paid__c, transactions[0].Late_Repayment_Fee_Amount__c);
        //  }
    }
    
    @isTest static void test_update_investment_fields_tranched_disbursements() { 
        Milestone_Configuration__c mc = new Milestone_Configuration__c(
            Object__c = 'Investment',
            Stage__c = 'Active',
            Milestone_Name__c = 'Investment Active',
            Sequence__c = 9
        );
        insert mc;
    
        // create a new loan        
        Investment__c i = TestUtils.createNewScheduledLoan();
        i.Setup_Fee_Charging_Method__c = 'Paid Up Front (scheduled)';
        i.Disbursement_Method__c = 'Tranched disbursement allowed';
        update i;
    
        // add a transaction with the type 'Disbursement' 
        Transaction__c t1 = TestUtils.createNewTransaction(i.Id, i.Amount__c/5, 'Disbursement', System.today().addDays(-15));
        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, i.Amount__c/5, 'Disbursement', System.today().addDays(-30));
        Transaction__c t3 = TestUtils.createNewTransaction(i.Id, i.Amount__c/5, 'Disbursement', 'Planned', System.today().addDays(90));
        insert new List<Transaction__c>{t1, t2, t3};

        // in this case, the loan status must be changed to 'Active' 
        // and the disbursement date must be changed on the date of the transaction
        Investment__c result = [
            SELECT Disbursement_Date__c, Status__c, Disbursed_Amount__c, Planned_Disbursement_Amount__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];

        List<Milestone_History__c> mhList = [
            SELECT Milestone_Date__c
            FROM Milestone_History__c
            WHERE Investment__c =: i.Id
        ];

        // verify results
        System.assertEquals('Active', result.Status__c);
        System.assertEquals(t2.Transaction_Date__c, result.Disbursement_Date__c);
        System.assertEquals(1, mhList.size());
        System.assertEquals(result.Disbursement_Date__c, mhList[0].Milestone_Date__c);
        System.assertEquals(result.Disbursed_Amount__c, t1.Amount__c + t2.Amount__c);
        System.assertEquals(result.Planned_Disbursement_Amount__c, t3.Amount__c);

        Transaction__c t4 = TestUtils.createNewTransaction(i.Id, i.Amount__c/5, 'Disbursement', System.today().addDays(45));
        Transaction__c t5 = TestUtils.createNewTransaction(i.Id, i.Amount__c/5, 'Disbursement', 'Planned', System.today().addDays(120));
        insert new List<Transaction__c>{t4, t5};

        Investment__c result2 = [
            SELECT Disbursed_Amount__c, Planned_Disbursement_Amount__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];

        // verify results
        System.assertEquals(result2.Disbursed_Amount__c, t1.Amount__c + t2.Amount__c + t4.Amount__c);
        System.assertEquals(result2.Planned_Disbursement_Amount__c, t3.Amount__c + t5.Amount__c);

        delete new List<Transaction__c>{t4, t5};

        Investment__c result3 = [
            SELECT Disbursed_Amount__c, Planned_Disbursement_Amount__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];

        // verify results
        System.assertEquals(result3.Disbursed_Amount__c, t1.Amount__c + t2.Amount__c);
        System.assertEquals(result3.Planned_Disbursement_Amount__c, t3.Amount__c);
    }

    @isTest static void test_update_investment_fields_full_disbursement_at_start() {
        // create a new loan        
        Investment__c i = TestUtils.createNewScheduledLoan();
        i.Disbursement_Method__c = 'Full disbursement at start';
        update i;
    
        // add a transaction with the type 'Disbursement' 
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', 'Planned', System.today().addDays(-30));
        insert t;

        // in this case, the loan status must be changed to 'Active' 
        // and the disbursement date must be changed on the date of the transaction
        Investment__c result = [
            SELECT Disbursed_Amount__c, Planned_Disbursement_Amount__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];

        // verify results
        System.assertEquals(result.Disbursed_Amount__c, 0);
        System.assertEquals(result.Planned_Disbursement_Amount__c, 0);

        t.Status__c = 'Disbursed';
        update t;

        Investment__c result2 = [
            SELECT Disbursed_Amount__c, Planned_Disbursement_Amount__c, Status__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];

        // verify results
        System.assertEquals(result2.Disbursed_Amount__c, t.Amount__c);
        System.assertEquals(result2.Planned_Disbursement_Amount__c, 0);
        System.assertEquals(result2.Status__c, 'Active');

        delete t;

        Investment__c result3 = [
            SELECT Disbursed_Amount__c, Planned_Disbursement_Amount__c, Status__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];

        // verify results
        System.assertEquals(result3.Disbursed_Amount__c, 0);
        System.assertEquals(result3.Planned_Disbursement_Amount__c, 0);
        System.assertEquals(result3.Status__c, 'Inactive');
    }

    @isTest static void test_prevent_FROM_saving_deletion_of_repayments_before_loan_event() { 
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;
        
        // create a new loan        
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-2), System.today().addMonths(-1));
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        update i;
        
        // add a transaction with the type 'Disbursement' 
        Transaction__c t1 = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', System.today().addMonths(-2));

        // add a transaction with the type 'Repayment'
        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, 1, 'Repayment', System.today().addMonths(-1));
        insert new List<Transaction__c>{ t1, t2 };
        
        Loan_Event__c le = new Loan_Event__c(
            Investment__c = i.Id,
            Loan_Product__c = lp.Id,
            Event_Date__c = System.today(),
            Loan_Event_Type__c = 'Reschedule'
        );
        insert le;

        // insert a new transaction before loan event date 
        Transaction__c t3 = TestUtils.createNewTransaction(i.Id, 1, 'Repayment', System.today().addMonths(-1));
        
        // Perform test
        Database.SaveResult result = Database.insert(t3, false);
        // Verify 
        // In this case the insertion should have been stopped by the trigger,
        // so verify that we got back an error.
        System.assert(!result.isSuccess());
        System.assert(result.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.error_message_66, result.getErrors()[0].getMessage());

        // update an existing repayment transaction
        t2.Amount__c = 2;
        
        // Perform test
        Database.SaveResult result2 = Database.update(t2, false);
        // Verify 
        // In this case the insertion should have been stopped by the trigger,
        // so verify that we got back an error.
        System.assert(!result2.isSuccess());
        System.assert(result2.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.error_message_66, result2.getErrors()[0].getMessage());

        // delete a repayment transaction before loan event date
        // Perform test
        Database.DeleteResult result3 = Database.delete(t2, false);
        // Verify 
        // In this case the insertion should have been stopped by the trigger,
        // so verify that we got back an error.
        System.assert(!result3.isSuccess());
        System.assert(result3.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.error_message_66, result3.getErrors()[0].getMessage());
        
    }

    @isTest static void test_prevent_FROM_manually_editing_disbursed_transactions() { 
        // create a new loan        
        Investment__c i = TestUtils.createNewScheduledLoan();
        i.Disbursement_Method__c = 'Full disbursement at start';
        update i;
    
        // add a transaction with the type 'Disbursement' 
        User platformUser = TestUtils.createPlatformUser();
        System.runAs(platformUser){
            Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement');

            // Perform test
            Database.SaveResult result = Database.insert(t, false);
            // Verify 
            // In this case the insertion should have been stopped by the trigger,
            // so verify that we got back an error.
            System.assert(!result.isSuccess());
            System.assert(result.getErrors().size() > 0);
            System.assertEquals(System.Label.sfims.error_message_50, result.getErrors()[0].getMessage());
        }
    }

    @isTest static void test_prevent_entering_transactions_when_no_schedule_is_generated() { 
        // create a new loan        
        Investment__c i = TestUtils.createNewLoan();
        insert i;
    
        // add a transaction with the type 'Disbursement' 
        Transaction__c t1 = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement');

        // Perform test
        Database.SaveResult result = Database.insert(t1, false);
        // Verify 
        // In this case the insertion should have been stopped by the trigger,
        // so verify that we got back an error.
        System.assert(!result.isSuccess());
        System.assert(result.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.part_of_error_message_17 + ' ' + System.Label.sfims.part_of_error_message_16, result.getErrors()[0].getMessage());

        // add a transaction with the type 'Repayment'
        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, 1, 'Repayment');

        // Perform test
        Database.SaveResult result2 = Database.insert(t2, false);
        // Verify 
        // In this case the insertion should have been stopped by the trigger,
        // so verify that we got back an error.
        System.assert(!result2.isSuccess());
        System.assert(result2.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.part_of_error_message_17 + ' ' + System.Label.sfims.part_of_error_message_16, result2.getErrors()[0].getMessage());
    }
        
    @isTest static void test_prevent_entering_transactions_if_the_loan_is_closed() {    
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        lp.Repayment_Allocation_Type__c = 'Loan-based';
        insert lp;
        
        // create a new loan        
        Investment__c i = TestUtils.createNewScheduledLoan();
        i.Loan_Product__c = lp.Id;
        i.Status__c = 'Closed';
        update i;

        // add a transaction with the type 'Disbursement' 
        Transaction__c t1 = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement');

        // add a transaction with the type 'Repayment'
        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, 1, 'Repayment');
        
        // Perform test
        List<Database.SaveResult> resultList = Database.insert(new List<Transaction__c>{t1, t2}, false);
        // Verify 
        // In this case the insertion should have been stopped by the trigger,
        // so verify that we got back an error.
        for (Database.SaveResult result : resultList) {
            System.assert(!result.isSuccess());
            System.assert(result.getErrors().size() > 0);
            System.assertEquals(System.Label.sfims.part_of_error_message_17 + ' ' + System.Label.sfims.part_of_error_message_15, result.getErrors()[0].getMessage());
        }
    }

    @isTest static void test_prevent_entering_transactions_if_the_loan_is_pending_recalculation() {    
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        lp.Repayment_Allocation_Type__c = 'Loan-based';
        insert lp;
        
        // create a new loan        
        Investment__c i = TestUtils.createNewScheduledLoan();
        i.Loan_Product__c = lp.Id;
        i.Recalculation_Status__c = 'Pending Recalculation';
        update i;

        // add a transaction with the type 'Disbursement' 
        Transaction__c t1 = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement');

        // add a transaction with the type 'Repayment'
        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, 1, 'Repayment');
        
        // Perform test
        List<Database.SaveResult> resultList = Database.insert(new List<Transaction__c>{t1, t2}, false);
        // Verify 
        // In this case the insertion should have been stopped by the trigger,
        // so verify that we got back an error.
        for (Database.SaveResult result : resultList) {
            System.assert(!result.isSuccess());
            System.assert(result.getErrors().size() > 0);
            System.assertEquals(System.Label.sfims.part_of_error_message_17 + ' ' + System.Label.sfims.part_of_error_message_14, result.getErrors()[0].getMessage());
        }
    }

    @isTest static void test_validate_repayment_allocation_order() { 
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        lp.Repayment_Allocation_Type__c = 'Loan-based';
        insert lp;
        
        // create a new loan        
        Investment__c i = TestUtils.createNewScheduledLoan();
        i.Loan_Product__c = lp.Id;
        update i;
    
        // add a transaction with the type 'Repayment'
        Transaction__c t = TestUtils.createNewTransaction(i.Id, 1, 'Repayment');
        insert t;
        
        t.Repayment_Allocation_Order__c = null;
        
        // Perform test
        Database.SaveResult result = Database.update(t, false);
        // Verify 
        // In this case the insertion should have been stopped by the trigger,
        // so verify that we got back an error.
        System.assert(!result.isSuccess());
        System.assert(result.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.error_message_49,
            result.getErrors()[0].getMessage());
        
        t.Repayment_Allocation_Order__c = 'Late Repayment Fees Interest Fees Principal';
        
        // Perform test
        Database.SaveResult result2 = Database.update(t, false);
        // Verify 
        // In this case the insertion should have been stopped by the trigger,
        // so verify that we got back an error.
        System.assert(!result2.isSuccess());
        System.assert(result2.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.error_message_48,
            result2.getErrors()[0].getMessage());
        
        t.Repayment_Allocation_Order__c = 'Interest;Fees;Principal;';
        
        // Perform test
        Database.SaveResult result3 = Database.update(t, false);
        // Verify 
        // In this case the insertion should have been stopped by the trigger,
        // so verify that we got back an error.
        System.assert(!result3.isSuccess());
        System.assert(result3.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.error_message_48,
            result3.getErrors()[0].getMessage());

         t.Repayment_Allocation_Order__c = 'Interest;Interest;Fees;Principal;';
        
        // Perform test
        Database.SaveResult result4 = Database.update(t, false);
        // Verify 
        // In this case the insertion should have been stopped by the trigger,
        // so verify that we got back an error.
        System.assert(!result4.isSuccess());
        System.assert(result4.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.error_message_48,
            result3.getErrors()[0].getMessage());


        t.Repayment_Allocation_Order__c = 'Late Repayment Fees;Interest;Fees;Principal';

        // Perform test
        Database.SaveResult result5 = Database.update(t, false);
        // Verify 
        // In this case the insertion should have been stopped by the trigger,
        // so verify that we got back an error.
        System.assert(!result5.isSuccess());
        System.assert(result5.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.error_message_51, result5.getErrors()[0].getMessage());
             
    }

    @isTest static void test_delete_disbursements() { 
        // create a loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today(), System.today().addMonths(1));
        i.Setup_Fee_Charging_Method__c = 'Paid Up Front (scheduled)';
        i.Disbursement_Method__c = 'Tranched disbursement allowed';
        update i;

        // create disbursed transactions
        List<Transaction__c> trToInsert = new List<Transaction__c>();
        Integer numberOfTransactions = 4;
        for (Integer k = 0; k < numberOfTransactions; k++) {
            trToInsert.add(
                TestUtils.createNewTransaction(i.Id, i.Amount__c/numberOfTransactions, 'Disbursement', System.today().addMonths(1 + k))
            );
        }
        
        Map<String, String> status = DisburseLoanButtonController.saveData(i.Id, JSON.serialize(trToInsert), '[]');
        System.debug(status);
        // in this case, for each disbursed transaction the loan must be rescheduled
        // this also means that a loan event associated with this loan must be created 
        List<Transaction__c> disbursements = [
            SELECT Id
            FROM Transaction__c
            WHERE Investment__c =: i.Id AND Type__c = 'Disbursement' AND Status__c = 'Disbursed'
            ORDER BY Transaction_Date__c ASC
        ];

        // Perform test
        Database.DeleteResult result = Database.delete(disbursements[0], false);
        // Verify 
        // In this case the deletion should have been stopped by the trigger,
        // so verify that we got back an error.
        
        System.assert(!result.isSuccess());
        System.assert(result.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.part_of_error_message_18 + ': ' + System.Label.sfims.error_message_44, result.getErrors()[0].getMessage());

        System.assertEquals([SELECT COUNT() FROM Loan_Event__c WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Disbursement'], disbursements.size());

        delete disbursements;

        System.assertEquals([SELECT COUNT() FROM Transaction__c WHERE Investment__c =: i.Id AND Type__c = 'Disbursement'], 0);
        System.assertEquals([SELECT COUNT() FROM Loan_Event__c WHERE Investment__c =: i.Id AND Loan_Event_Type__c = 'Disbursement'], 0);    
    }
}