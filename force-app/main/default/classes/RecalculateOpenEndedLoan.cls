public with sharing class RecalculateOpenEndedLoan implements Database.Batchable<sObject>, Database.Stateful {

    public Datetime startBatchTime;
    public Map<Id, Investment__c> loanIdToLoan = new Map<Id, Investment__c>();
    public Map<Id, String> loanIdToErrorMessage = new Map<Id, String>();

    public RecalculateOpenEndedLoan() {
        this.startBatchTime = System.now();

        Map<Id, Investment__c> loansToUpdateStatus = new Map<Id, Investment__c>();
        for (Investment__c inv : [SELECT Status__c, Recalculation_Status__c, Last_Recalculation_Date__c, Recalculation_Error_Message__c,
            (SELECT Id FROM Loan_Events__r WHERE Loan_Event_Type__c = 'Disbursement') 
            FROM Investment__c WHERE Open_Ended_Loan__c = true AND Recalculation_Status__c = 'Pending Recalculation'])
        {
            if (inv.Loan_Events__r.isEmpty()) {
                inv.Status__c = 'Inactive';
                inv.Recalculation_Status__c = 'Not Needed';
                inv.Last_Recalculation_Date__c = null;
                inv.Recalculation_Error_Message__c = null;
                loansToUpdateStatus.put(inv.Id, inv);
            }
        }
        if (!loansToUpdateStatus.isEmpty()) {
            DMLManager.updateAsUser(loansToUpdateStatus.values());
            DMLManager.deleteAsUser([SELECT Id FROM Repayment_Schedule__c WHERE Loan__c IN :loansToUpdateStatus.keySet() AND Migration__c = false]);
            DMLManager.deleteAsUser([SELECT Id FROM Loan_Event__c WHERE Investment__c IN :loansToUpdateStatus.keySet() AND Loan_Event_Type__c != 'Loan Creation']);
        }
        
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Amount__c, Interest_Rate__c, Disbursement_Date__c, Capitalized_Amount__c, Capitalized_Fee_Amount__c,
                Interest_Expected_Open_Ended_Loan__c, Disbursement_Method__c, Variable_Interest_Spread__c, Status__c, 
                Loan_Product__r.Interest_Rate_Review_Frequency__c, Loan_Product__r.Interest_Reference_Rate__c,
                Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c, 
                Loan_Product__r.Default_Interest_Rate__c, Loan_Product__r.Interest_Rate_Source__c, Loan_Product__c,
                Loan_Product__r.Repayment_Allocation_Order__c, Recalculation_Status__c, Last_Recalculation_Date__c, Recalculation_Error_Message__c, 
                (
                    SELECT Migration__c, Fees_Expected__c, Fees_Paid__c, Fees_Written_Off__c, Interest_Expected0__c, 
                        Interest_Expected_On_Last_Paid_Date__c, Interest_Paid__c, Interest_Written_Off__c,
                        Principal_Expected__c, Principal_Paid__c, Principal_Written_Off__c, Last_Paid_Date__c,
                        Last_Action_Date__c, Principal_Balance__c
                    FROM Repayment_Schedules__r  
                ),
                (
                    SELECT Transaction_Date__c, Amount__c, Migration__c, Type__c, Investment__c, Interest_Amount__c,
                        Principal_Amount__c, Fee_Amount__c, Created_Using_The_Disburse_Button__c, Repayment_Allocation_Order__c 
                    FROM Transactions__r 
                    WHERE (Type__c = 'Repayment' AND Status__c = 'Received') OR (Type__c = 'Disbursement' AND Status__c = 'Disbursed')
                    ORDER BY Transaction_Date__c
                ),
                (
                    SELECT Event_Date__c
                    FROM Loan_Events__r
                    WHERE Loan_Event_Type__c = 'Interest Rate Change'
                    ORDER BY Event_Date__c DESC
                )
            FROM Investment__c 
            WHERE Recalculation_Status__c = 'Pending Recalculation' AND Open_Ended_Loan__c = true
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Investment__c> scope) {
        TransactionTriggerHandler.bypassProcessTransactions = true;
        
        Investment__c theLoan = scope[0];
        switch on theLoan.Recalculation_Status__c {
            when 'Manual Recalculation' {
                return;
            }
            when 'Done', 'Failed' {
                if (theLoan.Last_Recalculation_Date__c > startBatchTime) return;
            }
        }
        
        loanIdToLoan.put(theLoan.Id, theLoan);
        
        theLoan.Recalculation_Status__c = 'In Progress';
        if (theLoan.Status__c != 'Active') theLoan.Status__c = 'Active';
        if (theLoan.Recalculation_Error_Message__c != null) theLoan.Recalculation_Error_Message__c = null;
        
        try { 
            DMLManager.updateAsSystem(new List<Investment__c>{theLoan});
        } catch(System.DmlException e) {
            System.debug(e.getDmlMessage(0));
            loanIdToErrorMessage.put(theLoan.Id, System.Label.sfims.part_of_error_message_6 + ': ' + e.getDmlMessage(0));
            return;
        }
            
        try {
            Map<String, String> resultMap = RecalculateOpenEndedLoan.processOpenEndedLoan(theLoan);
            if (resultMap.containsKey('error')) loanIdToErrorMessage.put(theLoan.Id, resultMap.get('error'));
        } catch(Exception e) {
            System.debug(e.getMessage());
            loanIdToErrorMessage.put(theLoan.Id, System.Label.sfims.part_of_error_message_5 + ': ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext BC) {
        List<Investment__c> loansToUpdateStatus = new List<Investment__c>();
        for (Investment__c inv : [SELECT Recalculation_Status__c, Last_Recalculation_Date__c, Recalculation_Error_Message__c 
            FROM Investment__c WHERE Id IN :loanIdToLoan.keySet() AND Recalculation_Status__c = 'In Progress'])
        {
            if (!loanIdToErrorMessage.containsKey(inv.Id)) {
                inv.Recalculation_Status__c = 'Done';
            } else {
                inv.Recalculation_Status__c = 'Failed';
                inv.Recalculation_Error_Message__c = loanIdToErrorMessage.get(inv.Id); 
            }
            inv.Last_Recalculation_Date__c = System.now();
            loansToUpdateStatus.add(inv);
        }
        DMLManager.updateAsSystem(loansToUpdateStatus);
        
        List<Investment__c> loansToRecalculate = [
            SELECT Id
            FROM Investment__c
            WHERE Recalculation_Status__c = 'Pending Recalculation' AND Open_Ended_Loan__c = true
        ];

        if (!loansToRecalculate.isEmpty()) Database.executeBatch(new RecalculateOpenEndedLoan(), 1);   
    }

    public static Map<String, String> processOpenEndedLoan(String loanId) {
        Investment__c theLoan = [
            SELECT Amount__c, Interest_Rate__c, Disbursement_Date__c, Capitalized_Amount__c, Capitalized_Fee_Amount__c,
                Interest_Expected_Open_Ended_Loan__c, Disbursement_Method__c, Variable_Interest_Spread__c, Loan_Product__c, 
                Loan_Product__r.Interest_Rate_Review_Frequency__c, Loan_Product__r.Interest_Reference_Rate__c,
                Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c, 
                Loan_Product__r.Default_Interest_Rate__c, Loan_Product__r.Interest_Rate_Source__c, 
                Loan_Product__r.Repayment_Allocation_Order__c, Open_Ended_Loan__c, Setup_Fee_Charging_Method__c,
                (
                    SELECT Migration__c, Fees_Expected__c, Fees_Paid__c, Fees_Written_Off__c, Interest_Expected0__c, 
                        Interest_Expected_On_Last_Paid_Date__c, Interest_Paid__c, Interest_Written_Off__c,
                        Principal_Expected__c, Principal_Paid__c, Principal_Written_Off__c, Last_Paid_Date__c,
                        Last_Action_Date__c, Principal_Balance__c, Interest_Rate__c
                    FROM Repayment_Schedules__r  
                ),
                (
                    SELECT Transaction_Date__c, Amount__c, Migration__c, Type__c, Investment__c, Interest_Amount__c, Fee_Amount__c,
                        Principal_Amount__c, Repayment_Allocation_Order__c, Created_Using_The_Disburse_Button__c, Name  
                    FROM Transactions__r 
                    WHERE (Type__c = 'Repayment' AND Status__c = 'Received') OR (Type__c = 'Disbursement' AND Status__c = 'Disbursed')
                    ORDER BY Transaction_Date__c
                ),
                (
                    SELECT Event_Date__c
                    FROM Loan_Events__r
                    WHERE Loan_Event_Type__c = 'Interest Rate Change'
                    ORDER BY Event_Date__c DESC
                )
            FROM Investment__c 
            WHERE Id = :loanId AND Open_Ended_Loan__c = true
        ];
        return RecalculateOpenEndedLoan.processOpenEndedLoan(theLoan);
    }

    public static Map<String, String> processOpenEndedLoan(Investment__c theLoan) {
        Map<String, String> resultMap = new Map<String, String>();
        Repayment_Schedule__c schedule = new Repayment_Schedule__c();
        
        if (!theLoan.Transactions__r.isEmpty()){
            for (Transaction__c tr : theLoan.Transactions__r){
                if (tr.Type__c == 'Repayment' && !tr.Migration__c) {
                    tr.Principal_Amount__c = 0;
                    tr.Fee_Amount__c = 0;
                    tr.Interest_Amount__c = 0;
                } 
            }
        }
        if(!theLoan.Repayment_Schedules__r.isEmpty()){
            schedule = theLoan.Repayment_Schedules__r[0];
    
            schedule.Interest_Paid__c = 0;
            schedule.Fees_Paid__c = 0;
            schedule.Principal_Paid__c = 0;
            schedule.Last_Paid_Date__c = null;
            schedule.Last_Action_Date__c = null;
            schedule.Repaid_Date__c = null;
            schedule.Interest_Expected_On_Last_Paid_Date__c = 0;
            schedule.Fees_Written_Off__c = 0;
            schedule.Interest_Written_Off__c = 0;
            schedule.Principal_Written_Off__c = 0;
            
        } else {
            schedule = LoanScheduler.generateSchedule(theLoan)[0];
        }

        // get interest rates if the loan is related to the loan product with Variable Interest Rate 
        List<Interest_Rate__c> interestRates = new List<Interest_Rate__c>();
        if (theLoan.Loan_Product__r.Interest_Rate_Source__c == 'Variable Interest' 
            && theLoan.Loan_Product__r.Interest_Reference_Rate__c != null
            && !theLoan.Loan_Events__r.isEmpty()) 
        {
            interestRates = [
                SELECT Date__c, Rate__c
                FROM Interest_Rate__c
                WHERE Interest_Rate_Source__c = :theLoan.Loan_Product__r.Interest_Reference_Rate__c 
                    AND Date__c <= :theLoan.Loan_Events__r[0].Event_Date__c
                ORDER BY Date__c
            ];

            // logic for the deletion of the Loan Events if they are no longer relevant after the deletion of interest rates           
            List<Loan_Event__c> loanEventsToDelete = new List<Loan_Event__c>();
            Date startDate = theLoan.Disbursement_Date__c;
            Integer currentRate = 0;
            for (Integer i = theLoan.Loan_Events__r.size() - 1; i >= 0; i--) {
                System.debug(i);
                Loan_Event__c le = theLoan.Loan_Events__r[i];
                System.debug(le.Event_Date__c);
                Integer interestRatesForThisLoanEvent = 0;
                for (Integer j = currentRate; j < interestRates.size(); j++) {
                    Interest_Rate__c ir = interestRates[j];
                    System.debug(ir.Date__c);
                    if (ir.Date__c < le.Event_Date__c) {
                        currentRate++;
                        if (ir.Date__c >= startDate) {
                            interestRatesForThisLoanEvent++;
                        }
                    } else {
                        j = interestRates.size();
                    } 
                }

                if (interestRatesForThisLoanEvent == 0) loanEventsToDelete.add(le);

                startDate = le.Event_Date__c;
            }
            
            if (!loanEventsToDelete.isEmpty()) {
                Utility.bypassLoanEventTrigger = true;
                DMLManager.deleteAsSystem(loanEventsToDelete);
                Utility.bypassLoanEventTrigger = false;
            }
            // ----------------------------------------------------------------------------------------------------------------
        }
    
        Integer currentRate = 0;
        Decimal principalExpected = theLoan.Amount__c;
        
        // calculate Interest Expected, Principal Expected, Interest Paid and Principal Paid amounts 
        if (!theLoan.Transactions__r.isEmpty()) {
            List<Transaction__c> transactions = theLoan.Transactions__r;
        
            // process transactions
            List<Transaction__c> transactionsToUpdate = new List<Transaction__c>();
            for (Integer i = 0; i < transactions.size(); i++) {
                Transaction__c tr = transactions[i];
                
                if (i == 0) {
                    switch on tr.Type__c {
                        when 'Disbursement' {
                            schedule.Principal_Expected__c = tr.Amount__c;
                            schedule.Principal_Balance__c = schedule.Principal_Expected__c;
                            schedule.Last_Action_Date__c = tr.Transaction_Date__c;
                            continue;    
                        }
                        when 'Repayment' {
                            resultMap.put('error', System.Label.sfims.error_message_31);
                            break;
                        }
                    }
                }
                
                // calculate Interest Expected for different types of interest rate source
                if (!interestRates.isEmpty()) {//Variable Interest
                    schedule = RecalculateOpenEndedLoan.calculateVariableInterestRate(theLoan, schedule, interestRates, currentRate, tr.Transaction_Date__c);
                } else {//Fixed Interest
                    Integer days = schedule.Last_Action_Date__c.daysBetween(tr.Transaction_Date__c);   
                    Decimal principalRemaining = schedule.Principal_Expected__c - schedule.Principal_Paid__c;
                    if (theLoan.Interest_Rate__c == null) theLoan.Interest_Rate__c = 0;
                    Decimal interestExpected = (days * ((theLoan.Interest_Rate__c/365)/100) * principalRemaining).setScale(2);
                    schedule.Interest_Expected_On_Last_Paid_Date__c += interestExpected;
                    schedule.Last_Action_Date__c = tr.Transaction_Date__c;
                }
                
                switch on tr.Type__c {
                    when 'Disbursement' {
                        schedule.Principal_Expected__c += tr.Amount__c;
                        schedule.Principal_Balance__c = schedule.Principal_Expected__c - schedule.Principal_Paid__c;
                    }
                    when 'Repayment' {
                        Decimal amountToAllocate = tr.Amount__c;
                        String allocationOrder = String.isBlank(tr.Repayment_Allocation_Order__c) ?
                            theLoan.Loan_Product__r.Repayment_Allocation_Order__c :
                            tr.Repayment_Allocation_Order__c;
                        for (String amount : allocationOrder.split(';')) {
                            Decimal amountRemaining = 0;
                            Decimal amountPaid = 0;
                            
                            switch on amount {
                                when 'Fees' {
                                    amountRemaining = schedule.Fees_Expected__c - schedule.Fees_Paid__c;
                                }
                                when 'Interest' {
                                    amountRemaining = schedule.Interest_Expected_On_Last_Paid_Date__c - schedule.Interest_Paid__c;
                                }
                                when 'Principal' {
                                    amountRemaining = schedule.Principal_Expected__c - schedule.Principal_Paid__c;
                                }
                            }
                             
                            if (amountRemaining > 0 && amountToAllocate > 0) {
                                if (amountToAllocate > amountRemaining) {
                                    amountPaid = amountRemaining;
                                } else {
                                    amountPaid = amountToAllocate;
                                }
                                
                                switch on amount {
                                    when 'Fees' {
                                        schedule.Fees_Paid__c += amountPaid;
                                        tr.Fee_Amount__c += amountPaid;
                                    }
                                    when 'Interest' {
                                        schedule.Interest_Paid__c += amountPaid;
                                        tr.Interest_Amount__c += amountPaid;
                                    }
                                    when 'Principal' {
                                        schedule.Principal_Paid__c += amountPaid;
                                        schedule.Principal_Balance__c = schedule.Principal_Expected__c - schedule.Principal_Paid__c;
                                        tr.Principal_Amount__c += amountPaid;
                                    }
                                }
                              
                                if (schedule.Last_Paid_Date__c != tr.Transaction_Date__c) 
                                    schedule.Last_Paid_Date__c = tr.Transaction_Date__c;

                                amountToAllocate -= amountPaid;
                                
                            }

                            if (amountToAllocate <= 0) break;
                        } 
                        transactionsToUpdate.add(tr); 
                    }
                }  
            }
            
            if (!interestRates.isEmpty() && !theLoan.Loan_Events__r.isEmpty()) {
                List<Loan_Event__c> loanEvents = theLoan.Loan_Events__r;
                
                for (Integer i = 0; i < loanEvents.size(); i++) {
                    Loan_Event__c le = loanEvents[i];
                    if (le.Event_Date__c <= schedule.Last_Action_Date__c) {
                        continue;
                    }

                    schedule = RecalculateOpenEndedLoan.calculateVariableInterestRate(theLoan, schedule, interestRates, currentRate, le.Event_Date__c);
                }    
            }
            

            Savepoint sp = Database.setSavepoint();
            try {   
                
                DMLManager.upsertAsSystem(new List<Repayment_Schedule__c>{schedule});
                DMLManager.updateAsSystem(transactionsToUpdate);
                
                // perform Nightly batch to populate Interest Expected for open ended loans on the Investment level
                Investment__c inv = [
                    SELECT Interest_Expected_Open_Ended_Loan__c, 
                    (
                        SELECT Interest_Expected_Open_Ended_Loan__c 
                        FROM Repayment_Schedules__r
                    ) 
                    FROM Investment__c 
                    WHERE Id =: theLoan.Id
                ];
                inv.Interest_Expected_Open_Ended_Loan__c = inv.Repayment_Schedules__r[0].Interest_Expected_Open_Ended_Loan__c;
                DMLManager.updateAsSystem(new List<Investment__c>{inv});
                
            } catch(Exception e) {
                // rollback and re-throw exception so that it can be handled
                Database.rollback(sp);
                system.debug('processing error: '+e.getMessage());
                resultMap.put('error', e.getMessage());
            }
        } 
        
        return resultMap;
    }

    public static Repayment_Schedule__c calculateVariableInterestRate(Investment__c theLoan, Repayment_Schedule__c schedule, List<Interest_Rate__c> interestRates, Integer currentRate, Date entryDate) {
        Date startInterestRateDate = schedule.Last_Action_Date__c == null ? theLoan.Disbursement_Date__c : schedule.Last_Action_Date__c;
        Decimal interestRateOnStartDate = interestRates[0].Rate__c;
        Double expression = 0;
        
        for (Integer j=currentRate; j<interestRates.size(); j++) {
            Interest_Rate__c rate = interestRates[j];
            if (rate.Date__c <= schedule.Last_Action_Date__c) {
                currentRate++;
                continue;
            }

            if (rate.Date__c < entryDate) {
                interestRateOnStartDate = interestRates[currentRate-1].Rate__c;
                expression += interestRateOnStartDate * startInterestRateDate.daysBetween(rate.Date__c);
                startInterestRateDate = rate.Date__c;
                currentRate++; 
            }
        }
        interestRateOnStartDate = interestRates[currentRate-1].Rate__c;
        expression += interestRateOnStartDate * startInterestRateDate.daysBetween(entryDate);
        System.debug(expression);

        Integer days = schedule.Last_Action_Date__c.daysBetween(entryDate);   
        Decimal interestRate = RecalculateOpenEndedLoan.checkVariableInterestRateRange(theLoan, expression / days);
        Decimal principalRemaining = schedule.Principal_Expected__c - schedule.Principal_Paid__c;
        Decimal interestExpected = (days * ((interestRate/365)/100) * principalRemaining).setScale(2);
        schedule.Interest_Expected_On_Last_Paid_Date__c += interestExpected;
        schedule.Last_Action_Date__c = entryDate;
        
        interestRateOnStartDate = RecalculateOpenEndedLoan.checkVariableInterestRateRange(theLoan, interestRateOnStartDate);
        schedule.Interest_Rate__c = interestRateOnStartDate;

        return schedule;
    }

    public static Decimal checkVariableInterestRateRange(Investment__c theLoan, Decimal interestRate) {
        if (theLoan.Variable_Interest_Spread__c != null) interestRate += theLoan.Variable_Interest_Spread__c;
        if (theLoan.Loan_Product__r.Maximum_Interest_Bandwidth__c != null 
            && interestRate > theLoan.Loan_Product__r.Maximum_Interest_Bandwidth__c) 
            interestRate = theLoan.Loan_Product__r.Maximum_Interest_Bandwidth__c;
        if (theLoan.Loan_Product__r.Minimum_Interest_Bandwidth__c != null 
            && interestRate < theLoan.Loan_Product__r.Minimum_Interest_Bandwidth__c) 
            interestRate = theLoan.Loan_Product__r.Minimum_Interest_Bandwidth__c;
        
        return interestRate;
    }

}