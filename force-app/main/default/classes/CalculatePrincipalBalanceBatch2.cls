public without sharing class CalculatePrincipalBalanceBatch2 implements Database.Batchable<SObject>, Database.Stateful {

    public class CustomException extends Exception {
    }

    public Set<Id> loanIds;
    public CalculatePrincipalBalanceBatch2(Set<Id> loanIds) {
        this.loanIds = loanIds;
    }

    List<Transaction__c> transactionsToUpdate = new List <Transaction__c>();
    List<Repayment_Schedule__c> repaymentSchedulesToUpdate = new List <Repayment_Schedule__c>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
                SELECT Id, Amount__c, Interest_Rate__c, Late_Repayment_Calculation_Method__c, Late_Repayment_Interest_Rate__c,
                        Disbursement_Date__c, Open_Ended_Loan__c, Late_Repayment_Fees_Expected0__c, Interest_Expected_Open_Ended_Loan__c,
                        Capitalized_Amount__c, Capitalized_Fee_Amount__c, Disbursement_Method__c, Variable_Interest_Spread__c,
                        Setup_Fee_Charging_Method__c, Setup_Fee__c, Setup_Fee_Expected__c, Loan_Product__c, Late_Repayment_Fixed_Fee__c,
                        Loan_Product__r.Interest_Rate_Review_Frequency__c, Loan_Product__r.Interest_Reference_Rate__c,
                        Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c,
                        Loan_Product__r.Default_Interest_Rate__c, Loan_Product__r.Interest_Rate_Source__c,
                        Loan_Product__r.Repayment_Allocation_Type__c, Loan_Product__r.Repayment_Allocation_Order__c
                FROM Investment__c
                WHERE Id IN:loanIds
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Investment__c> scope) {
        List<Transaction__c> disbursements = new List<Transaction__c>();
        List<Transaction__c> repayments = new List<Transaction__c>();
        for (Investment__c thisLoan : scope) {
            Id key = thisLoan.Id;
            for (Transaction__c tr : [
                    SELECT Name, Transaction_Date__c, Amount__c, Migration__c, Type__c, Investment__c,
                            Late_Repayment_Fee_Amount__c, Interest_Amount__c, Principal_Amount__c, Fee_Amount__c,
                            Created_Using_The_Disburse_Button__c, Repayment_Allocation_Order__c
                    FROM Transaction__c
                    WHERE Investment__c = :key AND ((Type__c = 'Repayment' AND Status__c = 'Received') OR (Type__c = 'Disbursement' AND Status__c = 'Disbursed'))
                    ORDER BY Transaction_Date__c, CreatedDate
            ]) {
                switch on tr.Type__c {
                    when 'Disbursement' {
                        tr.Created_Using_The_Disburse_Button__c = true;
                        disbursements.add(tr);
                    }
                    when 'Repayment' {
                        /*
                        tr.Late_Repayment_Fee_Amount__c = 0;
                        tr.Principal_Amount__c = 0;
                        tr.Fee_Amount__c = 0;
                        tr.Interest_Amount__c = 0;*/
                        repayments.add(tr);
                    }
                }
            }
            List<Repayment_Schedule__c> schedules = [
                    SELECT Id, Name, Loan__c, Start_Date__c, Due_Date__c, Migration__c, Fees_Expected__c, Fees_Paid__c, Fees_Written_Off__c,
                            Interest_Expected0__c, Interest_Expected_On_Last_Paid_Date__c, Interest_Paid__c, Interest_Written_Off__c,
                            Late_Repayment_Fees_On_Last_Paid_Date__c, Late_Repayment_Fees_Paid__c, Late_Repayment_Fees_Written_Off__c,
                            Late_Repayment_Fixed_Fee__c, Due_Date_with_Tolerance_Period__c, Cancel_Late_Repayment_Fee__c, Last_Action_Date__c,
                            Principal_Expected__c, Principal_Paid__c, Principal_Written_Off__c
                    FROM Repayment_Schedule__c
                    WHERE Loan__c = :key
                    ORDER BY Due_Date__c, CreatedDate
            ];

            for (Repayment_Schedule__c schedule : schedules) {
                /*
                schedule.Interest_Paid__c = 0;
                schedule.Interest_Bonus__c = 0;
                schedule.Fees_Paid__c = 0;
                schedule.Principal_Paid__c = 0;
                schedule.Last_Paid_Date__c = null;
                schedule.Repaid_Date__c = null;
                schedule.Late_Repayment_Fees_Paid__c = 0;
                */
                switch on thisLoan.Late_Repayment_Calculation_Method__c {
                    when 'Principal', 'Principal+Interest' {
                        schedule.Late_Repayment_Fees_On_Last_Paid_Date__c = 0;
                    }
                }
                if (schedule.Fees_Written_Off__c == null) schedule.Fees_Written_Off__c = 0;
                if (schedule.Interest_Written_Off__c == null) schedule.Interest_Written_Off__c = 0;
                if (schedule.Principal_Written_Off__c == null) schedule.Principal_Written_Off__c = 0;
                if (schedule.Late_Repayment_Fees_Written_Off__c == null) schedule.Late_Repayment_Fees_Written_Off__c = 0;
            }


            // populate the Principal Balance
            Decimal principalBalance = 0;

            // if there are no disbursements for the loan, get Loan Amount as the initial amount of the Principal Balance
            if (disbursements.isEmpty()) {
                Decimal capitalizedAmount = 0;
                Decimal capitalizedFeeAmount = 0;
                if (thisLoan.Capitalized_Amount__c != null) capitalizedAmount = thisLoan.Capitalized_Amount__c;
                if (thisLoan.Capitalized_Fee_Amount__c != null) capitalizedFeeAmount = thisLoan.Capitalized_Fee_Amount__c;
                principalBalance = capitalizedAmount - capitalizedFeeAmount;
            }

            // Principal Balance is equal to Principal Expected - Principal Paid - Principal Written Off

            if (thisLoan.Setup_Fee_Charging_Method__c == 'Deducted From Principal') {
                principalBalance += thisLoan.Setup_Fee_Expected__c;
            }

            Decimal principalBalanceForTransactions = principalBalance;
            Integer currentSchedule = 0;

            for (Transaction__c tr : disbursements) {
                // increase by the disbursement Amount (Principal Expected)
                principalBalanceForTransactions += tr.Amount__c;
                tr.Principal_Balance__c = principalBalanceForTransactions;
                transactionsToUpdate.add(tr);
            }

            for (Transaction__c tr : repayments) {
                // minus Principal Written Off
                for (Integer i = 0; i < schedules.size(); i++) {
                    Repayment_Schedule__c schedule = schedules[i];
                    if (tr.Transaction_Date__c <= schedule.Due_Date__c) {
                        if (schedule.Principal_Written_Off__c != null) principalBalanceForTransactions -= schedule.Principal_Written_Off__c;
                        currentSchedule++;
                    } else {
                        break;
                    }
                }
                // minus Principal Paid
                if (tr.Principal_Amount__c != null) {

                    if (principalBalanceForTransactions < tr.Principal_Amount__c) {
                        // overpayment should not be reflected in principal balance
                        principalBalanceForTransactions = 0;
                    } else {
                        principalBalanceForTransactions -= tr.Principal_Amount__c;
                    }
                }
                tr.Principal_Balance__c = principalBalanceForTransactions;
                transactionsToUpdate.add(tr);
            }

            // calculate for repayment schedules
            //   Map<Id, Repayment_Schedule__c> scheduleIdToSchedule = new Map<Id, Repayment_Schedule__c>(schedules);

            // currentDisbursement = 0;
            Integer currentDisbursement = 0;
            List<Repayment_Schedule__c> schedulesForBalance = schedules;
            // System.debug(schedulesForBalance.size());
            for (Integer i = 0; i < schedulesForBalance.size(); i++) {
                // System.debug(i);
                Repayment_Schedule__c schedule = new Repayment_Schedule__c();
                //  if (schedulesForBalance[i].Migration__c) {
                schedule = schedulesForBalance[i];
                //  } else {
                //      schedule = scheduleIdToSchedule.get(schedulesForBalance[i].Id);
                // }
                // System.debug(schedule);
                // increase by the disbursement Amount (Principal Expected)
                for (Integer j = 0; j < disbursements.size(); j++) {
                    Transaction__c disbursement = disbursements[j];
                    if (disbursement.Transaction_Date__c <= schedule.Due_Date__c) {
                        principalBalance += disbursement.Amount__c;
                        currentDisbursement++;
                    } else {
                        break;
                    }
                }
                // minus Principal Written Off
                if (schedule.Principal_Written_Off__c != null) principalBalance -= schedule.Principal_Written_Off__c;
                // minus Principal Paid
                if (i == schedulesForBalance.size() - 1) {
                    if (schedule.Principal_Paid__c != null) {
                        if (principalBalance < schedule.Principal_Paid__c) {
                            // overpayment should not be reflected in principal balance
                            principalBalance = 0;
                        } else {
                            principalBalance -= schedule.Principal_Paid__c;
                        }
                    }
                } else {
                    if (schedule.Principal_Paid__c != null) principalBalance -= schedule.Principal_Paid__c;
                }
                schedule.Principal_Balance__c = principalBalance;
                repaymentSchedulesToUpdate.add(schedule);
            }
            break;
        }
    }

    public void finish(Database.BatchableContext bc) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (!transactionsToUpdate.isEmpty()) {
                System.debug('transactionsToUpdate');
                for (Transaction__c tr : transactionsToUpdate) {
                    System.debug('START ' + tr.Name);
                    System.debug(tr.Transaction_Date__c);
                    System.debug(tr.Amount__c);
                    System.debug(tr.Migration__c);
                    System.debug(tr.Type__c);
                    System.debug(tr.Investment__c);

                    System.debug(tr.Late_Repayment_Fee_Amount__c);
                    System.debug(tr.Interest_Amount__c);
                    System.debug(tr.Principal_Amount__c);
                    System.debug(tr.Fee_Amount__c);
                }

                // we need to use updateAsSystem because we are writing to fields that normal users don't have access to (they should not be able to modify the fields themselves directly)
                TransactionTriggerHandler.bypassProcessTransactions = true;
                 DMLManager.updateAsSystem(transactionsToUpdate);
                TransactionTriggerHandler.bypassProcessTransactions = false;
            }

            // we need to use updateAsSystem because we are writing to fields that normal users don't have access to (they should not be able to modify the fields themselves directly)
            // system.debug(repaymentSchedulesToUpdate.size());
            // system.debug(repaymentSchedulesToUpdate);
            System.debug('repaymentSchedulesToUpdate');
            for (Repayment_Schedule__c rs : repaymentSchedulesToUpdate) {
                System.debug('START ' + rs.Name);
                System.debug(rs.Loan__c);
                System.debug(rs.Start_Date__c);
                System.debug(rs.Due_Date__c);
                System.debug(rs.Migration__c);
                System.debug(rs.Fees_Expected__c);

                System.debug(rs.Fees_Paid__c);
                System.debug(rs.Fees_Written_Off__c);
                System.debug(rs.Interest_Expected0__c);
                System.debug(rs.Interest_Expected_On_Last_Paid_Date__c);

                System.debug(rs.Interest_Paid__c);
                System.debug(rs.Interest_Written_Off__c);
                System.debug(rs.Late_Repayment_Fees_On_Last_Paid_Date__c);
                System.debug(rs.Late_Repayment_Fees_Paid__c);
                System.debug(rs.Late_Repayment_Fees_Written_Off__c);
                System.debug(rs.Late_Repayment_Fixed_Fee__c);
                System.debug(rs.Due_Date_with_Tolerance_Period__c);
                System.debug(rs.Cancel_Late_Repayment_Fee__c);
                System.debug(rs.Last_Action_Date__c);
                System.debug(rs.Principal_Expected__c);
                System.debug(rs.Principal_Paid__c);
                System.debug(rs.Principal_Written_Off__c);
            }
            DMLManager.updateAsSystem(repaymentSchedulesToUpdate);
        } catch (Exception e) {
            // rollback and re-throw exception so that it can be handled
            Database.rollback(sp);
            System.debug('Processing error: ' + e.getMessage());
            throw new CustomException(e.getMessage());
        }
    }
}