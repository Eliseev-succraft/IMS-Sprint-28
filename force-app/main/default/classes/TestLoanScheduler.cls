@isTest
private class TestLoanScheduler {

    @isTest static void test_loan_scheduling() {
        Investment__c i = TestUtils.createNewLoan();
        i.Number_of_Instalments__c = 12;
        i.Repayment_Frequency__c = 1;
        i.Repayment_Frequency_Unit__c = 'Months';
        i.Number_of_Grace_Periods__c = 2;
        i.Grace_Period_Type__c = 'Interest';
        i.Amount__c = 100;
        i.Interest_Rate__c = 5;
        i.Disbursement_Date__c = System.today();
        i.First_Repayment_Date__c = System.today().addMonths(1);          
        insert i;

        List<Repayment_Schedule__c> scheduleToInsert = LoanScheduler.generateScheduleById(i.Id);
        
        System.assertEquals(12,scheduleToInsert.size());

        // test the same with unauthorized user
        User newUser = TestUtils.ensureRestrictedUser();
        System.runAs(newUser){
            List<Repayment_Schedule__c> scheduleToInsert2;
            try{
                scheduleToInsert2 = LoanScheduler.generateScheduleById(i.Id);
                System.assert(false,'Expected an exception (unauthorized user');
            } catch (AuraHandledException e){
                // expected
                System.assertEquals(null, scheduleToInsert2);
            }
        }        
    }

    @isTest static void test_loan_scheduling_full_grace() {
        Investment__c i = TestUtils.createNewLoan();
        i.Number_of_Instalments__c = 12;
        i.Repayment_Frequency__c = 1;
        i.Repayment_Frequency_Unit__c = 'Years';
        i.Number_of_Grace_Periods__c = 2;
        i.Grace_Period_Type__c = 'Full';
        i.Amount__c = 100;
        i.Interest_Rate__c = null;
        i.Disbursement_Date__c = System.today();
        i.First_Repayment_Date__c = System.today().addMonths(1);          
        insert i;

        List<Repayment_Schedule__c> scheduleToInsert = LoanScheduler.generateScheduleById(i.Id);
        
        System.assertEquals(12,scheduleToInsert.size());
      
    }

    @isTest static void test_standard_loan_recalculation_30_360() {
        Investment__c i = TestUtils.createNewLoan();
        i.Number_of_Instalments__c = 12;
        i.Repayment_Frequency__c = 1;
        i.Repayment_Frequency_Unit__c = 'Months';
        i.Number_of_Grace_Periods__c = 2;
        i.Grace_Period_Type__c = 'Interest';
        i.Amount__c = 100;
        i.Interest_Rate__c = 5;
        i.Disbursement_Date__c = System.today();
        i.First_Repayment_Date__c = System.today().addMonths(1);          
        insert i;

        LoanScheduler.recalculateLoanSchedule(i.Id);
        
        System.assertEquals(12,[select id from repayment_schedule__c where loan__c = :i.Id].size());

        // test the same with unauthorized user
        User newUser = TestUtils.ensureRestrictedUser();
        System.runAs(newUser){
            try{
                LoanScheduler.recalculateLoanSchedule(i.Id);
                System.assert(false,'Expected an exception (unauthorized user');
            } catch (AuraHandledException e){
                // expected
                System.assertEquals(true,true);
            }
        }          
    }

    @isTest static void test_create_a_repayment_schedule_for_a_loan_with_the_paid_up_front_type_of_the_setup_see_charging_method() {
        Investment__c i = TestUtils.createNewLoan();
        i.Number_of_Instalments__c = 12;
        i.Repayment_Frequency__c = 1;
        i.Repayment_Frequency_Unit__c = 'Months';
        i.Number_of_Grace_Periods__c = 2;
        i.Grace_Period_Type__c = 'Interest';
        i.Amount__c = 100;
        i.Interest_Rate__c = 0.05;
        i.Disbursement_Date__c = System.today();
        i.First_Repayment_Date__c = System.today().addMonths(1);
        i.Setup_Fee_Charging_Method__c = 'Paid Up Front (scheduled)'; 
        i.Setup_Fee__c = 'Flat Amount';
        i.Flat_Amount__c = 5;         
        insert i;

        LoanScheduler.recalculateLoanSchedule(i.Id);

        List<Repayment_Schedule__c> result = [
            SELECT Id, Fees_Expected__c, Interest_Expected0__c, Principal_Expected__c
            FROM Repayment_Schedule__c 
            WHERE Loan__c = :i.Id AND Due_Date__c =: i.Disbursement_Date__c
        ];
        System.assertEquals(1, result.size());
        System.assertEquals(i.Flat_Amount__c, result[0].Fees_Expected__c);
        System.assertEquals(0, result[0].Principal_Expected__c);
        System.assertEquals(0, result[0].Interest_Expected0__c);
        
    }

    @isTest static void test_open_ended_loan_recalculation() {
        Investment__c i = TestUtils.createOpenEndedLoan();        
        insert i;

        LoanScheduler.recalculateLoanSchedule(i.Id);
        
        System.assertEquals(1,[SELECT Id FROM Repayment_Schedule__c WHERE Loan__c = :i.Id].size());

        // test the same with unauthorized user
        User newUser = TestUtils.ensureRestrictedUser();
        System.runAs(newUser){
            try{
                LoanScheduler.recalculateLoanSchedule(i.Id);
                System.assert(false,'Expected an exception (unauthorized user');
            } catch (AuraHandledException e){
                // expected
                System.assertEquals(true,true);
            }
        }          
    }

    @isTest static void test_standard_loan_recalculation_actual_365() {
        Investment__c i = TestUtils.createNewLoan();
        i.Number_of_Instalments__c = 12;
        i.Repayment_Frequency__c = 1;
        i.Repayment_Frequency_Unit__c = 'Months';
        i.Number_of_Grace_Periods__c = 2;
        i.Grace_Period_Type__c = 'Interest';
        i.Amount__c = 100;
        i.Interest_Rate__c = 5;
        i.Disbursement_Date__c = System.today();
        i.First_Repayment_Date__c = System.today().addMonths(1);
        i.Day_Count_Convention__c = 'Actual/365';         
        insert i;

        LoanScheduler.recalculateLoanSchedule(i.Id);
        
        System.assertEquals(12,[select id from repayment_schedule__c where loan__c = :i.Id].size());

        // test the same with unauthorized user
        User newUser = TestUtils.ensureRestrictedUser();
        System.runAs(newUser){
            try{
                LoanScheduler.recalculateLoanSchedule(i.Id);
                System.assert(false,'Expected an exception (unauthorized user');
            } catch (AuraHandledException e){
                // expected
                System.assertEquals(true,true);
            }
        }          
    }

    @isTest static void test_standard_loan_recalculation_actual_365l() {
        Investment__c i = TestUtils.createNewLoan();
        i.Number_of_Instalments__c = 12;
        i.Repayment_Frequency__c = 1;
        i.Repayment_Frequency_Unit__c = 'Months';
        i.Number_of_Grace_Periods__c = 2;
        i.Grace_Period_Type__c = 'Interest';
        i.Amount__c = 100;
        i.Interest_Rate__c = 5;
        i.Disbursement_Date__c = System.today();
        i.First_Repayment_Date__c = System.today().addMonths(1);
        i.Day_Count_Convention__c = 'Actual/365L';          
        insert i;

        LoanScheduler.recalculateLoanSchedule(i.Id);
        
        System.assertEquals(12,[select id from repayment_schedule__c where loan__c = :i.Id].size());

        // test the same with unauthorized user
        User newUser = TestUtils.ensureRestrictedUser();
        System.runAs(newUser){
            try{
                LoanScheduler.recalculateLoanSchedule(i.Id);
                System.assert(false,'Expected an exception (unauthorized user');
            } catch (AuraHandledException e){
                // expected
                System.assertEquals(true,true);
            }
        }          
    }

    @isTest static void test_monitoring_fee_calculations() {
        Investment__c i = TestUtils.createNewLoan();
        i.Number_of_Instalments__c = 12;
        i.Repayment_Frequency__c = 1;
        i.Repayment_Frequency_Unit__c = 'Months';
        i.Grace_Period_Type__c = 'None';
        i.Amount__c = 100;
        i.Interest_Rate__c = 6;
        i.Monitoring_Fee_Percentage__c = 3;
        i.Disbursement_Date__c = System.today();
        i.First_Repayment_Date__c = System.today().addMonths(1);          
        insert i;

        List<Repayment_Schedule__c> scheduleToInsert = LoanScheduler.generateScheduleById(i.Id);
        
        System.assertEquals(i.Number_of_Instalments__c, scheduleToInsert.size());
        for (Repayment_Schedule__c rs : scheduleToInsert) {
            System.assertEquals(rs.Monitoring_Fee_Percentage__c, i.Monitoring_Fee_Percentage__c);
        }

        // test the same with unauthorized user
        User newUser = TestUtils.ensureRestrictedUser();
        System.runAs(newUser){
            List<Repayment_Schedule__c> scheduleToInsert2;
            try{
                scheduleToInsert2 = LoanScheduler.generateScheduleById(i.Id);
                System.assert(false,'Expected an exception (unauthorized user');
            } catch (AuraHandledException e){
                // expected
                System.assertEquals(null,scheduleToInsert2);
            }
        }        
    }

}