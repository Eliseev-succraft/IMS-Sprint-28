global with sharing class CreateRemainingScheduleBatch implements Database.Batchable<SObject>, Database.Stateful {
    // this batch generates new schedules for the selected loan, based on repaying the full 'migrated outstanding capital'

    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Number_of_Instalments__c, Repayment_Frequency__c, Repayment_Frequency_Unit__c, Amount__c,
                Number_of_Grace_Periods__c, Grace_Period_Type__c, Capitalized_Amount__c, Capitalized_Fee_Amount__c,
                Setup_Fee_Charging_Method__c, Setup_Fee_Expected__c, Disbursement_Date__c, First_Repayment_Date__c,
                Open_Ended_Loan__c, Interest_Rate__c, Day_Count_Convention__c, Variable_Interest_Spread__c,
                Loan_Product__r.Interest_Rate_Source__c, Loan_Product__r.Interest_Reference_Rate__c, Loan_Product__c,
                Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c, 
                Non_Working_Days_Rescheduling__c, Monitoring_Fee_Percentage__c, Migrated_Instalment_Amount__c, 
                Migrated_Next_First_Repayment_Date__c, Migrated_Outstanding_Capital__c, Migrated_Remaining_Grace_Periods__c
            FROM Investment__c
            WHERE Create_Remaining_Schedule__c = TRUE AND Open_Ended_Loan__c = FALSE
        ]);
    }

    global void execute(Database.BatchableContext BC, List<Investment__c> scope) {
        // System.debug(scope[0]);
        Investment__c theLoan = scope[0];

        Savepoint sp = Database.setSavepoint();
        String errorMessage;
        try {
            // generate schedule
            List<Repayment_Schedule__c> rsToInsert = CreateRemainingScheduleBatch.createRepaymentSchedules(theLoan);
            try {
                DMLManager.insertAsUser(rsToInsert);
                
                // create a loan event
                Loan_Event__c le = new Loan_Event__c(
                    Event_Date__c = System.today(),
                    Investment__c = theLoan.Id,
                    Loan_Event_Type__c = 'Automatic Schedule Migration for Migrated Loan',
                    Loan_Product__c = theLoan.Loan_Product__c
                );
                
                try {
                    DMLManager.insertAsUser(new List<Loan_Event__c>{le});
                } catch(System.DmlException e) {
                    Database.rollback(sp);
                    errorMessage = System.Label.sfims.part_of_error_message_32 + ': ' + e.getDmlMessage(0);
                }
            } catch(System.DmlException e) {
                errorMessage = System.Label.sfims.part_of_error_message_33 + ': ' + e.getDmlMessage(0);
            }
        } catch(Exception e) {
            errorMessage = System.Label.sfims.part_of_error_message_34 + ': ' + e.getMessage();
        }
        
        // update the loan
        Investment__c inv = [
            SELECT Create_Remaining_Schedule__c, Errors_Creating_Remaining_Schedule__c
            FROM Investment__c
            WHERE Id = :theLoan.Id
        ];
        if (errorMessage != null) inv.Errors_Creating_Remaining_Schedule__c = errorMessage.abbreviate(255);
        inv.Create_Remaining_Schedule__c = false;
    
        DMLManager.updateAsSystem(new List<Investment__c>{inv});
    }

    global void finish(Database.BatchableContext BC) {

    }

    public static List<Repayment_Schedule__c> createRepaymentSchedules(Investment__c theLoan) {
        System.debug('CreateRemainingScheduleBatch.createRepaymentSchedules');

        // apply migrated parameters to the loan
        theLoan.Capitalized_Amount__c = theLoan.Migrated_Outstanding_Capital__c;

        Integer numberOfGracePeriods = 0;
        if (theLoan.Migrated_Remaining_Grace_Periods__c != null)  numberOfGracePeriods = theLoan.Migrated_Remaining_Grace_Periods__c.intValue();
        theLoan.Number_of_Grace_Periods__c = numberOfGracePeriods;
        
        // calculate the number of instalments based on migrated outstanding capital and migrated instalment amount
        Integer numberOfInstalments = Math.floor(theLoan.Migrated_Outstanding_Capital__c / theLoan.Migrated_Instalment_Amount__c).intValue() + 1;
        numberOfInstalments += numberOfGracePeriods;
        theLoan.Number_of_Instalments__c = numberOfInstalments;

        // determine so-called disbursement date
        theLoan.First_Repayment_Date__c = theLoan.Migrated_Next_First_Repayment_Date__c;
        Date startDate;
        switch on theLoan.Repayment_Frequency_Unit__c {
            when 'Days' {
                startDate = theLoan.First_Repayment_Date__c.addDays((-1*theLoan.Repayment_Frequency__c).intValue());
            }
            when 'Weeks' {
                startDate = theLoan.First_Repayment_Date__c.addDays((7*-1*theLoan.Repayment_Frequency__c).intValue());  
            }
            when 'Months' {
                startDate = theLoan.First_Repayment_Date__c.addMonths((-1*theLoan.Repayment_Frequency__c).intValue());
            }
            when 'Years' {
                startDate = theLoan.First_Repayment_Date__c.addYears((-1*theLoan.Repayment_Frequency__c).intValue());
            }
        }
        theLoan.Disbursement_Date__c = startDate;

        // generate future schedules
        return LoanScheduler.generateSchedule(theLoan, 0, 0, theLoan.Migrated_Instalment_Amount__c);   
    }
}