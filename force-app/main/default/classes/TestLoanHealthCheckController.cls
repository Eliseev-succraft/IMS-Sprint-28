@isTest
private class TestLoanHealthCheckController {

    @isTest static void test_getLoanData_sums_of_paid() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-7), System.today().addMonths(-6));
        i.Disbursement_Method__c = 'Full disbursement at start';
        update i;
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', System.today().addMonths(-7));
        Transaction__c t1 = TestUtils.createNewTransaction(i.Id, 10, 'Repayment');
        insert new List<Transaction__c>{t,t1};

        List<String> result = LoanHealthCheckController.getLoanData(i.Id);
        System.debug(result);
        System.assertEquals(0, result.size());
        
        Transaction__c t2 =  TestUtils.createNewTransaction(i.Id, 4, 'Repayment', System.today().addDays(-1));
        t2.Migration__c = true;
        t2.Fee_Amount__c = 1;
        t2.Interest_Amount__c = 1;
        t2.Late_Repayment_Fee_Amount__c = 1;
        t2.Principal_Amount__c = 1;
        insert t2;

        List<String> result2 = LoanHealthCheckController.getLoanData(i.Id);
        for (String str : result2) {
            System.debug(str);
        }
        System.assertEquals(5, result2.size());
    }

    @isTest static void test_getLoanData_transaction_date() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today(), System.today().addMonths(1));

        List<String> result = LoanHealthCheckController.getLoanData(i.Id);
        System.assertEquals(0, result.size());
        
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', 'Planned', System.today().addDays(-1));
        insert t;

        List<String> result2 = LoanHealthCheckController.getLoanData(i.Id);
        System.assertEquals(1, result2.size());
        System.assertEquals(System.Label.sfims.health_check_4, result2[0]);

    }

    @isTest static void test_getLoanData_recalculation_status() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-1), System.today());

        List<String> result = LoanHealthCheckController.getLoanData(i.Id);
        System.assertEquals(0, result.size());
        
        i.Recalculation_Status__c = 'Pending Recalculation';
        update i;

        List<String> result2 = LoanHealthCheckController.getLoanData(i.Id);
        System.assertEquals(1, result2.size());
        System.assertEquals(System.Label.sfims.health_check_1, result2[0]);

        i.Recalculation_Status__c = 'In Progress';
        update i;

        List<String> result3 = LoanHealthCheckController.getLoanData(i.Id);
        System.assertEquals(1, result3.size());
        System.assertEquals(System.Label.sfims.health_check_2, result3[0]);

        i.Recalculation_Status__c = 'Failed';
        update i;

        List<String> result4 = LoanHealthCheckController.getLoanData(i.Id);
        System.assertEquals(1, result4.size());
        System.assertEquals(System.Label.sfims.health_check_3, result4[0]);

    }

    @isTest static void test_getLoanData_expected_principal_balance() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today(), System.today().addMonths(1));

        List<String> result = LoanHealthCheckController.getLoanData(i.Id);
        System.debug(result);
        System.assertEquals(0, result.size());
        
        Repayment_Schedule__c rs = [
            SELECT Expected_Principal_Balance__c
            FROM Repayment_Schedule__c
            WHERE Loan__c =: i.Id AND Active__c = true
            ORDER BY Due_Date__c DESC
            LIMIT 1
        ];
        rs.Expected_Principal_Balance__c = 1;
        update rs;

        List<String> result2 = LoanHealthCheckController.getLoanData(i.Id);
        System.assertEquals(1, result2.size());
        System.assertEquals(System.Label.sfims.health_check_5, result2[0]);

    }

    @isTest static void test_getLoanData_principal_balance() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-1), System.today());
        i.Disbursement_Method__c = 'Full disbursement at start';
        update i;
        Transaction__c t = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', System.today().addMonths(-1));
        Transaction__c t1 = TestUtils.createNewTransaction(i.Id, 10, 'Repayment');
        insert new List<Transaction__c>{t,t1};

        List<String> result = LoanHealthCheckController.getLoanData(i.Id);
        System.debug(result);
        System.assertEquals(0, result.size());
        
        Repayment_Schedule__c rs = [
            SELECT Principal_Balance__c
            FROM Repayment_Schedule__c
            WHERE Loan__c =: i.Id AND Active__c = true
            ORDER BY Due_Date__c DESC
            LIMIT 1
        ];
        rs.Principal_Balance__c += 1;
        update rs;
        Transaction__c tr = [
            SELECT Principal_Balance__c
            FROM Transaction__c
            WHERE Investment__c =: i.Id
            ORDER BY Transaction_Date__c DESC
            LIMIT 1
        ];
        tr.Principal_Balance__c += 1;
        update tr;

        List<String> result2 = LoanHealthCheckController.getLoanData(i.Id);
        System.assertEquals(2, result2.size());
        System.assertEquals(System.Label.sfims.health_check_6, result2[0]);
        System.assertEquals(System.Label.sfims.health_check_7, result2[1]);

    }

    @isTest static void test_getLoanData_populate_late_repayment_fees_expected() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addmonths(-6), System.today().addmonths(-5));

        List<String> result = LoanHealthCheckController.getLoanData(i.Id);

        Investment__c inv = [
            SELECT Late_Repayment_Fees_Expected0__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];

        AggregateResult rsResult = [
            SELECT SUM(Late_Repayment_Fees_Expected0__c) lateRepaymentFeesExpected
            FROM Repayment_Schedule__c
            WHERE Loan__c =: i.Id
        ];
        System.debug(rsResult);
        
        System.assertEquals(inv.Late_Repayment_Fees_Expected0__c, rsResult.get('lateRepaymentFeesExpected'));
    }

    @isTest static void test_getLoanData_populate_interest_expected() {
        Investment__c i = TestUtils.createNewScheduledOpenEndedLoan(System.today().addDays(-7), 100);

        List<String> result = LoanHealthCheckController.getLoanData(i.Id);

        Investment__c inv = [
            SELECT Interest_Expected_Open_Ended_Loan__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];

        AggregateResult rsResult = [
            SELECT SUM(Interest_Expected_Open_Ended_Loan__c) interestExpected
            FROM Repayment_Schedule__c
            WHERE Loan__c =: i.Id
        ];
        System.debug(rsResult);
        
        System.assertEquals(inv.Interest_Expected_Open_Ended_Loan__c, rsResult.get('interestExpected'));
    }

    @isTest static void test_getLoanData_repayment_before_disbursement() {
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-1), System.today());
        
        List<String> result = LoanHealthCheckController.getLoanData(i.Id);
        System.debug(result);
        System.assertEquals(0, result.size());

        Transaction__c t = TestUtils.createNewTransaction(i.Id, 10, 'Repayment');
        insert t;

        List<String> result2 = LoanHealthCheckController.getLoanData(i.Id);
        System.assertEquals(1, result2.size());
        System.assertEquals(System.Label.sfims.health_check_8, result2[0]);

    }

}