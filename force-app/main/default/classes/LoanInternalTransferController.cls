public without sharing class LoanInternalTransferController {

    public class CommonException extends Exception {
    }

    @AuraEnabled
    public static void createTransferTransactions(Double amount, Date transactionDate, Id fromLoanId, Id toLoanId) {
        try {
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