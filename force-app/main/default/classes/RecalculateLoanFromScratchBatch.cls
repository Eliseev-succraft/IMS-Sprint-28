public with sharing class RecalculateLoanFromScratchBatch implements Database.Batchable<sObject>, Database.Stateful {
    // this batch recalculates a standard loan from scratch based on the loan events related to this loan

    public Datetime startBatchTime;
    public Map<Id, Investment__c> loanIdToLoan = new Map<Id, Investment__c>();
    public Map<Id, Integer> loanIdToDisbursementIndex = new Map<Id, Integer>();
    public Map<Id, Date> loanIdToEventDate = new Map<Id, Date>();
    public Map<Id, String> loanIdToErrorMessage = new Map<Id, String>();
    public Set<Id> manuallyRecalculatedLoans = new Set<Id>();
    public List<Loan_Event__c> loanEventsToDelete = new List<Loan_Event__c>();
    Map<Id, Investment__c> loansToUpdateStatus = new Map<Id, Investment__c>();

    public RecalculateLoanFromScratchBatch() {
        this.startBatchTime = System.now();

        Map<Id, Investment__c> loansToUpdateStatus = new Map<Id, Investment__c>();
        for (Investment__c inv : [SELECT Recalculation_Status__c, Last_Recalculation_Date__c, Recalculation_Error_Message__c,
            Last_Instalment_Amount__c, (SELECT Id FROM Loan_Events__r WHERE Loan_Event_Type__c = 'Disbursement') 
            FROM Investment__c WHERE Open_Ended_Loan__c = false AND Recalculation_Status__c = 'Pending Recalculation'])
        {
            if (inv.Loan_Events__r.isEmpty()) {
                inv.Recalculation_Status__c = 'Not Needed';
                if (inv.Last_Recalculation_Date__c != null) inv.Last_Recalculation_Date__c = null;
                if (inv.Recalculation_Error_Message__c != null) inv.Recalculation_Error_Message__c = null;
                inv.Last_Instalment_Amount__c = null;
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
            SELECT Loan_Event_Type__c, Event_Date__c, Investment__c, Amount__c, First_Repayment_Date__c, Number_of_Instalments__c,
                Grace_Period_Type__c, Number_of_Grace_Periods__c, Repayment_Frequency__c, Repayment_Frequency_Unit__c, Interest_Rate__c,  
                Fees_Written_Off__c, Interest_Written_Off__c, Late_Repayment_Fees_Written_Off__c, Principal_Written_Off__c,  
                Variable_Interest_Spread__c, Reschedule_Type__c, Instalment_Amount__c, Approval_Status__c, Balloon_Repayment_Period__c,
                (
                    SELECT Amount__c
                    FROM Transactions__r
                ),
                (
                    SELECT Due_Date__c, Cancel_Late_Repayment_Fee__c
                    FROM Loan_Event_Details__r
                )
            FROM Loan_Event__c
            WHERE Investment__r.Recalculation_Status__c = 'Pending Recalculation' 
                AND Investment__r.Open_Ended_Loan__c = false AND Loan_Event_Type__c != 'Loan Creation'
            ORDER BY Event_Date__c, CreatedDate
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Loan_Event__c> scope) {
        TransactionTriggerHandler.bypassProcessTransactions = true;
        System.debug(scope[0]);
        
        Loan_Event__c le = scope[0];
        
        try {
            if (manuallyRecalculatedLoans.contains(le.Investment__c)) return;
            
            // check if the loan is being recalculated manually
            Investment__c theLoan = [
                SELECT Name, Recalculation_Status__c, Last_Recalculation_Date__c 
                FROM Investment__c 
                WHERE Id = :le.Investment__c
            ];
            System.debug(theLoan.Name);
            switch on theLoan.Recalculation_Status__c {
                when 'Manual Recalculation' {
                    manuallyRecalculatedLoans.add(theLoan.Id);
                    return;
                }
                when 'Done', 'Failed' {
                    if (theLoan.Last_Recalculation_Date__c > startBatchTime) {
                        manuallyRecalculatedLoans.add(theLoan.Id);
                        return;
                    }
                }
            }
            
            if (!loanIdToLoan.containsKey(le.Investment__c)) {
                theLoan = [
                    SELECT Id, Number_of_Instalments__c, Repayment_Frequency__c, Repayment_Frequency_Unit__c, Day_Count_Convention__c,
                        Number_of_Grace_Periods__c, Grace_Period_Type__c, Amount__c, Capitalized_Amount__c, Capitalized_Fee_Amount__c, 
                        Open_Ended_Loan__c, Interest_Rate__c, Variable_Interest_Spread__c, Disbursement_Date__c, First_Repayment_Date__c, 
                        Disbursement_Method__c, Expected_End_Date__c, Setup_Fee_Charging_Method__c, Setup_Fee__c, Setup_Fee_Expected__c, 
                        Percent_of_Disbursement_Amount__c, Non_Working_Days_Rescheduling__c, Recalculation_Status__c, Recalculation_Error_Message__c,
                        Monitoring_Fee_Percentage__c, Loan_Product__r.Interest_Rate_Source__c, Loan_Product__r.Interest_Reference_Rate__c,
                        Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c,
                        Migrated_Instalment_Amount__c, Migrated_Next_First_Repayment_Date__c, 
                        Migrated_Outstanding_Capital__c, Migrated_Remaining_Grace_Periods__c
                    FROM Investment__c
                    WHERE Id = :le.Investment__c
                ];
                theLoan.Recalculation_Status__c = 'In Progress';
                if (theLoan.Recalculation_Error_Message__c != null) theLoan.Recalculation_Error_Message__c = null;
                DMLManager.updateAsSystem(new List<Investment__c>{theLoan});

                loanIdToLoan.put(theLoan.Id, theLoan);
                loanIdToDisbursementIndex.put(theLoan.Id, 0);
                loanIdToEventDate.put(theLoan.Id, null);

                DMLManager.deleteAsUser([SELECT Id FROM Repayment_Schedule__c WHERE Loan__c =: theLoan.Id AND Migration__c = false]);
            }

            if (loanIdToErrorMessage.containsKey(le.Investment__c)) return;
            
            theLoan = loanIdToLoan.get(le.Investment__c);
            Date eventDate = loanIdToEventDate.get(le.Investment__c);
            
            Map<String, String> resultMap = RecalculateLoanFromScratchBatch.processLoanEvent(theLoan, le, eventDate, loanIdToDisbursementIndex.get(le.Investment__c));
            loanIdToEventDate.put(le.Investment__c, Date.valueOf(resultMap.get('eventDate')));
            if (resultMap.containsKey('index')) loanIdToDisbursementIndex.put(le.Investment__c, Integer.valueOf(resultMap.get('index')));
            if (resultMap.containsKey('loanEventToDelete')) loanEventsToDelete.add((Loan_Event__c)JSON.deserialize(resultMap.get('loanEventToDelete'), Loan_Event__c.class));

        } catch(Exception e) {
            loanIdToErrorMessage.put(le.Investment__c, e.getMessage());
        }
    }

    public void finish(Database.BatchableContext BC) {
        Map<Id, Investment__c> loansToUpdateStatus = new Map<Id, Investment__c>();
        for (Investment__c inv : [SELECT Recalculation_Status__c, Last_Recalculation_Date__c, Recalculation_Error_Message__c, Last_Instalment_Amount__c, 
            (SELECT Instalment_Amount__c FROM Loan_Events__r WHERE Loan_Event_Type__c IN ('Disbursement', 'Reschedule', 'Refinance') 
            ORDER BY Event_Date__c DESC, CreatedDate DESC LIMIT 1) FROM Investment__c WHERE Id IN :loanIdToLoan.keySet() AND Recalculation_Status__c = 'In Progress'])
        {
            if (!loanIdToErrorMessage.containsKey(inv.Id)) {
                inv.Recalculation_Status__c = 'Done';
                if (!inv.Loan_Events__r.isEmpty()) inv.Last_Instalment_Amount__c = inv.Loan_Events__r[0].Instalment_Amount__c;
            } else {
                inv.Recalculation_Status__c = 'Failed';
                inv.Recalculation_Error_Message__c = loanIdToErrorMessage.get(inv.Id); 
            }
            inv.Last_Recalculation_Date__c = System.now();
            loansToUpdateStatus.put(inv.Id, inv);
        }
        DMLManager.updateAsUser(loansToUpdateStatus.values());
        
        if (!loanEventsToDelete.isEmpty()) {
            List<Loan_Event__c> toDelete = new List<Loan_Event__c>();
            for (Loan_Event__c le : loanEventsToDelete) {
                if (!manuallyRecalculatedLoans.contains(le.Investment__c)) toDelete.add(le);
            }
            Utility.bypassLoanEventTrigger = true;
            DMLManager.deleteAsSystem(toDelete);
            Utility.bypassLoanEventTrigger = false;
        }
        
        LoanTransactionProcessor.processLoanTransactions(loansToUpdateStatus.keySet());

        List<Investment__c> loansToRecalculate = [
            SELECT Id
            FROM Investment__c
            WHERE Recalculation_Status__c = 'Pending Recalculation' AND Open_Ended_Loan__c = false
        ];

        if (!loansToRecalculate.isEmpty()) Database.executeBatch(new RecalculateLoanFromScratchBatch(), 1);
    }

    public static Map<String, String> processLoanEvent(Investment__c theLoan, Loan_Event__c le, Date eventDate, Integer index) {
        System.debug('RecalculateLoanFromScratchBatch.processLoanEvent');
        Map<String, String> returnMap = new Map<String, String>();
        if (eventDate != null) LoanTransactionProcessor.processLoanTransactions(theLoan.Id, le.Event_Date__c);
            
        eventDate = le.Event_Date__c;
        returnMap.put('eventDate', String.valueOf(eventDate));
        // loanIdToEventDate.put(le.Investment__c, eventDate);
        
        switch on le.Loan_Event_Type__c {
            when 'Reschedule', 'Disbursement' {
                theLoan.Disbursement_Date__c = le.Event_Date__c;
                theLoan.Capitalized_Amount__c = le.Amount__c;
                theLoan.First_Repayment_Date__c = le.First_Repayment_Date__c;
                theLoan.Number_of_Instalments__c = le.Number_of_Instalments__c;
                theLoan.Repayment_Frequency__c = le.Repayment_Frequency__c;
                theLoan.Repayment_Frequency_Unit__c = le.Repayment_Frequency_Unit__c;
                switch on theLoan.Loan_Product__r.Interest_Rate_Source__c {
                    when 'Fixed Interest' {
                        theLoan.Interest_Rate__c = le.Interest_Rate__c;
                    }
                    when 'Variable Interest' {
                        theLoan.Variable_Interest_Spread__c = le.Variable_Interest_Spread__c;
                    }
                }
            }
        }

        Map<String, Object> dataMap = new Map<String, Object>();
        dataMap.put('recordId', theLoan.Id);
        dataMap.put('totalPrincipalWrittenOff', le.Principal_Written_Off__c);
        dataMap.put('totalInterestWrittenOff', le.Interest_Written_Off__c);
        dataMap.put('totalFeesWrittenOff', le.Fees_Written_Off__c);
        dataMap.put('totalPenaltiesWrittenOff', le.Late_Repayment_Fees_Written_Off__c);

        switch on le.Loan_Event_Type__c {
            when 'Reschedule' {
                System.debug('RecalculateLoanFromScratchBatch.Reschedule');
                theLoan.Grace_Period_Type__c = le.Grace_Period_Type__c;
                theLoan.Number_of_Grace_Periods__c = le.Number_of_Grace_Periods__c;

                dataMap.put('action', 'Reschedule');
                dataMap.put('selectedType', le.Reschedule_Type__c);
                dataMap.put('loan', JSON.serialize(theLoan));
                dataMap.put('rescheduleDate', le.Event_Date__c);
                if (le.Number_of_Instalments__c == null) dataMap.put('pmtValue', le.Instalment_Amount__c);

                Map<String, List<SObject>> resultMap = RescheduleLoanButtonController.processRescheduling(dataMap);
                if (resultMap.containsKey('toUpdate')) {
                    DMLManager.updateAsUser(resultMap.get('toUpdate'));
                }
                if (resultMap.containsKey('toDelete')) {
                    DMLManager.deleteAsUser(resultMap.get('toDelete'));
                }
                DMLManager.insertAsUser(resultMap.get('toInsert'));
            }
            when 'Disbursement' {
                System.debug('RecalculateLoanFromScratchBatch.Disbursement');
                Repayment_Schedule__c rsFees;
                // Integer index = loanIdToDisbursementIndex.get(le.Investment__c);
                if (index == 0) {
                    theLoan.Grace_Period_Type__c = le.Grace_Period_Type__c;
                    theLoan.Number_of_Grace_Periods__c = le.Number_of_Grace_Periods__c;
                    if (theLoan.Disbursement_Method__c == 'Tranched disbursement allowed') {
                        theLoan.Capitalized_Amount__c = le.Transactions__r[0].Amount__c;
                    }
                    if (theLoan.Setup_Fee_Charging_Method__c == 'Paid Up Front (scheduled)') { 
                        switch on theLoan.Setup_Fee__c {
                            when '% of Disbursement Amount' {
                                Decimal feesExpected = le.Transactions__r[0].Amount__c * theLoan.Percent_of_Disbursement_Amount__c/100;
                                if (theLoan.Setup_Fee_Expected__c < feesExpected) feesExpected = theLoan.Setup_Fee_Expected__c; 
                                rsFees = LoanScheduler.createFeesRepaymentSchedule(theLoan.Id, eventDate, feesExpected);
                            }
                            when 'Flat Amount' {
                                rsFees = LoanScheduler.createFeesRepaymentSchedule(theLoan.Id, eventDate, theLoan.Setup_Fee_Expected__c);
                            }
                        } 
                    }
                } else {
                    if (theLoan.Grace_Period_Type__c != 'None') theLoan.Grace_Period_Type__c = 'None';
                    if (theLoan.Number_of_Grace_Periods__c != 0) theLoan.Number_of_Grace_Periods__c = 0;
                    
                    // set the reschedule amount
                    AggregateResult[] results = [
                        SELECT SUM(Principal_Remaining__c)principalRemaining, SUM(Fees_Remaining__c)feesRemaining
                        FROM Repayment_Schedule__c
                        WHERE Loan__c = :theLoan.Id AND Active__c = true AND Due_Date__c > :eventDate 
                    ];

                    if (theLoan.Setup_Fee_Charging_Method__c == 'Capitalized') {
                        theLoan.Capitalized_Fee_Amount__c = (Decimal)results[0].get('feesRemaining');
                        theLoan.Capitalized_Amount__c = (Decimal)results[0].get('principalRemaining') + le.Transactions__r[0].Amount__c + (Decimal)results[0].get('feesRemaining');
                    } else {
                        theLoan.Capitalized_Amount__c = (Decimal)results[0].get('principalRemaining') + le.Transactions__r[0].Amount__c;
                    }
                    
                    if (theLoan.Setup_Fee_Charging_Method__c == 'Paid Up Front (scheduled)' 
                        && theLoan.Setup_Fee__c == '% of Disbursement Amount')
                    {
                        Investment__c tempInv = [
                            SELECT Setup_Fee_Expected__c, Setup_Fees_Expected__c
                            FROM Investment__c
                            WHERE Id = :theLoan.Id
                        ];
                        if (tempInv.Setup_Fee_Expected__c - tempInv.Setup_Fees_Expected__c > 0) {
                            Decimal feesExpected = le.Transactions__r[0].Amount__c * theLoan.Percent_of_Disbursement_Amount__c/100;
                            if (tempInv.Setup_Fee_Expected__c - tempInv.Setup_Fees_Expected__c < feesExpected) 
                                feesExpected = tempInv.Setup_Fee_Expected__c - tempInv.Setup_Fees_Expected__c;
                                
                            rsFees = LoanScheduler.createFeesRepaymentSchedule(theLoan.Id, eventDate, feesExpected);
                        } 
                    }
                }
                
                dataMap.put('action', 'Disbursement');
                dataMap.put('loan', JSON.serialize(theLoan));
                dataMap.put('disbursementDate', le.Event_Date__c);
                
                List<Repayment_Schedule__c> rsToReschedule = [
                    SELECT Start_Date__c, Interest_Expected_Standard_Loan__c, Active__c, Total_Paid__c, Principal_Remaining__c, 
                        Principal_Written_Off__c, Interest_Remaining__c, Interest_Written_Off__c, Due_Date__c, Loan__c, Total_Due__c,
                        Fees_Remaining__c, Fees_Written_Off__c, Late_Repayment_Fees_Remaining__c, Late_Repayment_Fees_Written_Off__c, 
                        Principal_Balance__c, Status__c, Fees_Paid__c, Interest_Paid__c, Late_Repayment_Fees_Paid__c, Principal_Paid__c,
                        Monitoring_Fees_Expected__c
                    FROM Repayment_Schedule__c
                    WHERE Loan__c =: theLoan.Id AND Due_Date__c > :le.Event_Date__c 
                    ORDER BY Due_Date__c ASC
                ];
                
                Date startDate;
                if (index != 0 && !rsToReschedule.isEmpty()) {
                    Repayment_Schedule__c rs = rsToReschedule[0];
                    Decimal additionalInterest = (rs.Interest_Expected_Standard_Loan__c * (rs.Start_Date__c.daysBetween(le.Event_Date__c)) 
                        / (rs.Start_Date__c.daysBetween(rs.Due_Date__c))).setScale(2);
                    startDate = rs.Start_Date__c;
                    dataMap.put('additionalInterest', additionalInterest);
                    
                    Decimal additionalMonitoringFee = (rs.Monitoring_Fees_Expected__c * (rs.Start_Date__c.daysBetween(le.Event_Date__c)) 
                        / (rs.Start_Date__c.daysBetween(rs.Due_Date__c))).setScale(2);
                    dataMap.put('additionalMonitoringFee', additionalMonitoringFee);
                }
                dataMap.put('repaymentSchedules', JSON.serialize(rsToReschedule));
                
                Map<String, List<SObject>> resultMap = RescheduleLoanButtonController.processRescheduling(dataMap);
                if (resultMap.containsKey('toUpdate')) {
                    DMLManager.updateAsUser(resultMap.get('toUpdate'));
                }
                if (resultMap.containsKey('toDelete')) {
                    DMLManager.deleteAsUser(resultMap.get('toDelete'));
                }
                List<Repayment_Schedule__c> rsToInsert = resultMap.get('toInsert');
                if (index != 0 && !rsToReschedule.isEmpty()) {
                    rsToInsert[0].Start_Date__c = startDate;
                }

                if (rsFees != null) rsToInsert.add(0, rsFees);
                DMLManager.insertAsUser(rsToInsert);
                
                index++;
                returnMap.put('index', String.valueOf(index));
                // loanIdToDisbursementIndex.put(le.Investment__c, index);

            }
            when 'Interest Rate Change' {
                System.debug('RecalculateLoanFromScratchBatch.InterestRateChange');
                Investment__c theLoanForVariableInterestRate = [
                    SELECT Loan_Product__r.Interest_Rate_Review_Frequency__c, Loan_Product__r.Interest_Reference_Rate__c, Grace_Period_Type__c,
                        Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c, Loan_Product__c,
                        Loan_Product__r.Default_Interest_Rate__c, Interest_Rate__c, Variable_Interest_Spread__c, Open_Ended_Loan__c, 
                        (
                            SELECT Start_Date__c, Due_Date__c, Name
                            FROM Repayment_Schedules__r
                            WHERE Start_Date__c < :le.Event_Date__c AND Active__c = true AND Migration__c = false AND Status__c != 'Fee'
                            ORDER BY Start_Date__c ASC
                        )
                    FROM Investment__c
                    WHERE Id =: theLoan.Id 
                ];
                List<Repayment_Schedule__c> rsToUpdate = VariableInterestRateBatch.processRepaymentSchedules(theLoanForVariableInterestRate, le.Event_Date__c);
                if (!rsToUpdate.isEmpty()) DMLManager.updateAsUser(rsToUpdate);
                else returnMap.put('loanEventToDelete', JSON.serialize(le));
            }
            when 'Interest Rollup Recalculation' {
                System.debug('RecalculateLoanFromScratchBatch.InterestRollupRecalculation');
                
                Map<String, List<SObject>> resultMap = RecalculateInterestRollupLoansBatch.updateRepaymentSchedules(theLoan.Id, le.Event_Date__c);
                if (resultMap.containsKey('repaymentSchedules')) DMLManager.updateAsUser(resultMap.get('repaymentSchedules'));

            }
            when 'Bullet Repayment' {
                List<Repayment_Schedule__c> rsToProcess = BalloonRepaymentButtonController.getRepaymentSchedules(theLoan.Id).Repayment_Schedules__r;
                Map<String, List<Repayment_Schedule__c>> schedulesMap = BalloonRepaymentButtonController.processRepaymentSchedules(rsToProcess, Integer.valueOf(le.Balloon_Repayment_Period__c), theLoan.Id);
                
                if (!schedulesMap.get('schedulesToDelete').isEmpty()) DMLManager.deleteAsUser(schedulesMap.get('schedulesToDelete'));
                DMLManager.updateAsUser(schedulesMap.get('schedulesToUpdate'));
                    
            }
            when 'Automatic Schedule Migration for Migrated Loan' {
                DMLManager.insertAsUser(CreateRemainingScheduleBatch.createRepaymentSchedules(theLoan));  
            }
            when 'Fee Cancelled' {
                System.debug('RecalculateLoanFromScratchBatch.FeeCancelled');
                if ((le.Approval_Status__c == 'Approved' || le.Approval_Status__c == 'No Approval Required') && !le.Loan_Event_Details__r.isEmpty()) {
                    Loan_Event_Detail__c led = le.Loan_Event_Details__r[0];
                    List<Repayment_Schedule__c> rsToUpdate = new List<Repayment_Schedule__c>();
                    for (Repayment_Schedule__c rs : [SELECT Due_Date__c, Cancel_Late_Repayment_Fee__c FROM Repayment_Schedule__c 
                        WHERE Loan__c = :theLoan.Id AND Due_Date__c =: led.Due_Date__c])
                    {
                        System.debug(rs);
                        rs.Cancel_Late_Repayment_Fee__c = led.Cancel_Late_Repayment_Fee__c;
                        rsToUpdate.add(rs);
                    }
                    if (!rsToUpdate.isEmpty()) DMLManager.updateAsUser(rsToUpdate);
                }
            }
            when 'Refinance' {
                // not available

            }
        }
        return returnMap;
    }

}