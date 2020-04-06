/**
 * @description         This is the trigger handler for the Transaction__c sObject. 
 * @author              Guy Clairbois
 */
public with sharing class TransactionTriggerHandler {

    public static Boolean bypassProcessTransactions = false;

    /**
     * @description         Automatically create/update 1 or more Transaction__c based on the VF_Transaction__c
     */
    public void processTransactions(Map<Id,Transaction__c> newTransactionsMap, Map<Id,Transaction__c> oldTransactionsMap){
        if (TransactionTriggerHandler.bypassProcessTransactions) return;

        // we do an entire loan recalculation when a transaction changes, because it's nearly impossible to predict which schedules will be hit and which not
        // collect the loan ids
        Set<Id> loanIds = new Set<Id>();

        // handle the delete scenario (just make sure the calculation is retriggered)
        if(newTransactionsMap == null) newTransactionsMap = oldTransactionsMap;
        
        for(Transaction__c t : newTransactionsMap.values()){
            if((t.Type__c == 'Repayment' || t.Type__c == 'Disbursement') && t.Investment__c != null && !transactionsInRecalculation.contains(t.Id)){
                loanIds.add(t.Investment__c);
                transactionsInRecalculation.add(t.Id);
            }
        }
        Set<Id> standardLoanIds = new Set<Id>();
        List<Investment__c> openEndedLoans = new List<Investment__c>();
        if (!loanIds.isEmpty()) {
            for (Investment__c theLoan : [SELECT Open_Ended_Loan__c, Recalculation_Status__c FROM Investment__c WHERE Id IN :loanIds]) {
                if (theLoan.Open_Ended_Loan__c) openEndedLoans.add(theLoan);
                else standardLoanIds.add(theLoan.Id);
            }
        }
        if (openEndedLoans.size() == 1) {
            Map<String, String> resultMap = RecalculateOpenEndedLoan.processOpenEndedLoan(openEndedLoans[0].Id);
            if (resultMap.containsKey('error')) {
                
                for (Transaction__c temp : newTransactionsMap.values()) {
                    temp.addError(System.Label.sfims.part_of_error_message_7 + ': ' + resultMap.get('error'));
                }
            }
        } else if (openEndedLoans.size() > 1) {
            for (Investment__c inv : openEndedLoans) {
                inv.Recalculation_Status__c = 'Pending Recalculation';
            }    
                
            String result = TriggerHelper.runRecalculateLoanFromScratch(openEndedLoans); 
            if (result != null) {
                for (Transaction__c temp : newTransactionsMap.values()) {
                    temp.addError(result);
                }
            }
        }

        if(!standardLoanIds.isEmpty()) LoanTransactionProcessor.processLoanTransactions(standardLoanIds);
    }

    public static Set<Id> transactionsInRecalculation {
        get{
            if(transactionsInRecalculation == null) transactionsInRecalculation = new Set<Id>();
            return transactionsInRecalculation;
         }
        set;
    }

}