public with sharing class PopulateLateRepaymentFixedFeeBatch implements Database.Batchable<sObject>, Database.Stateful {
    // this batch populates the Late Repayment Fixed Fees on the Repayment Shedule records for standard loans
    public Database.QueryLocator start(Database.BatchableContext BC) {
        Date entryDate = System.today();
        return Database.getQueryLocator([
            SELECT Late_Repayment_Fixed_Fee__c, Loan__r.Late_Repayment_Fixed_Fee__c
            FROM Repayment_Schedule__c
            WHERE Loan__r.Status__c = 'Active' AND Loan__r.Open_Ended_Loan__c = FALSE AND Active__c = TRUE 
                AND Loan__r.Late_Repayment_Calculation_Method__c = 'Fixed Fee' AND Late_Repayment_Fixed_Fee__c = NULL
                AND Due_Date_with_Tolerance_Period__c < :entryDate AND Total_Remaining__c > 0
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Repayment_Schedule__c> scope) {
        System.debug(scope);
        List<Repayment_Schedule__c> rsToUpdate = new List<Repayment_Schedule__c>(); 
        for (Repayment_Schedule__c rs : scope) { 
            rs.Late_Repayment_Fixed_Fee__c = rs.Loan__r.Late_Repayment_Fixed_Fee__c;
            rsToUpdate.add(rs);  
        }
        System.debug(rsToUpdate);
        if (!rsToUpdate.isEmpty()) {
            update rsToUpdate;
        }
    }

    public void finish(Database.BatchableContext BC) {

    }

}