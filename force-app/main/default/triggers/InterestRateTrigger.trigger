trigger InterestRateTrigger on Interest_Rate__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        createNewLoanEvents();
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        createNewLoanEvents();
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        recalculateLoans();
    }

    public void createNewLoanEvents() {
        System.debug('InterestRateTrigger');
        // gather loan data 
        Map<Id, List<Interest_Rate__c>> interestRateSourceIdToInterestRates = new Map<Id, List<Interest_Rate__c>>();
        for (Interest_Rate__c temp : Trigger.new) {
            // System.debug(temp.Date__c);
            if (temp.Date__c < System.today()) {
                if (!interestRateSourceIdToInterestRates.containsKey(temp.Interest_Rate_Source__c)) {
                    interestRateSourceIdToInterestRates.put(temp.Interest_Rate_Source__c, new List<Interest_Rate__c>());
                }
                interestRateSourceIdToInterestRates.get(temp.Interest_Rate_Source__c).add(temp);
            }
        }

        Map<Id, List<Investment__c>> interestRateSourceIdToLoans = new Map<Id, List<Investment__c>>();
        for (Investment__c inv : [SELECT Open_Ended_Loan__c, Recalculation_Status__c, Loan_Product__c, 
            Loan_Product__r.Interest_Reference_Rate__c, Loan_Product__r.Interest_Rate_Review_Frequency__c, 
            Disbursement_Date__c, Expected_End_Date__c, (SELECT Start_Date__c, Due_Date__c FROM Repayment_Schedules__r 
            WHERE Active__c = true AND Migration__c = false AND Status__c != 'Fee' ORDER BY Start_Date__c ASC, Name DESC LIMIT 1),
            (SELECT Event_Date__c FROM Loan_Events__r WHERE Loan_Event_Type__c = 'Interest Rate Change' ORDER BY Event_Date__c) 
            FROM Investment__c WHERE Status__c = 'Active' AND Loan_Product__r.Interest_Rate_Source__c = 'Variable Interest'
            AND Loan_Product__r.Interest_Reference_Rate__c IN :interestRateSourceIdToInterestRates.keySet()])
        {
            if (!interestRateSourceIdToLoans.containsKey(inv.Loan_Product__r.Interest_Reference_Rate__c)) {
                interestRateSourceIdToLoans.put(inv.Loan_Product__r.Interest_Reference_Rate__c, new List<Investment__c>());
            }
            interestRateSourceIdToLoans.get(inv.Loan_Product__r.Interest_Reference_Rate__c).add(inv);
        }

        if (!interestRateSourceIdToLoans.isEmpty()) {
            List<Investment__c> loansToUpdate = new List<Investment__c>();
            List<Loan_Event__c> newLoanEvents = new List<Loan_Event__c>();
            for (Id key : interestRateSourceIdToLoans.keySet()) {
                List<Investment__c> loans = interestRateSourceIdToLoans.get(key);
                List<Interest_Rate__c> interestRates = interestRateSourceIdToInterestRates.get(key);
                for (Investment__c theLoan : loans) {
                    if (!theLoan.Repayment_Schedules__r.isEmpty()) {
                        Date startDate = theLoan.Repayment_Schedules__r[0].Start_Date__c == null ?
                            theLoan.Disbursement_Date__c : theLoan.Repayment_Schedules__r[0].Start_Date__c;

                        Map<String, List<SObject>> resultMap = TriggerHelper.processInterestRates(theLoan, startDate, interestRates);
                        if (resultMap.containsKey('loans')) loansToUpdate.addAll((List<Investment__c>)resultMap.get('loans'));
                        if (resultMap.containsKey('loanEvents')) newLoanEvents.addAll((List<Loan_Event__c>)resultMap.get('loanEvents'));
                    }
                }
            }
            // System.debug(newLoanEvents.size());
            if (!newLoanEvents.isEmpty()) insert newLoanEvents;
            if (!loansToUpdate.isEmpty() && !Test.isRunningTest()) {
                updateLoansAndRunRecalculation(loansToUpdate, Trigger.new);
            }
        }
    }

    public void recalculateLoans(){
        Map<Id, List<Investment__c>> interestRateSourceIdToLoans = new Map<Id, List<Investment__c>>();
        for (Interest_Rate__c temp : Trigger.old) {
            if (!interestRateSourceIdToLoans.containsKey(temp.Interest_Rate_Source__c)) {
                interestRateSourceIdToLoans.put(temp.Interest_Rate_Source__c, new List<Investment__c>());
            }
        }

        if (!interestRateSourceIdToLoans.isEmpty()) {
            for (Investment__c inv : [SELECT Open_Ended_Loan__c, Recalculation_Status__c, Loan_Product__r.Interest_Reference_Rate__c,
                (SELECT Event_Date__c FROM Loan_Events__r WHERE Loan_Event_Type__c = 'Interest Rate Change' ORDER BY Event_Date__c DESC LIMIT 1)
                FROM Investment__c WHERE Loan_Product__r.Interest_Rate_Source__c = 'Variable Interest'
                AND Loan_Product__r.Interest_Reference_Rate__c IN :interestRateSourceIdToLoans.keySet()])
            {
                interestRateSourceIdToLoans.get(inv.Loan_Product__r.Interest_Reference_Rate__c).add(inv);
            }
        }

        List<Investment__c> loansToUpdate = new List<Investment__c>();
        for (Interest_Rate__c temp : Trigger.old) {
            if (temp.Interest_Rate_Source__c != null) {
                for (Investment__c inv : interestRateSourceIdToLoans.get(temp.Interest_Rate_Source__c)) {
                    if (!inv.Loan_Events__r.isEmpty()) {
                        if (inv.Loan_Events__r[0].Event_Date__c > temp.Date__c) {
                            inv.Recalculation_Status__c = 'Pending Recalculation';
                            loansToUpdate.add(inv);
                        }
                    }
                }
            }
        }

        updateLoansAndRunRecalculation(loansToUpdate, Trigger.old);
    }

    public void updateLoansAndRunRecalculation(List<Investment__c> loansToUpdate, List<Interest_Rate__c> interestRates) {
        String result = TriggerHelper.runRecalculateLoanFromScratch(loansToUpdate);
        if (result != null) {
            for (Interest_Rate__c temp : interestRates) {
                temp.addError(result);
            }
        }
    }

}