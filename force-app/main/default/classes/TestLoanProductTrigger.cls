@isTest
private class TestLoanProductTrigger {
    
    @isTest static void test_validations() {
        
        // test loan settings
        // create org settings
        Loan_Settings__c ls = new Loan_Settings__c(
            CBO_Day_Count_Convention__c = false,
            Day_Count_Convention__c = '30/360',
            CBO_Early_Payment_Method__c = false,
            Early_Payment_Method__c = 'Only Interest Due To Date Charged',
            CBO_Flat_Amount__c = false,
            Flat_Amount__c = 100,
            CBO_Late_Repayment_Calculation_Method__c = false,
            Late_Repayment_Calculation_Method__c = 'No penalty',
            CBO_Late_Repayment_Interest_Rate__c = false,
            Late_Repayment_Interest_Rate__c = 8,
            CBO_Late_Repayment_Tolerance_Period__c = false,
            Late_Repayment_Tolerance_Period__c = 10,
            CBO_Monitoring_Fee_Percentage__c = false,
            Monitoring_Fee_Percentage__c = 1,
            CBO_Non_Working_Days_Rescheduling__c = false,
            Non_Working_Days_Rescheduling__c = 'Do not reschedule repayments',
            CBO_Percent_Of_Disbursement_Amount__c = false,
            Percent_Of_Disbursement_Amount__c = 2,
            CBO_Repayment_Allocation_Order__c = false,
            Repayment_Allocation_Order__c = 'Interest;Late Repayment Fees;Fees;Principal',
            CBO_Repayment_Allocation_Type__c = false,
            Repayment_Allocation_Type__c = 'Schedule-based',
            CBO_Repayment_Frequency_Unit__c = false, 
            Repayment_Frequency_Unit__c = 'Months',
            CBO_Repayment_Frequency__c = false, 
            Repayment_Frequency__c = 1,
            CBO_Setup_Fee_Charging_Method__c = false,
            Setup_Fee_Charging_Method__c = 'Capitalized',
            CBO_Setup_Fee__c = false,
            Setup_Fee__c = 'Flat Amount'
        );
        insert ls;

        // create a new loan product
        Loan_Product__c lp = new Loan_Product__c(
            Name = 'Test Loan Product',
            Day_Count_Convention__c = '30/360',
            Early_Payment_Method__c = 'Only Interest Due To Date Charged',
            Flat_Amount__c = 100,
            Late_Repayment_Calculation_Method__c = 'No penalty',
            Late_Repayment_Interest_Rate__c = 8,
            Default_Arrears_Tolerance_Period_days__c = 10,
            Default_Monitoring_Fee_Percentage__c = 1,
            Percent_Of_Disbursement_Amount__c = 2,
            Non_Working_Days_Rescheduling__c = 'Do not reschedule repayments',
            Repayment_Frequency_Unit__c = 'Months',
            Repayment_Frequency__c = 1,
            Setup_Fee_Charging_Method__c = 'Capitalized',
            Setup_Fee__c = 'Flat Amount',
            Repayment_Allocation_Order__c = 'Interest;Late Repayment Fees;Fees;Principal',
            Repayment_Allocation_Type__c = 'Schedule-based',
            Grace_Period_Types__c = 'No Grace;Pay Admin Fees Only;Pay Interest Only;Full Grace;',
            Interest_Rate_Source__c = 'Fixed Interest',
            CBO_Default_Interest_Rate__c = true,
            CBO_Default_Loan_Amount__c = true,
            CBO_Default_number_of_installments__c = true,
            CBO_Default_Variable_Interest_Spread__c = true,
            CBO_Disbursement_Method__c = true,
            CBO_Open_Ended_Loan__c = true,
            CBO_Setup_Fee_Cap__c = true
        );
        insert lp;
        
        // try to change settings as platform user and as admin 
        lp.Day_Count_Convention__c = 'Actual/365';
        lp.Early_Payment_Method__c = 'Full Interest For Scheduled Periods Charged';
        lp.Flat_Amount__c = 50;
        lp.Late_Repayment_Calculation_Method__c = 'Overdue Principal * # of Late Days * Penalty Rate';
        lp.Late_Repayment_Interest_Rate__c = 5;
        lp.Default_Arrears_Tolerance_Period_days__c = 3;
        lp.Default_Monitoring_Fee_Percentage__c = 2;
        lp.Non_Working_Days_Rescheduling__c = 'Move ahead to next working day';
        lp.Percent_Of_Disbursement_Amount__c = 1;
        lp.Repayment_Allocation_Order__c = 'Fees;Late Repayment Fees;Interest;Principal';
        lp.Repayment_Allocation_Type__c = 'Loan-based';
        lp.Repayment_Frequency_Unit__c = 'Weeks';
        lp.Repayment_Frequency__c = 2;
        lp.Setup_Fee_Charging_Method__c = 'Deducted From Principal';
        lp.Setup_Fee__c = '% of Disbursement Amount';

        User platformUser = TestUtils.createPlatformUser();
        System.runAs(platformUser){
            // Perform test
            Database.SaveResult result = Database.update(lp, false);
            // Verify 
            // In this case the update should have been stopped by the trigger because user has no rights to change settings and no settings can be overridden,
            // so verify that we got back an error.
            
            System.assert(!result.isSuccess());
            System.assert(result.getErrors().size() > 0);
            System.assertEquals('No settings can be overridden. Settings on Loan Product level can only be changed by admin or Loan Product owner.',
                result.getErrors()[0].getMessage());
        }

        // verify results if nothing is filled in
        ls.Early_Payment_Method__c = '';
        update ls;

        System.runAs(platformUser){
            // Perform test
            Database.SaveResult result2 = Database.update(lp, false);
            // Verify 
            // In this case the update should have been stopped by the trigger because only Early Payment Method can be overridden,
            // so verify that we got back an error.
            
            System.assert(!result2.isSuccess());
            System.assert(result2.getErrors().size() > 0);
            System.assertEquals('Only Early Payment Method can be overridden.',
                result2.getErrors()[0].getMessage());
        }
        
        // update loan settings to be able to override settings on the Loan Product object
        ls.CBO_Day_Count_Convention__c = true;
        ls.CBO_Early_Payment_Method__c = true;
        ls.CBO_Flat_Amount__c = true;
        ls.CBO_Late_Repayment_Calculation_Method__c = true;
        ls.CBO_Late_Repayment_Interest_Rate__c = true;
        ls.CBO_Late_Repayment_Tolerance_Period__c = true;
        ls.CBO_Monitoring_Fee_Percentage__c = true;
        ls.CBO_Non_Working_Days_Rescheduling__c = true;
        ls.CBO_Percent_Of_Disbursement_Amount__c = true;
        ls.CBO_Repayment_Allocation_Order__c = true;
        ls.CBO_Repayment_Allocation_Type__c = true;
        ls.CBO_Repayment_Frequency_Unit__c = true;
        ls.CBO_Repayment_Frequency__c = true;
        ls.CBO_Setup_Fee_Charging_Method__c = true;
        ls.CBO_Setup_Fee__c = true;
        update ls;

        // Perform test
        Database.SaveResult result3 = Database.update(lp, false);
        update lp;
        System.assert(result3.isSuccess());

        // test repayment allocation
        Validation_Settings__c vs = new Validation_Settings__c(
            Disable_Validation_Rules_on_Loan_Product__c = false
        );
        insert vs;
        
        // create a new loan
        Investment__c i = TestUtils.createNewScheduledLoan();
        i.Loan_Product__c = lp.Id;
        i.Status__c = 'Active';
        update i;

        lp.Repayment_Allocation_Order__c = 'Late Repayment Fees;Interest;Fees;Principal';

        // Perform test
        Database.SaveResult result4 = Database.update(lp, false);
        // Verify 
        // In this case the update should have been stopped by the trigger,
        // so verify that we got back an error.
        
        System.assert(!result4.isSuccess());
        System.assert(result4.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.error_message_45,
            result4.getErrors()[0].getMessage());
    
    }
}