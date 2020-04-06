@isTest
private class TestRecalculateButtonController {
    @isTest static void test_recalculate_open_ended_loan_on_create(){
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledOpenEndedLoan(System.today().addMonths(-1), 100);
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        update i;

        // add a disbursement
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', System.today().addMonths(-1));
        DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');

        // add a repayment
        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, i.Amount__c/10, 'Repayment');
        insert t2;

        List<Repayment_Schedule__c> expectedRS = [
            SELECT Principal_Expected__c, Interest_Expected0__c, Principal_Paid__c, Interest_Paid__c, Active__c
            FROM Repayment_Schedule__c
            WHERE Loan__c = :i.Id
        ];
        System.assertEquals(1, expectedRS.size());

        delete [SELECT Id FROM Repayment_Schedule__c WHERE Loan__c = :i.Id];

        // pefrorm test
        RecalculateButtonController.recalculateOpenEndedLoan(i.Id);

        Investment__c result = [
            SELECT Recalculation_Status__c
            FROM Investment__c
            WHERE Id = :i.Id
        ];

        List<Repayment_Schedule__c> actualRS = [
            SELECT Principal_Expected__c, Interest_Expected0__c, Principal_Paid__c, Interest_Paid__c, Active__c
            FROM Repayment_Schedule__c
            WHERE Loan__c = :i.Id
            ORDER BY Due_Date__c ASC
        ];

        // check results
        System.assertEquals('Done', result.Recalculation_Status__c);
        System.assertEquals(expectedRS.size(), actualRS.size());
        System.assertEquals(expectedRS[0].Principal_Expected__c.setscale(2), actualRS[0].Principal_Expected__c.setscale(2));
        System.assertEquals(expectedRS[0].Interest_Expected0__c.setscale(2), actualRS[0].Interest_Expected0__c.setscale(2));
        System.assertEquals(expectedRS[0].Principal_Paid__c.setscale(2), actualRS[0].Principal_Paid__c.setscale(2));
        System.assertEquals(expectedRS[0].Interest_Paid__c.setscale(2), actualRS[0].Interest_Paid__c.setscale(2));
    }
    
    @isTest static void test_recalculate_open_ended_loan_on_delete(){
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledOpenEndedLoan(System.today().addMonths(-1), 100);
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        update i;

        // add a disbursement
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', System.today().addMonths(-1));
        DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');

        // add a repayment
        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, i.Amount__c/10, 'Repayment');
        insert t2;

        // delete transactions
        delete [SELECT Id FROM Transaction__c WHERE Investment__c = :i.Id];
        
        // pefrorm test
        RecalculateButtonController.recalculateOpenEndedLoan(i.Id);

        Investment__c result = [
            SELECT Status__c, Recalculation_Status__c
            FROM Investment__c
            WHERE Id = :i.Id
        ];

        // check results
        System.assertEquals('Inactive', result.Status__c);
        System.assertEquals('Not Needed', result.Recalculation_Status__c);
    }

    @isTest static void test_recalculation_scheduler(){
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-2), System.today().addMonths(-1));
        i.Loan_Product__c = lp.Id;
        i.Setup_Fee_Charging_Method__c = 'Paid Up Front (scheduled)';
        i.Disbursement_Method__c = 'Tranched disbursement allowed';
        update i;
        // add a disbursement
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c/2, 'Disbursement', System.today().addMonths(-2));
        DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');

        // add a repayment
        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, i.Amount__c/12, 'Repayment', System.today().addMonths(-1));
        insert t2;
        
        Test.startTest();
        RecalculateButtonController.runRecalculationScheduler(JSON.serialize(i));
        System.assert([SELECT COUNT() FROM CronTrigger] > 0, 'A job should be scheduled');
        Test.stopTest();

    }

    @isTest static void test_get_loan_data_and_process_loan_event(){
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-2), System.today().addMonths(-1));
        i.Loan_Product__c = lp.Id;
        i.Setup_Fee_Charging_Method__c = 'Paid Up Front (scheduled)';
        i.Disbursement_Method__c = 'Tranched disbursement allowed';
        update i;
        // add a disbursement
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c/2, 'Disbursement', System.today().addMonths(-2));
        DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t}), '[]');
        
        Map<String, String> resultMap = RecalculateButtonController.getLoanData(i.Id);
        System.assert(resultMap.containsKey('loan'));
        System.assert(resultMap.containsKey('loanEvents'));

        Investment__c theLoan = (Investment__c)JSON.deserialize(resultMap.get('loan'), Investment__c.class);
        List<Loan_Event__c> loanEvents = (List<Loan_Event__c>)JSON.deserialize(resultMap.get('loanEvents'), List<Loan_Event__c>.class);
        System.debug(loanEvents.size());
        
        Map<String, String> resultMap2 = RecalculateButtonController.processLoanEvent(resultMap.get('loan'), resultMap.get('loanEvents'), 0, null, 0, RecalculateButtonController.runRecalculationScheduler(JSON.serialize(i)));
        System.debug(resultMap2);
        System.assert(resultMap2.containsKey('eventDate'));
        System.assert(resultMap2.containsKey('index'));
        System.assertEquals(loanEvents[0].Event_Date__c, Date.valueOf(resultMap2.get('eventDate')));
        System.assertEquals(1, Integer.valueOf(resultMap2.get('index')));
    }

    @isTest static void test_run_recalculation_without_loan_events(){
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-2), System.today().addMonths(-1));
        i.Loan_Product__c = lp.Id;
        i.Setup_Fee_Charging_Method__c = 'Paid Up Front (scheduled)';
        i.Disbursement_Method__c = 'Tranched disbursement allowed';
        update i;
        
        Map<String, String> resultMap = RecalculateButtonController.getLoanData(i.Id);
        System.assert(resultMap.containsKey('loan'));
        System.assert(!resultMap.containsKey('loanEvents'));
        
        RecalculateButtonController.runRecalculationWithoutLoanEvents(resultMap.get('loan'));
        
        Investment__c result = [
            SELECT Status__c, Recalculation_Status__c
            FROM Investment__c
            WHERE Id = :i.Id
        ];

        System.assertEquals('Inactive', result.Status__c);
        System.assertEquals('Not Needed', result.Recalculation_Status__c);
    }
}