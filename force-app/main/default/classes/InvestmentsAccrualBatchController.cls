public with sharing class InvestmentsAccrualBatchController implements Database.Batchable<sObject>, Database.Stateful {

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id, Principal_Expected__c, Interest_Expected0__c, Fees_Expected__c, Late_Repayment_Fees_Expected0__c, Principal_Due__c,
                Interest_Due__c, Fees_Due__c, Late_Repayment_Fees_Due__c, Status__c
            FROM Repayment_Schedule__c
            WHERE Loan__r.Status__c = 'Active' AND Due_Date__c < TODAY AND Total_Due__c = 0
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Repayment_Schedule__c> scope) {

        for (Repayment_Schedule__c rs : scope){
            
            rs.Principal_Due__c = rs.Principal_Expected__c;
            rs.Interest_Due__c = rs.Interest_Expected0__c;
            rs.Fees_Due__c = rs.Fees_Expected__c;
            rs.Late_Repayment_Fees_Due__c = rs.Late_Repayment_Fees_Expected0__c;

        }
        
        update scope;
        
    }

    public void finish(Database.BatchableContext BC) {

    }

}