global with sharing class LoanHealthCheckBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    Map<Id, Investment__c> loanIdToLoan = new Map<Id, Investment__c>();
    Map<Id, List<String>> loanIdToIssues = new Map<Id, List<String>>();
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Investment__c
            WHERE Status__c = 'Active'
        ]);
    }

    global void execute(Database.BatchableContext BC, List<Investment__c> scope) {
        System.debug(scope);
        Investment__c theLoan = [
            SELECT Principal_Remaining__c, Open_Ended_Loan__c, Interest_Expected_Open_Ended_Loan__c, 
                Late_Repayment_Fees_Expected0__c, Health_Check_Fails__c, Health_Check_Failures__c,
                Recalculation_Status__c, Status__c,
            (
                SELECT Fees_Paid__c, Interest_Paid__c, Late_Repayment_Fees_Paid__c, Principal_Paid__c, 
                    Interest_Expected_Open_Ended_Loan__c, Late_Repayment_Fees_Expected0__c, 
                    Expected_Principal_Balance__c, Principal_Balance__c, Due_Date__c, Active__c
                FROM Repayment_Schedules__r
                ORDER BY Due_Date__c DESC
            ),
            (
                SELECT Fee_Amount__c, Interest_Amount__c, Late_Repayment_Fee_Amount__c, Principal_Amount__c,
                    Transaction_Date__c, Type__c, Status__c, Principal_Balance__c
                FROM Transactions__r
                ORDER BY Transaction_Date__c DESC
            )
            FROM Investment__c
            WHERE Id = :scope[0].Id
        ];
        
        loanIdToLoan.put(theLoan.Id, theLoan);
        loanIdToIssues.put(theLoan.Id, LoanHealthCheckController.getIssues(theLoan));
    }

    global void finish(Database.BatchableContext BC) {
        List<Investment__c> loansToUpdate = new List<Investment__c>();
        for (Id key : loanIdToIssues.keySet()) {
            List<String> issues = loanIdToIssues.get(key);
            Investment__c theLoan = loanIdToLoan.get(key);
            if (!issues.isEmpty()) {
                theLoan.Health_Check_Fails__c = true;
                theLoan.Health_Check_Failures__c = String.join(issues, ' ').abbreviate(255);
                loansToUpdate.add(theLoan);
            }
            if (theLoan.Health_Check_Fails__c && issues.isEmpty()) {
                theLoan.Health_Check_Fails__c = false;
                theLoan.Health_Check_Failures__c = null;
                loansToUpdate.add(theLoan);
            }
        }

        if (!loansToUpdate.isEmpty()) update loansToUpdate;
    }

}