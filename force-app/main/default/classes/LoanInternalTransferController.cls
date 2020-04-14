public without sharing class LoanInternalTransferController {

    public class CommonException extends Exception {
    }

    @AuraEnabled
    public static void createTransferTransactions(Double amount, Date transactionDate, Id fromLoanId, Id toLoanId, Map<String, Object> dataMap) {
        try {
            // validations
            if (fromLoanId == null || toLoanId == null || amount == null || transactionDate == null) {
                throw new CommonException('Required parameters are not correct.');
            }
            Map<Id, Investment__c> investments = new Map<Id, Investment__c>([SELECT sfims__Available_Disbursement_Amount__c,sfims__Status__c,sfims__Principal_Remaining__c FROM Investment__c WHERE RecordType.Name = 'Loan' AND (Id = :fromLoanId OR Id = :toLoanId)]);
            if (investments.size() != 2 ||
                    !investments.containsKey(fromLoanId) ||
                    !investments.containsKey(toLoanId) ||
                    investments.get(fromLoanId).sfims__Available_Disbursement_Amount__c <= 0 ||
                    investments.get(toLoanId).sfims__Status__c != 'Active' ||
                    investments.get(toLoanId).sfims__Principal_Remaining__c <= 0) {
                throw new CommonException('Required parameters are invalid.');
            }
            if (amount > investments.get(toLoanId).sfims__Principal_Remaining__c) {
                throw new CommonException('Amount cannot be more ' + investments.get(toLoanId).sfims__Principal_Remaining__c);
            }
            // END validations

            List<Transaction__c> internalTransferTransactions = new List<Transaction__c>();
            // for From Loan
            internalTransferTransactions.add(new Transaction__c (
                    Type__c = 'Disbursement',
                    Status__c = 'Disbursed',
                    Transaction_Date__c = transactionDate,
                    Amount__c = amount,
                    Investment__c = fromLoanId
                    // Allow_To_Disburse_Loan_From_Trigger__c = true
            ));
            // for To Loan
            internalTransferTransactions.add(new Transaction__c (
                    Type__c = 'Repayment',
                    Status__c = 'Received',
                    Transaction_Date__c = transactionDate,
                    Amount__c = amount,
                    Investment__c = toLoanId
            ));
            insert internalTransferTransactions;
        } catch (Exception err) {
            throw new CommonException(err.getMessage());
        }
    }
}