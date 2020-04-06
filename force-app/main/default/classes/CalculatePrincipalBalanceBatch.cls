public without sharing class CalculatePrincipalBalanceBatch implements Database.Batchable<SObject>, Database.Stateful {

    public class CustomException extends Exception {
    }

    public Set<Id> loanIds;
    public CalculatePrincipalBalanceBatch(Set<Id> loanIds) {
        this.loanIds = loanIds;
    }
    Map<Id, List<Transaction__c>> loanIdToDisbursements = new Map<Id, List<Transaction__c>>();
    Map<Id, List<Transaction__c>> loanIdToRepayments = new Map<Id, List<Transaction__c>>();


    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
                SELECT Name, Transaction_Date__c, Amount__c, Migration__c, Type__c, Investment__c,
                        Late_Repayment_Fee_Amount__c, Interest_Amount__c, Principal_Amount__c, Fee_Amount__c,
                        Created_Using_The_Disburse_Button__c, Repayment_Allocation_Order__c
                FROM Transaction__c
                WHERE sfims__Investment__c IN :loanIds AND
                ((Type__c = 'Repayment' AND Status__c = 'Received') OR (Type__c = 'Disbursement' AND Status__c = 'Disbursed'))
                ORDER BY Transaction_Date__c, CreatedDate
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Transaction__c> scope) {
        for (Transaction__c tr : scope) {
            switch on tr.Type__c {
                when 'Disbursement' {
                    tr.Created_Using_The_Disburse_Button__c = true;
                    if (!loanIdToDisbursements.containsKey(tr.sfims__Investment__c)) {
                        loanIdToDisbursements.put(tr.sfims__Investment__c, new List<Transaction__c>());
                    }
                    loanIdToDisbursements.get(tr.sfims__Investment__c).add(tr);
                }
                when 'Repayment' {
                   // if (!tr.Migration__c) {
                        /*
                        tr.Late_Repayment_Fee_Amount__c = 0;
                        tr.Principal_Amount__c = 0;
                        tr.Fee_Amount__c = 0;
                        tr.Interest_Amount__c = 0;*/
                        if (!loanIdToRepayments.containsKey(tr.sfims__Investment__c)) {
                            loanIdToRepayments.put(tr.sfims__Investment__c, new List<Transaction__c>());
                        }
                        loanIdToRepayments.get(tr.sfims__Investment__c).add(tr);
                    //}
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        List<Investment__c> investments = [
                SELECT Late_Repayment_Calculation_Method__c, Setup_Fee_Charging_Method__c, (
                        SELECT Id, Name, Loan__c, Start_Date__c, Due_Date__c, Migration__c, Fees_Expected__c, Fees_Paid__c, Fees_Written_Off__c,
                                Interest_Expected0__c, Interest_Expected_On_Last_Paid_Date__c, Interest_Paid__c, Interest_Written_Off__c,
                                Late_Repayment_Fees_On_Last_Paid_Date__c, Late_Repayment_Fees_Paid__c, Late_Repayment_Fees_Written_Off__c,
                                Late_Repayment_Fixed_Fee__c, Due_Date_with_Tolerance_Period__c, Cancel_Late_Repayment_Fee__c, Last_Action_Date__c,
                                Principal_Expected__c, Principal_Paid__c, Principal_Written_Off__c
                        FROM Repayment_Schedules__r
                        ORDER BY Due_Date__c, CreatedDate
                )
                FROM Investment__c
                WHERE Id IN:loanIds
        ];
        Map<Id, List<Repayment_Schedule__c>> loanIdToSchedules = new Map<Id, List<Repayment_Schedule__c>>();
        for (Investment__c thisLoan : investments) {
            Id key = thisLoan.Id;
            if (!thisLoan.Repayment_Schedules__r.isEmpty()) {
                for (Repayment_Schedule__c initSched : thisLoan.Repayment_Schedules__r) {
                    if (!initSched.Migration__c) {
                        /*
                        initSched.Interest_Paid__c = 0;
                        initSched.Interest_Bonus__c = 0;
                        initSched.Fees_Paid__c = 0;
                        initSched.Principal_Paid__c = 0;
                        initSched.Last_Paid_Date__c = null;
                        initSched.Repaid_Date__c = null;
                        initSched.Late_Repayment_Fees_Paid__c = 0;
                        */
                        switch on thisLoan.Late_Repayment_Calculation_Method__c {
                            when 'Principal', 'Principal+Interest' {
                                initSched.Late_Repayment_Fees_On_Last_Paid_Date__c = 0;
                            }
                        }
                        if (initSched.Fees_Written_Off__c == null) initSched.Fees_Written_Off__c = 0;
                        if (initSched.Interest_Written_Off__c == null) initSched.Interest_Written_Off__c = 0;
                        if (initSched.Principal_Written_Off__c == null) initSched.Principal_Written_Off__c = 0;
                        if (initSched.Late_Repayment_Fees_Written_Off__c == null) initSched.Late_Repayment_Fees_Written_Off__c = 0;

                        if (!loanIdToSchedules.containsKey(key)) {
                            loanIdToSchedules.put(key, new List<Repayment_Schedule__c>());
                        }
                        loanIdToSchedules.get(key).add(initSched);
                    }
                }
            }
        }
        //List to hold schedule for update
        List<Repayment_Schedule__c> repaymentSchedulesToUpdate = new List <Repayment_Schedule__c>();
        //List to hold transactions for update
        List<Transaction__c> transactionsToUpdate = new List <Transaction__c>();

        for (Investment__c thisLoan : investments) {
            Id key = thisLoan.Id;
            List<Repayment_Schedule__c> schedules = new List<Repayment_Schedule__c>();
            if (loanIdToSchedules.containsKey(key)) {
                schedules = loanIdToSchedules.get(key);
            }
            // populate the Principal Balance
            Decimal principalBalance = 0;
            Integer currentDisbursement = 0;
            List<Transaction__c> disbursements = new List<Transaction__c>();
            if (loanIdToDisbursements.containsKey(key)) {
                disbursements = loanIdToDisbursements.get(key);
            }
            // if there are no disbursements for the loan, get Loan Amount as the initial amount of the Principal Balance
            if (disbursements.isEmpty()) {
                Decimal capitalizedAmount = 0;
                Decimal capitalizedFeeAmount = 0;
                if (thisLoan.Capitalized_Amount__c != null) capitalizedAmount = thisLoan.Capitalized_Amount__c;
                if (thisLoan.Capitalized_Fee_Amount__c != null) capitalizedFeeAmount = thisLoan.Capitalized_Fee_Amount__c;
                principalBalance = capitalizedAmount - capitalizedFeeAmount;
            }

            // Principal Balance is equal to Principal Expected - Principal Paid - Principal Written Off
            // calculate for transactions
            // Map<Id, Transaction__c> repaymentIdToRepayment = new Map<Id, Transaction__c>();
            if (loanIdToRepayments.containsKey(key)) {
                //  repaymentIdToRepayment = new Map<Id, Transaction__c>(loanIdToRepayments.get(key));
            }

            if (thisLoan.Setup_Fee_Charging_Method__c == 'Deducted From Principal') {
                principalBalance += thisLoan.Setup_Fee_Expected__c;
            }

            Decimal principalBalanceForTransactions = principalBalance;
            Integer currentSchedule = 0;

            if (loanIdToDisbursements.containsKey(key)) {
                for (Transaction__c tr : loanIdToDisbursements.get(key)) {
                    // increase by the disbursement Amount (Principal Expected)
                    principalBalanceForTransactions += tr.Amount__c;
                    tr.Principal_Balance__c = principalBalanceForTransactions;
                    transactionsToUpdate.add(tr);
                }
            }

            if (loanIdToRepayments.containsKey(key)) {
                for (Transaction__c tr : loanIdToRepayments.get(key)) {
                    // if (!tr.Migration__c) tr = repaymentIdToRepayment.get(tr.Id);

                    // minus Principal Written Off
                    for (Integer i = currentSchedule; i < schedules.size(); i++) {
                        Repayment_Schedule__c schedule = schedules[i];
                        if (tr.Transaction_Date__c <= schedule.Due_Date__c) {
                            if (schedule.Principal_Written_Off__c != null) principalBalanceForTransactions -= schedule.Principal_Written_Off__c;
                            currentSchedule++;
                        } else {
                            i = schedules.size();
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
            }

            // calculate for repayment schedules
            Map<Id, Repayment_Schedule__c> scheduleIdToSchedule = new Map<Id, Repayment_Schedule__c>();
            if (loanIdToSchedules.containsKey(key)) {
                scheduleIdToSchedule = new Map<Id, Repayment_Schedule__c>(loanIdToSchedules.get(key));
                // System.debug(scheduleIdToSchedule.size());
            }

            currentDisbursement = 0;
            List<Repayment_Schedule__c> schedulesForBalance = thisLoan.Repayment_Schedules__r;
            // System.debug(schedulesForBalance.size());
            for (Integer i = 0; i < schedulesForBalance.size(); i++) {
                // System.debug(i);
                Repayment_Schedule__c schedule = new Repayment_Schedule__c();
                if (schedulesForBalance[i].Migration__c) {
                    schedule = schedulesForBalance[i];
                } else {
                    schedule = scheduleIdToSchedule.get(schedulesForBalance[i].Id);
                }
                // System.debug(schedule);
                // increase by the disbursement Amount (Principal Expected)
                for (Integer j = currentDisbursement; j < disbursements.size(); j++) {
                    Transaction__c disb = disbursements[j];
                    if (disb.Transaction_Date__c <= schedule.Due_Date__c) {
                        principalBalance += disb.Amount__c;
                        currentDisbursement++;
                    } else {
                        j = disbursements.size();
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
        }

        Savepoint sp = Database.setSavepoint();
        try {
            if (!transactionsToUpdate.isEmpty()) {
                System.debug('transactionsToUpdate');
                System.debug(transactionsToUpdate);
                // we need to use updateAsSystem because we are writing to fields that normal users don't have access to (they should not be able to modify the fields themselves directly)
                TransactionTriggerHandler.bypassProcessTransactions = true;
                DMLManager.updateAsSystem(transactionsToUpdate);
                TransactionTriggerHandler.bypassProcessTransactions = false;
            }

            // we need to use updateAsSystem because we are writing to fields that normal users don't have access to (they should not be able to modify the fields themselves directly)
            // system.debug(repaymentSchedulesToUpdate.size());
            // system.debug(repaymentSchedulesToUpdate);
            System.debug('repaymentSchedulesToUpdate');
            System.debug(repaymentSchedulesToUpdate);
            DMLManager.updateAsSystem(repaymentSchedulesToUpdate);
        } catch (Exception e) {
            // rollback and re-throw exception so that it can be handled
            Database.rollback(sp);
            System.debug('processing error: ' + e.getMessage());
            throw new CustomException(e.getMessage());
        }
    }
}