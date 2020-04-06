public with sharing class RecalculationScheduler implements Schedulable, Database.Stateful {
    String loanId;
    
    public RecalculationScheduler(String loanId) {
        this.loanId = loanId;
    }
    public void execute(SchedulableContext sc) {
        Investment__c theLoan = [
            SELECT Open_Ended_Loan__c, Recalculation_Status__c 
            FROM Investment__c 
            WHERE Id = :loanId
        ];

        if (theLoan.Recalculation_Status__c == 'Manual Recalculation') {
            theLoan.Recalculation_Status__c = 'Pending Recalculation';

            String result = TriggerHelper.runRecalculateLoanFromScratch(new List<Investment__c>{theLoan});
            if (result != null) RecalculateButtonController.finishWithError(theLoan, null, result);
        }
    }
}