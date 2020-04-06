public with sharing class PopulateLoanExpectedAmountBatch implements Database.Batchable<sObject>, Database.Stateful {
    // this batch populates the Late Repayment Fees Expected amount for standard loans
    // and the Interest Expected amount for open ended loans on the Investment object
    // it's an alternative to roll-up summary fields that we cannot use due to the function TODAY
    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Open_Ended_Loan__c, Late_Repayment_Fees_Expected0__c, Interest_Expected_Open_Ended_Loan__c,
            (
                SELECT Late_Repayment_Fees_Expected0__c, Interest_Expected_Open_Ended_Loan__c
                FROM Repayment_Schedules__r
                WHERE Active__c = true 
                AND ((Due_Date_with_Tolerance_Period__c = null AND Days_Since_Last_Paid_Date__c > 0) OR Due_Date_with_Tolerance_Period__c < TODAY)
            )
            FROM Investment__c
            WHERE Status__c = 'Active'
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Investment__c> scope) {
        System.debug(scope);
        List<Investment__c> investmentsToUpdate = new List<Investment__c>(); 
        for (Investment__c i : scope) {
            if (!i.Repayment_Schedules__r.isEmpty()) {
                if (i.Open_Ended_Loan__c) {
                    i.Interest_Expected_Open_Ended_Loan__c = i.Repayment_Schedules__r[0].Interest_Expected_Open_Ended_Loan__c;
                    investmentsToUpdate.add(i);
                } else {
                    Decimal lateRepaymentFeesExpected = 0;
                    for (Repayment_Schedule__c rs : i.Repayment_Schedules__r) {
                        if (rs.Late_Repayment_Fees_Expected0__c != null) lateRepaymentFeesExpected += rs.Late_Repayment_Fees_Expected0__c;
                    } 
                    i.Late_Repayment_Fees_Expected0__c = lateRepaymentFeesExpected;
                    investmentsToUpdate.add(i);
                }
            }
        }
        System.debug(investmentsToUpdate);
        if (!investmentsToUpdate.isEmpty()) {
            update investmentsToUpdate;
        }
    }

    public void finish(Database.BatchableContext BC) {

    }

}