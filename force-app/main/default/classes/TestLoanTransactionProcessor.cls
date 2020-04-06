@isTest
private class TestLoanTransactionProcessor {
    
    @isTest static void test_transaction_processing_for_a_standard_loan() {
        User platformUser = TestUtils.createPlatformUser();
        system.runAs(platformUser){
            // create a new loan product and an account
            Loan_Product__c lp = TestUtils.createNewLoanProduct();
            Account acc = TestUtils.createAccount('Investee_Account');
            insert new List<SObject>{ lp, acc };

            // create the loan
            Date startDate = System.today().addYears(-1);
            Integer numberOfPeriods = 360;
            Investment__c i = new Investment__c();
            i.Name = 'Test Loan';
            i.Loan_Product__c = lp.Id;
            i.Account__c = acc.Id;
            i.Status__c = 'Inactive';
            i.Amount__c = 1000;
            i.Interest_Rate__c = 0.05;
            i.Disbursement_Date__c = startDate;
            i.First_Repayment_Date__c = startDate.addMonths(1);
            i.Number_of_Instalments__c = numberOfPeriods;  
            i.Repayment_Frequency__c = 1;
            i.Repayment_Frequency_Unit__c = 'Months';
            i.Number_of_Grace_Periods__c = 0;
            i.Grace_Period_Type__c = 'None';
            i.Late_Repayment_Calculation_Method__c = 'No Penalty';
            i.RecordTypeId = Utility.loanRecordTypeId; 
            insert i;

            // now create the schedule
            List<Repayment_Schedule__c> schedules = new List<Repayment_Schedule__c>();
            for (Integer k = 0; k < numberOfPeriods; k++){
                Repayment_Schedule__c rs = new Repayment_Schedule__c();
                rs.Loan__c = i.Id;
                rs.Status__c = 'Pending';
                rs.Due_Date__c = startDate.addMonths(k);
                rs.Principal_Expected__c = 100+k;
                rs.Interest_Expected_Standard_Loan__c = 5;
                rs.Interest_Rate__c = 0.05;
                rs.Fees_Expected__c = 5;
                schedules.add(rs);
            }
            insert schedules;
    
            // make sure penalty interest is calculated
            i.Status__c = 'Active';
            i.Late_Repayment_Calculation_Method__c = 'Principal';
            i.Late_Repayment_Interest_Rate__c = 0.05;
            i.Late_Repayment_Tolerance_Period__c = 0;
            update i;

            // take the first schedule and check the status
            Repayment_Schedule__c rs = [
                SELECT Status__c
                FROM Repayment_Schedule__C 
                WHERE Loan__c = :i.Id 
                ORDER BY Due_Date__c ASC 
                LIMIT 1
            ];
            system.assertEquals('Late', rs.Status__c);

            // partly repay the first schedule
            Transaction__c t = TestUtils.createNewTransaction(i.Id, 60, 'Repayment', startDate);
            insert t;

            Investment__c inv = [
                SELECT Total_Paid__c, Principal_Paid__c, Interest_Paid__c, Fees_Paid__c, Late_Repayment_Fees_Paid__c 
                FROM Investment__c 
                WHERE Id = :i.Id
            ];

            System.debug(inv);
            
            System.assertEquals(60, inv.Total_Paid__c.setScale(2));
            System.assertEquals(50, inv.Principal_Paid__c.setScale(2));
            System.assertEquals(5, inv.Interest_Paid__c.setScale(2));
            System.assertEquals(5, inv.Fees_Paid__c.setScale(2));

            // repay the second schedule (late)
            Transaction__c t2 = TestUtils.createNewTransaction(i.Id, 150, 'Repayment', startDate.addMonths(1));
            insert t2;

            Investment__c inv2 = [
                SELECT Total_Paid__c, Principal_Paid__c, Interest_Paid__c, Fees_Paid__c 
                FROM Investment__c 
                WHERE Id = :i.Id
            ];
            System.assertEquals(210, inv2.Total_Paid__c.setScale(2));
            System.assertEquals(190, inv2.Principal_Paid__c.setScale(2));
            System.assertEquals(10, inv2.Interest_Paid__c.setScale(2));
            System.assertEquals(10, inv2.Fees_Paid__c.setScale(2));

            // repay the second and third schedule, including some penalty interest and early repayment
            Transaction__c t3 = TestUtils.createNewTransaction(i.Id, 550, 'Repayment', startDate.addMonths(2));
            insert t3; 

            Investment__c inv3 = [
                SELECT Total_Paid__c, Principal_Paid__c, Interest_Paid__c, Fees_Paid__c 
                FROM Investment__c 
                WHERE Id = :i.Id
            ];
            System.assertEquals(760, inv3.Total_Paid__c.setScale(2));
            System.assertEquals(715, inv3.Principal_Paid__c.setScale(2));
            System.assertEquals(15, inv3.Interest_Paid__c.setScale(2));
            System.assertEquals(30, inv3.Fees_Paid__c.setScale(2));
        }
    }

    @isTest static void test_transaction_processing_for_an_open_ended_loan() {
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;
        
        // create the loan
        Investment__c i = TestUtils.createNewScheduledOpenEndedLoan(System.today().addDays(-30), 100);
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Status__c = 'Inactive';
        update i;

        // add a disbursement
        Transaction__c d = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', System.today().addDays(-30));
        DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{d}), '[]');

        Transaction__c t = TestUtils.createNewTransaction(i.Id, 10.1 , 'Repayment', System.today().addDays(-20));
        insert t;

        Investment__c inv = [
            SELECT Total_Paid__c, Principal_Paid__c, Interest_Paid__c
            FROM Investment__c 
            WHERE Id = :i.Id
        ];
        
        System.assertEquals(10.1, inv.Total_Paid__c);
        System.assertEquals(10, inv.Principal_Paid__c);
        System.assertEquals(0.1, inv.Interest_Paid__c);

        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, 40.09, 'Repayment', System.today().addDays(-10));
        insert t2;

        Investment__c inv2 = [
            SELECT Total_Paid__c, Principal_Paid__c, Interest_Paid__c
            FROM Investment__c 
            WHERE Id = :i.Id
        ];
        System.assertEquals(50.19, inv2.Total_Paid__c);
        System.assertEquals(50, inv2.Principal_Paid__c);
        System.assertEquals(0.19, inv2.Interest_Paid__c);
        

        // repay the second and third schedule, including some penalty interest and early repayment
        Transaction__c t3 = TestUtils.createNewTransaction(i.Id, 20.05, 'Repayment');
        insert t3; 

        Investment__c inv3 = [
            SELECT Total_Paid__c, Principal_Paid__c, Interest_Paid__c 
            FROM Investment__c 
            WHERE Id = :i.Id
        ];
        System.assertEquals(70.24, inv3.Total_Paid__c);
        System.assertEquals(70, inv3.Principal_Paid__c);
        System.assertEquals(0.24, inv3.Interest_Paid__c);
    }

    @isTest static void test_transaction_processing_unauthorized() {
        
        Account a = TestUtils.createAccount('Investee_Account','test',null);
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addYears(-1), System.today().addMonths(-11));

        User newUser = TestUtils.ensureRestrictedUser();
        System.runAs(newUser){
            try{
                LoanTransactionProcessor.processLoanTransactions(new Set<Id> {i.Id});
                System.assert(false,'Expected an exception (unauthorized user');
            } catch (AuraHandledException e){
                // expected
                system.assertEquals(true,true);
            }
        }  
    }

    @isTest static void test_late_repayment_fixed_fee() {
        // create a loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        insert lp;

        // create a loan in the past
        Investment__c i = TestUtils.createNewLoan(System.today().addmonths(-2), System.today().addmonths(-1));
        i.Loan_Product__c = lp.Id;
        i.Status__c = 'Inactive';
        i.Late_Repayment_Calculation_Method__c = 'Fixed Fee';
        i.Late_Repayment_Fixed_Fee__c = 1;
        i.Late_Repayment_Interest_Rate__c = null;
        i.Late_Repayment_Tolerance_Period__c = 5;
        i.Disbursement_Method__c = 'Full disbursement at start';
        insert i;
        
        // generate repayment schedules
        List<Repayment_Schedule__c> schedules = LoanScheduler.generateScheduleById(i.Id);
        insert schedules;

        // add a disbursement
        Transaction__c t1 = TestUtils.createNewTransaction(i.Id, i.Amount__c, 'Disbursement', System.today().addmonths(-2));
       
        Map<String, String> result = DisburseLoanButtonController.saveData(i.Id, JSON.serialize(new List<Transaction__c>{t1}), '[]');
        
        Repayment_Schedule__c rs = [
            SELECT Late_Repayment_Fixed_Fee__c, Total_Remaining__c, Late_Repayment_Fees_Remaining__c 
            FROM Repayment_Schedule__c 
            WHERE Loan__c = :i.Id 
            ORDER BY Due_Date__c ASC 
            LIMIT 1
        ];

        // verify if Late Repayment Fixed Fee was calculated
        System.assertEquals(i.Late_Repayment_Fixed_Fee__c, rs.Late_Repayment_Fixed_Fee__c);
        System.debug(rs);
        System.debug(rs.Total_Remaining__c);
        System.debug(rs.Late_Repayment_Fees_Remaining__c);
        
        // pay in time
        Transaction__c t2 = TestUtils.createNewTransaction(i.Id, (rs.Total_Remaining__c - rs.Late_Repayment_Fees_Remaining__c), 'Repayment', System.today().addmonths(-1));
        insert t2;

        Repayment_Schedule__c rs2 = [
            SELECT Late_Repayment_Fixed_Fee__c, Total_Remaining__c 
            FROM Repayment_Schedule__c 
            WHERE Loan__c = :i.Id 
            ORDER BY Due_Date__c ASC 
            LIMIT 1
        ];
        System.debug(rs2);

        // verify if Late Repayment Fixed Fee was calculated
        System.assertEquals(null, rs2.Late_Repayment_Fixed_Fee__c);

        // pay late
        Transaction__c t3 = TestUtils.createNewTransaction(i.Id, (rs.Total_Remaining__c - rs.Late_Repayment_Fees_Remaining__c), 'Repayment', System.today().addmonths(1));
        insert t3;

        List<Repayment_Schedule__c> rsList = [
            SELECT Late_Repayment_Fixed_Fee__c, Total_Remaining__c 
            FROM Repayment_Schedule__c 
            WHERE Loan__c = :i.Id 
            ORDER BY Due_Date__c ASC 
        ];
        
        // verify if Late Repayment Fixed Fee was calculated
        System.assertEquals(i.Late_Repayment_Fixed_Fee__c, rsList[1].Late_Repayment_Fixed_Fee__c);
        
    }        
        
}