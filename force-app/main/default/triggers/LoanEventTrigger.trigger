trigger LoanEventTrigger on Loan_Event__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
    if (Utility.bypassLoanEventTrigger) return;

    if (Trigger.isBefore && Trigger.isInsert) {
        generateLoanEventName();
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        generateLoanEventName();
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        updateRepaymentSchedules();
    }

    if (Trigger.isDelete && Utility.executeFromDeleteMethodOfInvestmentTrigger) return;
    if (Trigger.isBefore && Trigger.isDelete) {
        runValidations();
        collectTransactions();
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        deleteTransactions();
        recalculateLoans();
    }

    public void generateLoanEventName(){                   
        for (Loan_Event__c temp : Trigger.new) {
            temp.Name = temp.Loan_Event_Type__c + ' - ' + temp.Event_Date__c.format();       
        }
    }

    public void runValidations(){                   
        Map<Id, Set<Id>> loanIdToLoanEventIds = new Map<Id, Set<Id>>();
        Set<Id> allLoanIds = new Set<Id>();       
        for (Loan_Event__c temp : Trigger.old) {
            if (temp.Investment__c != null) {
                if (!allLoanIds.contains(temp.Investment__c)) allLoanIds.add(temp.Investment__c);
                switch on temp.Loan_Event_Type__c {
                    when 'Reschedule', 'Disbursement', 'Refinance' {
                        if (!loanIdToLoanEventIds.containsKey(temp.Investment__c)) {
                            loanIdToLoanEventIds.put(temp.Investment__c, new Set<Id>());
                        }     
                        loanIdToLoanEventIds.get(temp.Investment__c).add(temp.Id);
                    }
                }
            }       
        }
        // System.debug(loanIdToLoanEventIds.size());
        Boolean failed = false;
        List<Investment__c> loansToRecalculate = new List<Investment__c>();
        for (Investment__c theLoan : [SELECT Id, Recalculation_Status__c, Open_Ended_Loan__c, 
            (SELECT Id FROM Loan_Events__r WHERE Loan_Event_Type__c IN ('Reschedule', 'Disbursement', 'Refinance') 
            ORDER BY Event_Date__c DESC, CreatedDate DESC) FROM Investment__c WHERE Id IN :loanIdToLoanEventIds.keySet()]) 
        {
            Set<Id> loanEventIds = new Set<Id>();
            for (Integer i = 0; i < loanIdToLoanEventIds.get(theLoan.Id).size(); i++) {
                loanEventIds.add(theLoan.Loan_Events__r[i].Id);
            }
            if (loanEventIds != loanIdToLoanEventIds.get(theLoan.Id)) {
                for (Id loanEventId :loanIdToLoanEventIds.get(theLoan.Id)) {
                    Trigger.oldMap.get(loanEventId).addError(System.Label.sfims.error_message_44);   
                }
                failed = true;
                break;
            } 
            theLoan.Recalculation_Status__c = 'Pending Recalculation';
            loansToRecalculate.add(theLoan);
        }
        // System.debug(failed);

        if (!failed) {
            for (Investment__c theLoan : [SELECT Id, Recalculation_Status__c, Open_Ended_Loan__c FROM Investment__c 
                WHERE Id IN :allLoanIds AND Id NOT IN :loanIdToLoanEventIds.keySet()]) 
            {
                theLoan.Recalculation_Status__c = 'Pending Recalculation';
                loansToRecalculate.add(theLoan);
            }
            Utility.loansToRecalculate = loansToRecalculate;
        }
        // System.debug(Utility.loansToRecalculate);
    }

    public void collectTransactions(){                       
        Utility.transactionsToDelete = [
            SELECT Id 
            FROM Transaction__c 
            WHERE Loan_Event__c IN :Trigger.oldMap.keySet()
        ];
        
    }

    public void deleteTransactions(){                   
        List<Transaction__c> transactionsToDelete = Utility.transactionsToDelete;
        if (!transactionsToDelete.isEmpty()) delete transactionsToDelete;
    }

    public void recalculateLoans(){                   
        // System.debug(Utility.loansToRecalculate);
        String result = TriggerHelper.runRecalculateLoanFromScratch(Utility.loansToRecalculate); 
        if (result != null) {
            for (Loan_Event__c temp : Trigger.old) {
                temp.addError(result);
            }
        }
    }

    public void updateRepaymentSchedules(){                   
        System.debug('-----updateRepaymentSchedules-----');
        Set<Id> loanEventIds = new Set<Id>();
        Set<Id> loanIds = new Set<Id>();
        for (Loan_Event__c le : Trigger.new) {
            // check if status has changed
            if (le.Loan_Event_Type__c == 'Fee Cancelled' && le.Approval_Status__c != Trigger.oldMap.get(le.Id).Approval_Status__c
                && (le.Approval_Status__c == 'Approved' || le.Approval_Status__c == 'No Approval Required'))
            {
                loanEventIds.add(le.Id);
                loanIds.add(le.Investment__c);
            }
        }
        System.debug(loanEventIds.size());
        if (!loanEventIds.isEmpty()) {
            Map<Id, List<Repayment_Schedule__c>> loanIdToRepaymentSchedules = new Map<Id, List<Repayment_Schedule__c>>();
            for (Repayment_Schedule__c rs : [SELECT Due_Date__c, Cancel_Late_Repayment_Fee__c, Loan__c
                FROM Repayment_Schedule__c WHERE Loan__c IN :loanIds AND Due_Date__c < TODAY])
            {
                System.debug(rs);
                if (!loanIdToRepaymentSchedules.containsKey(rs.Loan__c)) 
                    loanIdToRepaymentSchedules.put(rs.Loan__c, new List<Repayment_Schedule__c>());
                
                loanIdToRepaymentSchedules.get(rs.Loan__c).add(rs);
            }
            System.debug(loanIdToRepaymentSchedules.size());
            List<Repayment_Schedule__c> rsToUpdate = new List<Repayment_Schedule__c>();
            for (Loan_Event_Detail__c led : [SELECT Due_Date__c, Cancel_Late_Repayment_Fee__c, Loan_Event__r.Investment__c
                FROM Loan_Event_Detail__c WHERE Loan_Event__c IN :loanEventIds])
            {
                if (loanIdToRepaymentSchedules.containsKey(led.Loan_Event__r.Investment__c)) {
                    for (Repayment_Schedule__c rs : loanIdToRepaymentSchedules.get(led.Loan_Event__r.Investment__c)) {
                        if (rs.Due_Date__c == led.Due_Date__c) {
                            rs.Cancel_Late_Repayment_Fee__c = led.Cancel_Late_Repayment_Fee__c;
                            rsToUpdate.add(rs);
                            break;
                        }
                    }
                }
            }

            if (!rsToUpdate.isEmpty()) {
                System.debug('-----update rs-----');
                update rsToUpdate;
            }
        }
    }

}