@isTest
private class TestInvestmentTriggerHandler {
    @isTest static void test_run_validation_for_loan_creation() {
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct('Test Loan Product');
        lp.Active__c = false;
        insert lp;
        
        // create a new loan
        Investment__c i = TestUtils.createNewLoan();
        i.Loan_Product__c = lp.Id;
		
        // Perform test
        Database.SaveResult result = Database.insert(i, false);
        // Verify 
        // In this case the update should have been stopped by the trigger,
        // so verify that we got back an error.
        
        System.assert(!result.isSuccess());
        System.assert(result.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.error_message_52, result.getErrors()[0].getMessage());

    }
    
    @isTest static void test_update_fields() {
        Investment__c i = TestUtils.createNewLoan();
        i.Setup_Fee__c = 'Flat Amount';
        i.Flat_Amount__c = 10;
		insert i;

        Investment__c inv = [
            SELECT Capitalized_Amount__c, Capitalized_Fee_Amount__c, Setup_Fee_Expected__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];
        System.assertEquals(i.Flat_Amount__c, inv.Setup_Fee_Expected__c);
        System.assertEquals(i.Flat_Amount__c, inv.Capitalized_Fee_Amount__c);
        System.assertEquals(i.Amount__c + i.Flat_Amount__c, inv.Capitalized_Amount__c);
        
        i.Setup_Fee_Charging_Method__c = 'Deducted From Principal';
        update i;

        Investment__c inv2 = [
            SELECT Capitalized_Amount__c, Capitalized_Fee_Amount__c, Setup_Fee_Expected__c
            FROM Investment__c
            WHERE Id =: i.Id
        ];
        System.assertEquals(i.Flat_Amount__c, inv2.Setup_Fee_Expected__c);
        System.assertEquals(0, inv2.Capitalized_Fee_Amount__c);
        System.assertEquals(i.Amount__c, inv2.Capitalized_Amount__c);

    }
    
    @isTest static void test_investment_delete() {
        Investment__c i = TestUtils.createNewScheduledLoan();
        Transaction__c tr = TestUtils.createNewTransaction(i.Id, 1, 'Repayment', System.today());
        Transaction__c tr2 = TestUtils.createNewTransaction(null, 1, 'Repayment', 'Declined', System.today());
        tr2.Investment_Reporting__c = i.Id;
        Progress_Report__c pr = new Progress_Report__c(Investment__c = i.Id);
        insert new List<SObject>{tr, tr2, pr};
        delete i;
        System.assertEquals(0,[SELECT Id FROM Investment__c WHERE Id = :i.Id].size());
        System.assertEquals(0,[SELECT Id FROM Loan_Event__c WHERE Investment__c = :i.Id].size());
        System.assertEquals(0,[SELECT Id FROM Transaction__c WHERE Investment__c = :i.Id OR Investment_Reporting__c = :i.Id].size());
        System.assertEquals(0,[SELECT Id FROM Progress_Report__c WHERE Investment__c = :i.Id].size());

    }

    @isTest static void test_investment_delete_as_platform_user() {
        User platformUser = TestUtils.createPlatformUser();
        System.runAs(platformUser){        
            Investment__c i = TestUtils.createNewLoan();
            insert i;
            delete i;
            System.assertEquals(0,[SELECT Id FROM Investment__c WHERE Id = :i.Id].size());
        }

    }
            
    @isTest static void test_investment_update_after_fund_change() {
        User platformUser = TestUtils.createPlatformUser();
        system.runAs(platformUser){                
            Investment__c i = TestUtils.createNewScheduledLoan();
            Fund__c f1 = new Fund__c(Name='fund1');
            insert f1;

            // now change the fund on the investment
            i.Loan_Fund__c = f1.Id;
            update i;

            // check that schedules got the fund
            List<Repayment_Schedule__c> rsList = [Select Id, Fund__c From Repayment_Schedule__c Where Loan__c = :i.Id];
            System.assertEquals(rsList[0].Fund__c,f1.Id);

            // check that transactions got the fund
            List<Transaction__c> transList = [Select Id, Fund__c From Transaction__c Where Investment_Reporting__c = :i.Id];
            System.assertEquals(transList[0].Fund__c,f1.Id);
        }

    }
    
    @isTest static void test_investment_update_after_account_change() {
        User platformUser = TestUtils.createPlatformUser();
        system.runAs(platformUser){        
            Account a = TestUtils.createAccount('Investee_Account', 'test', null);
            Account a2 = TestUtils.createAccount('Investee_Account', 'test2', null);
            insert new List<Account>{ a, a2 };
            Investment__c i = TestUtils.createNewScheduledLoan(a.Id, System.today().addMonths(-1), System.today());
            Progress_Report__c pr = new Progress_Report__c(Organisation__c = a.Id, Investment__c = i.Id);
            insert pr;
            Transaction__c t = TestUtils.createNewTransaction(i.Id, 50, 'Repayment');
            insert t;

            // now change the account on the investment
            i.Account__c = a2.Id;
            update i;

            // check that progress reports got the account
            List<Progress_Report__c> rsList = [Select Id, Organisation__c From Progress_Report__c Where Investment__c = :i.Id];
            system.assertEquals(rsList[0].Organisation__c,a2.Id);

            // check that transactions got the account
            List<Transaction__c> transList = [Select Id, Account__c From Transaction__c Where Object_Type__c = 'Transaction' AND Investment_Reporting__c = :i.Id];
            system.assertEquals(transList[0].Account__c,a2.Id);
        }
    }    
    
    @isTest static void test_investment_status_edited() {
        User platformUser = TestUtils.createPlatformUser();
             
        Milestone_Configuration__c mc1 = TestUtils.createNewMilestoneConfiguration('Investment', 'Active', 'Investment Active', 9);
        Milestone_Configuration__c mc2 = TestUtils.createNewMilestoneConfiguration('Investment', 'Closed - All Obligations Met', 'Investment Closed', 10);
            
        Application__c app = TestUtils.createNewApplication();
        
        Investment__c inv = TestUtils.createNewLoan(System.today(),System.today());
        inv.Status__c = 'Active';

        // admin creates the setup
        System.runAs(new User(ID = UserInfo.getUserID())){          
            insert new List<SObject>{ mc1, mc2, app };
            inv.Application__c = app.Id;
            insert inv;

            List<Milestone_History__c> mhList = [
                SELECT Milestone__c, Milestone_Date__c, Days_in_Milestone__c, Investment__c, Application__c, Sequence__c
                FROM Milestone_History__c
                WHERE Investment__c =: inv.Id
                ORDER BY Sequence__c DESC
            ];

            System.assertEquals(1, mhList.size());
            System.assertEquals(inv.Id, mhList[0].Investment__c);
            System.assertEquals('Investment Active', mhList[0].Milestone__c);
        }

        // platform user triggers the logic 
        system.runAs(platformUser){
            inv.Status__c = 'Closed - All Obligations Met';
            update inv;

            List<Milestone_History__c> mhList2 = [
                SELECT Milestone__c, Milestone_Date__c, Days_in_Milestone__c, Investment__c, Application__c, Sequence__c
                FROM Milestone_History__c
                WHERE Investment__c =: inv.Id
                ORDER BY Sequence__c DESC
            ];

            System.assertEquals(2, mhList2.size());
            System.assertEquals(inv.Id, mhList2[0].Investment__c);
            System.assertEquals(app.Id, mhList2[0].Application__c);
            System.assertEquals(null, mhList2[1].Days_in_Milestone__c);
        }
    }

    @isTest static void test_a_new_loan_event_after_an_investment_has_been_created() {
        User platformUser = TestUtils.createPlatformUser();
        system.runAs(platformUser){        
            Investment__c i = TestUtils.createNewLoan();
        	insert i; 

            // check if a new loan event has been created
            List<Loan_Event__c> loanEventList = [SELECT Id, Loan_Event_Type__c FROM Loan_Event__c WHERE Investment__c = :i.Id];
            system.assertEquals(1, loanEventList.size());
            system.assertEquals('Loan Creation', loanEventList[0].Loan_Event_Type__c);           
        }
    }

    @isTest static void test_validations_when_loan_is_active() {

        Account acc = TestUtils.createAccount('Investee_Account');
        insert acc;
        Application__c app = TestUtils.createNewApplication(acc.Id);
        Investment__c i = TestUtils.createNewLoan(acc.Id);
        insert new List<SObject>{i, app};

        List<Repayment_Schedule__c> schedules = LoanScheduler.generateScheduleById(i.Id);
        insert schedules;

        i.Status__c = 'Active';
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Monitoring_Fee_Percentage__c = 1;
        i.Application__c = app.Id;
        update i;

        Account acc2 = TestUtils.createAccount('Investee_Account', 'test2', null);
        Application__c app2 = TestUtils.createNewApplication(acc2.Id);
        
        i.Amount__c = 200;
        i.Application__c = app2.Id;
        i.Disbursement_Method__c = 'Tranched disbursement allowed';
        i.Disbursement_Date__c = System.today().addMonths(1);
        i.Early_Payment_Method__c = 'interestFullSchedule';
        i.First_Repayment_Date__c = System.today().addMonths(2);
        i.Flat_Amount__c = 9;
        i.Grace_Period_Type__c = 'Full Grace';
        i.Interest_Rate__c = 8;
        i.Late_Repayment_Calculation_Method__c = 'Principal';
        i.Late_Repayment_Interest_Rate__c = 4;
        i.Late_Repayment_Tolerance_Period__c = 1;
        i.Monitoring_Fee_Percentage__c = 2;
        i.Number_of_Grace_Periods__c = 1;
        i.Number_of_Instalments__c = 24;
        i.Repayment_Frequency__c = 2;
        i.Repayment_Frequency_Unit__c = 'Weeks';
        i.Setup_Fee__c = 'Flat Amount';
        i.Percent_of_Disbursement_Amount__c = 3;
        i.Setup_Fee_Cap__c = 10;

        // Perform test
        Database.SaveResult result = Database.update(i, false);
        // Verify 
        // In this case the update should have been stopped by the trigger,
        // so verify that we got back an error.
        
        System.assert(!result.isSuccess());
        System.assert(result.getErrors().size() > 0);
        System.assertEquals('Amount, Application, Disbursement Method, Disbursement Date, Early Payment Method, First Repayment Date, Flat Amount, ' + 
            'Grace Period Type, Interest Rate, Late Repayment Calculation Method, Late Repayment Interest Rate, ' + 
            'Late Repayment Tolerance Period (days), Monitoring Fee Percentage, Number of Grace Periods, Number of Instalments, Repayment Frequency, ' + 
            'Repayment Frequency Unit, Setup Fee, % of Disbursement Amount, Setup Fee Cap cannot be changed on the \'Active\' loan.',
            result.getErrors()[0].getMessage());

    }

    @isTest static void test_validation_loan_settings() {
        
        // create a new loan product
        Loan_Product__c lp = new Loan_Product__c(
            Name = 'Test Loan Product',
            Active__c = true,
            CBO_Default_Loan_Amount__c = false,
            Default_Loan_Amount__c = 100,
            CBO_Day_Count_Convention__c = false,
            Day_Count_Convention__c = '30/360',
            CBO_Disbursement_Method__c = false,
            Disbursement_Method__c = 'Full disbursement at start',
            CBO_Early_Payment_Method__c = false,
            Early_Payment_Method__c = 'Only Interest Due To Date Charged',
            CBO_Flat_Amount__c = false,
            Flat_Amount__c = 100,
            CBO_Default_Interest_Rate__c = false,
            Default_Interest_Rate__c = 5,
            CBO_Late_Repayment_Calculation_Method__c = false,
            Late_Repayment_Calculation_Method__c = 'No penalty',
            CBO_Late_Repayment_Interest_Rate__c = false,
            Late_Repayment_Interest_Rate__c = 8,
            CBO_Late_Repayment_Tolerance_Period__c = false,
            Default_Arrears_Tolerance_Period_days__c = 10,
            CBO_Default_Monitoring_Fee_Percentage__c = false,
            Default_Monitoring_Fee_Percentage__c = 1,
            CBO_Default_number_of_installments__c = false,
            Default_number_of_installments__c = 12,
            CBO_Non_Working_Days_Rescheduling__c = false,
            Non_Working_Days_Rescheduling__c = 'Do not reschedule repayments',
            CBO_Open_Ended_Loan__c = false,
            Open_Ended_Loan__c = false,
            CBO_Percent_Of_Disbursement_Amount__c = false,
            Percent_Of_Disbursement_Amount__c = 2,
            CBO_Repayment_Frequency_Unit__c = false, 
            Repayment_Frequency_Unit__c = 'Months',
            CBO_Repayment_Frequency__c = false, 
            Repayment_Frequency__c = 1,
            CBO_Setup_Fee_Charging_Method__c = false,
            Setup_Fee_Charging_Method__c = 'Capitalized',
            CBO_Setup_Fee__c = false,
            Setup_Fee__c = 'Flat Amount',
            CBO_Setup_Fee_Cap__c = false,
            Setup_Fee_Cap__c = 1,
            CBO_Default_Variable_Interest_Spread__c =false,
            Default_Variable_Interest_Spread__c = 3,
            Repayment_Allocation_Type__c = 'Schedule-based',
            Repayment_Allocation_Order__c = 'Interest;Late Repayment Fees;Fees;Principal;',
            Grace_Period_Types__c = 'No Grace;Pay Admin Fees Only;Pay Interest Only;Full Grace;',
            Interest_Rate_Source__c = 'Fixed Interest'
        );
        Account acc = TestUtils.createAccount('Investee_Account');
        insert new List<SObject>{ lp, acc };

        // create a new loan
        Investment__c inv = new Investment__c(
            Name = 'Test Loan',
            RecordTypeId = Utility.loanRecordTypeId,
            Loan_Product__c = lp.Id,
            Account__c = acc.Id,
            Number_of_Instalments__c = 12,
            Amount__c = 100,
            Interest_Rate__c = 5,
            Disbursement_Date__c = System.today(),
            Disbursement_Method__c = 'Full disbursement at start',
            First_Repayment_Date__c = System.today(),
            Day_Count_Convention__c = '30/360',
            Early_Payment_Method__c = 'interestDueToDate',
            Flat_Amount__c = 100,
            Grace_Period_Type__c = 'None',
            Late_Repayment_Calculation_Method__c = 'No penalty',
            Late_Repayment_Interest_Rate__c = 8,
            Late_Repayment_Tolerance_Period__c = 10,
            Monitoring_Fee_Percentage__c = 1,
            Non_Working_Days_Rescheduling__c = 'Do not reschedule repayments',
            Open_Ended_Loan__c = false,
            Percent_Of_Disbursement_Amount__c = 2,
            Repayment_Frequency_Unit__c = 'Months',
            Repayment_Frequency__c = 1,
            Setup_Fee_Charging_Method__c = 'Capitalized',
            Setup_Fee__c = 'Flat Amount',
            Setup_Fee_Cap__c = 1,
            Variable_Interest_Spread__c = 3
        );
        insert inv;
        
        // try to change settings as platform user and as admin 
        inv.Amount__c = 1000;
        inv.Day_Count_Convention__c = 'Actual/365';
        inv.Disbursement_Method__c = 'Tranched disbursement allowed';
        inv.Early_Payment_Method__c = 'interestFullSchedule';
        inv.Flat_Amount__c = 50;
        inv.Interest_Rate__c = 10;
        inv.Late_Repayment_Calculation_Method__c = 'Principal';
        inv.Late_Repayment_Interest_Rate__c = 5;
        inv.Late_Repayment_Tolerance_Period__c = 3;
        inv.Monitoring_Fee_Percentage__c = 2;
        inv.Non_Working_Days_Rescheduling__c = 'Move ahead to next working day';
        inv.Number_of_Instalments__c = 24;
        inv.Percent_Of_Disbursement_Amount__c = 1;
        inv.Repayment_Frequency_Unit__c = 'Weeks';
        inv.Repayment_Frequency__c = 2;
        inv.Setup_Fee_Charging_Method__c = 'Paid Up Front (scheduled)';
        inv.Setup_Fee__c = '% of Disbursement Amount';
        inv.Setup_Fee_Cap__c = 2;
        inv.Variable_Interest_Spread__c = 4;

        User platformUser = TestUtils.createPlatformUser();
        System.runAs(platformUser){
            // Perform test
            Database.SaveResult result = Database.update(inv, false);
            // Verify 
            // In this case the update should have been stopped by the trigger because user has no rights to change settings and no settings can be overridden,
            // so verify that we got back an error.
            
            System.assert(!result.isSuccess());
            System.assert(result.getErrors().size() > 0);
            System.assertEquals('No settings can be overridden. Settings on Loan level can only be changed by admin or Loan owner.',
                result.getErrors()[0].getMessage());
        }

        // verify results if nothing is filled in
        lp.Early_Payment_Method__c = '';
        lp.CBO_Early_Payment_Method__c = true;
        update lp;

        System.runAs(platformUser){
            // Perform test
            Database.SaveResult result2 = Database.update(inv, false);
            // Verify 
        // Verify 
            // Verify 
            // In this case the update should have been stopped by the trigger because only Early Payment Method can be overridden,
            // so verify that we got back an error.
            
            System.assert(!result2.isSuccess());
            System.assert(result2.getErrors().size() > 0);
            System.assertEquals('Only Early Payment Method can be overridden.',
                result2.getErrors()[0].getMessage());
        }
        
        // update loan settings to be able to override settings on the Loan Product object
        lp.CBO_Default_Loan_Amount__c = true;
        lp.CBO_Day_Count_Convention__c = true;
        lp.CBO_Disbursement_Method__c = true;
        lp.CBO_Early_Payment_Method__c = true;
        lp.CBO_Flat_Amount__c = true;
        lp.CBO_Default_Interest_Rate__c = true;
        lp.CBO_Late_Repayment_Calculation_Method__c = true;
        lp.CBO_Late_Repayment_Interest_Rate__c = true;
        lp.CBO_Late_Repayment_Tolerance_Period__c = true;
        lp.CBO_Default_Monitoring_Fee_Percentage__c = true;
        lp.CBO_Non_Working_Days_Rescheduling__c = true;
        lp.CBO_Default_number_of_installments__c = true;
        lp.CBO_Open_Ended_Loan__c = true;
        lp.CBO_Percent_Of_Disbursement_Amount__c = true;
        lp.CBO_Repayment_Frequency_Unit__c = true;
        lp.CBO_Repayment_Frequency__c = true;
        lp.CBO_Setup_Fee_Charging_Method__c = true;
        lp.CBO_Setup_Fee__c = true;
        lp.CBO_Setup_Fee_Cap__c = true;
        lp.CBO_Default_Variable_Interest_Spread__c = true;
        update lp;

        // Perform test
        Database.SaveResult result3 = Database.update(inv, false);
        System.assert(result3.isSuccess());
    
    }

    @isTest static void test_populate_fund_fields() {      
        Fund__c f = new Fund__c(Name = 'test Fund');
        insert f;
        Investment__c i = TestUtils.createNewScheduledLoan(System.today().addMonths(-1), System.today());
        i.Loan_Fund__c = f.Id;
        update i;
        Transaction__c t = TestUtils.createNewTransaction(i.Id, 10, 'Repayment');
        insert t;

        Fund__c fund = [
            SELECT Id, Fees_Due__c, Fees_Expected__c, Fees_Paid__c, Fees_Written_Off__c, Fees_Overdue__c, Fees_Remaining__c,
                Interest_Due__c, Interest_Expected__c, Interest_Paid__c, Interest_Written_Off__c, Interest_Overdue__c, Interest_Remaining__c,
                Late_Repayment_Fees_Due__c, Late_Repayment_Fees_Expected__c, Late_Repayment_Fees_Paid__c, Late_Repayment_Fees_Written_Off__c,
                Late_Repayment_Fees_Overdue__c, Late_Repayment_Fees_Remaining__c, Total_Expected__c, Setup_Fee_Expected__c, 
                Principal_Due__c, Principal_Expected__c, Principal_Paid__c, Principal_Written_Off__c, Principal_Overdue__c, Principal_Remaining__c,
            (
                SELECT Id, Fees_Due__c, Fees_Expected__c, Fees_Paid__c, Fees_Written_Off__c, Fees_Overdue__c, Fees_Remaining__c,
                    Interest_Due__c, Interest_Expected0__c, Interest_Paid__c, Interest_Written_Off__c, Interest_Overdue__c, Interest_Remaining__c,
                    Late_Repayment_Fees_Due__c, Late_Repayment_Fees_Expected0__c, Late_Repayment_Fees_Paid__c, Late_Repayment_Fees_Written_Off__c,
                    Late_Repayment_Fees_Overdue__c, Late_Repayment_Fees_Remaining__c, Total_Expected__c, Setup_Fee_Expected__c,
                    Principal_Due__c, Principal_Expected__c, Principal_Paid__c, Principal_Written_Off__c, Principal_Overdue__c, Principal_Remaining__c
                FROM Investments__r
            )
            FROM Fund__c 
            WHERE Id =: f.Id
        ];
       
        System.assertEquals(1, fund.Investments__r.size());
        System.assertEquals(fund.Investments__r[0].Fees_Due__c, fund.Fees_Due__c);           
        System.assertEquals(fund.Investments__r[0].Interest_Due__c, fund.Interest_Due__c);
        System.assertEquals(fund.Investments__r[0].Late_Repayment_Fees_Due__c, fund.Late_Repayment_Fees_Due__c);
        System.assertEquals(fund.Investments__r[0].Principal_Due__c, fund.Principal_Due__c);
        
        System.assertEquals(fund.Investments__r[0].Fees_Expected__c, fund.Fees_Expected__c);           
        //System.assertEquals(fund.Investments__r[0].Interest_Expected0__c, fund.Interest_Expected__c);
        //System.assertEquals(fund.Investments__r[0].Late_Repayment_Fees_Expected0__c, fund.Late_Repayment_Fees_Expected__c);
        System.assertEquals(fund.Investments__r[0].Principal_Expected__c, fund.Principal_Expected__c);
        
        System.assertEquals(fund.Investments__r[0].Fees_Paid__c, fund.Fees_Paid__c);           
        System.assertEquals(fund.Investments__r[0].Interest_Paid__c, fund.Interest_Paid__c);
        System.assertEquals(fund.Investments__r[0].Late_Repayment_Fees_Paid__c, fund.Late_Repayment_Fees_Paid__c);
        System.assertEquals(fund.Investments__r[0].Principal_Paid__c, fund.Principal_Paid__c);
        
        System.assertEquals(fund.Investments__r[0].Fees_Written_Off__c, fund.Fees_Written_Off__c);           
        System.assertEquals(fund.Investments__r[0].Interest_Written_Off__c, fund.Interest_Written_Off__c);
        System.assertEquals(fund.Investments__r[0].Late_Repayment_Fees_Written_Off__c, fund.Late_Repayment_Fees_Written_Off__c);
        System.assertEquals(fund.Investments__r[0].Principal_Written_Off__c, fund.Principal_Written_Off__c);

        System.assertEquals(fund.Investments__r[0].Fees_Overdue__c, fund.Fees_Overdue__c);           
        System.assertEquals(fund.Investments__r[0].Interest_Overdue__c, fund.Interest_Overdue__c);
        System.assertEquals(fund.Investments__r[0].Late_Repayment_Fees_Overdue__c, fund.Late_Repayment_Fees_Overdue__c);
        System.assertEquals(fund.Investments__r[0].Principal_Overdue__c, fund.Principal_Overdue__c);

        System.assertEquals(fund.Investments__r[0].Fees_Remaining__c, fund.Fees_Remaining__c);           
        System.assertEquals(fund.Investments__r[0].Interest_Remaining__c, fund.Interest_Remaining__c);
        System.assertEquals(fund.Investments__r[0].Late_Repayment_Fees_Remaining__c, fund.Late_Repayment_Fees_Remaining__c);
        System.assertEquals(fund.Investments__r[0].Principal_Remaining__c, fund.Principal_Remaining__c);
        
        System.assertEquals(fund.Investments__r[0].Setup_Fee_Expected__c, fund.Setup_Fee_Expected__c);
        System.assertEquals(fund.Investments__r[0].Total_Expected__c, fund.Total_Expected__c);

        delete i;

        Fund__c fund2 = [
            SELECT Id, Fees_Expected__c, Interest_Expected__c, Late_Repayment_Fees_Expected__c, 
                Principal_Expected__c, Setup_Fee_Expected__c, Total_Expected__c,
            (
                SELECT Total_Expected__c 
                FROM Investments__r
            )
            FROM Fund__c 
            WHERE Id =: f.Id
        ];

        System.assertEquals(0, fund2.Investments__r.size());
        System.assertEquals(0, fund2.Total_Expected__c);

    }

}