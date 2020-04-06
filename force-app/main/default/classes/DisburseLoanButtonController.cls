public with sharing class DisburseLoanButtonController {
    
    // this method is executed when the Disburse Loan button is clicked
    @AuraEnabled
    public static List<Transaction__c> getDisbursementTransactions(Id loanId) {
        // Check to see whether the caller has access to this information.
        if (!Transaction__c.SObjectType.getDescribe().isAccessible()){
            throw new AuraHandledException(System.Label.sfims.error_message_7);
        }

        return [
            SELECT Id, Amount__c, Status__c, Transaction_Date__c, Investment__c, Type__c
            FROM Transaction__c
            WHERE Investment__c =: loanId AND Type__c = 'Disbursement'
            ORDER BY Transaction_Date__c ASC
        ];

    }

    // this method is executed when the Preview button on the Disburse Loan pop-up is clicked
    @AuraEnabled
    public static Map<String, String> generateSchedulePreview(String loanId, String JSONtransactionsNew, String JSONtransactionsOld) {
        // Check to see whether the caller has access to this information.
        if (!Investment__c.SObjectType.getDescribe().isAccessible()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isAccessible())
        {
            throw new AuraHandledException(System.Label.sfims.error_message_22);
        }
        
        // assign a record type for each new transaction
        System.debug(loanId);
        System.debug(JSONtransactionsNew);
        System.debug(JSONtransactionsOld);

        Map<String, String> resultMap = DisburseLoanButtonController.disburseLoan(loanId, JSONtransactionsNew, JSONtransactionsOld, true);

        return resultMap;

    }

    // this method is executed when the Save button on the Disburse Loan pop-up is clicked
    @AuraEnabled
    public static Map<String, String> saveData(String loanId, String JSONtransactionsNew, String JSONtransactionsOld) {
        // Check to see whether the caller has access to this information.
        if (!Transaction__c.SObjectType.getDescribe().isAccessible()
            || !Transaction__c.SObjectType.getDescribe().isCreateable()
            || !Transaction__c.SObjectType.getDescribe().isUpdateable()
            || !Transaction__c.SObjectType.getDescribe().isDeletable()
            || !Investment__c.SObjectType.getDescribe().isAccessible()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isAccessible()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isCreateable()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isUpdateable()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isDeletable()
            || !Loan_Event__c.SObjectType.getDescribe().isCreateable())
        {
            throw new AuraHandledException(System.Label.sfims.error_message_7);
        }
        
        // assign a record type for each new transaction
        System.debug(JSONtransactionsNew);

        Savepoint sp = database.setSavepoint();
        Map<String, String> resultMap = DisburseLoanButtonController.disburseLoan(loanId, JSONtransactionsNew, JSONtransactionsOld, false);
        System.debug('AFTER DisburseLoanButtonController.disburseLoan');
        try {
            if (resultMap.containsKey('error')) {
                return resultMap;
            } else {
                if (!resultMap.isEmpty()) {
                    if (resultMap.containsKey('toDelete'))  
                        DMLManager.deleteAsUser((List<SObject>)JSON.deserialize(resultMap.get('toDelete'), List<SObject>.class));

                    if (resultMap.containsKey('toUpdate')) 
                        DMLManager.updateAsUser((List<SObject>)JSON.deserialize(resultMap.get('toUpdate'), List<SObject>.class));

                    if (resultMap.containsKey('toInsert')) 
                        DMLManager.insertAsUser((List<SObject>)JSON.deserialize(resultMap.get('toInsert'), List<SObject>.class));

                    List<Loan_Event__c> le = new List<Loan_Event__c>();
                    if (resultMap.containsKey('loanEvents')) {
                        le = (List<Loan_Event__c>)JSON.deserialize(resultMap.get('loanEvents'), List<Loan_Event__c>.class);
                        DMLManager.insertAsSystem(le);
                    }

                    List<Transaction__c> trToUpdate = new List<Transaction__c>();
                    List<Transaction__c> trToInsert = new List<Transaction__c>();
                    List<Transaction__c> trToDelete = new List<Transaction__c>();
                    
                    // link disbursed transactions and loan events
                    if (resultMap.containsKey('trToProcess')) {
                        List<Transaction__c> trToProcess = (List<Transaction__c>)JSON.deserialize(resultMap.get('trToProcess'), List<Transaction__c>.class);
                        for (Integer i = 0; i < trToProcess.size(); i++) {
                            Transaction__c tr = trToProcess[i];
                            tr.Loan_Event__c = le[i].Id;
                            if (tr.Id != null) trToUpdate.add(tr);
                            else trToInsert.add(tr);
                        }
                    }

                    if (resultMap.containsKey('trToDelete')) 
                        trToDelete.addAll((List<Transaction__c>)JSON.deserialize(resultMap.get('trToDelete'), List<Transaction__c>.class));
                    
                    if (resultMap.containsKey('trToUpdate')) 
                        trToUpdate.addAll((List<Transaction__c>)JSON.deserialize(resultMap.get('trToUpdate'), List<Transaction__c>.class));
                    
                    if (resultMap.containsKey('trToInsert'))
                        trToInsert.addAll((List<Transaction__c>)JSON.deserialize(resultMap.get('trToInsert'), List<Transaction__c>.class));         

                    if (resultMap.containsKey('openEndedLoan')) {
                        if (!trToDelete.isEmpty()) DMLManager.deleteAsUser(trToDelete);
                        if (!trToUpdate.isEmpty()) DMLManager.updateAsUser(trToUpdate);
                        if (!trToInsert.isEmpty()) DMLManager.insertAsUser(trToInsert);
                        
                        RecalculateButtonController.recalculateOpenEndedLoan((String)resultMap.get('openEndedLoan'));
                    } else {
                        // define bypassProcessTransactions to prevent triple or double launch of ProcessTransactions logic
                        if (!trToInsert.isEmpty()) TransactionTriggerHandler.bypassProcessTransactions = true;
                        if (!trToDelete.isEmpty()) {
                            if (!trToInsert.isEmpty() || !trToUpdate.isEmpty()) TransactionTriggerHandler.bypassProcessTransactions = true;
                            DMLManager.deleteAsUser(trToDelete);
                        }
                        if (!trToUpdate.isEmpty()) {
                            if (!trToInsert.isEmpty() && !TransactionTriggerHandler.bypassProcessTransactions) TransactionTriggerHandler.bypassProcessTransactions = true;
                            DMLManager.updateAsUser(trToUpdate);
                        }
                        if (!trToInsert.isEmpty()) {
                            if (TransactionTriggerHandler.bypassProcessTransactions) TransactionTriggerHandler.bypassProcessTransactions = false;
                            DMLManager.insertAsUser(trToInsert);
                        }
                        System.debug(Utility.InstalmentAmount);
                        Investment__c inv = [
                            SELECT Last_Instalment_Amount__c
                            FROM Investment__c
                            WHERE Id = :loanId
                        ];
                        inv.Last_Instalment_Amount__c = Utility.InstalmentAmount;
                        DMLManager.updateAsUser(new List<Investment__c>{ inv });

                        if (resultMap.containsKey('recalculate') && !Test.isRunningTest()) {
                            Investment__c theLoanToUpdate = new Investment__c(
                                Id = (Id)resultMap.get('recalculate'),
                                Open_Ended_Loan__c = false,
                                Recalculation_Status__c = 'Pending Recalculation'
                            );
                            String result = TriggerHelper.runRecalculateLoanFromScratch(new List<Investment__c>{theLoanToUpdate});
                            if (result != null) {
                                resultMap.clear();
                                resultMap.put('error', result);
                                return resultMap;
                            }
                        }   
                    }
                    
                }
                resultMap.clear();
                resultMap.put('success', System.Label.sfims.success_message_1);
                return resultMap;
            }
        } catch(System.DmlException e) {
            // rollback and re-throw exception so that it can be handled
            Database.rollback(sp);
            resultMap.put('error', String.valueOf(e.getDmlMessage(0)));
            return resultMap;
        }
    }

    public static Map<String, String> disburseLoan(String loanId, String JSONtransactionsNew, String JSONtransactionsOld, Boolean preview) {
        // set up an input parameter for rescheduling
        Map<String, Object> dataMap = new Map<String, Object>();
        dataMap.put('action', 'Disbursement');
        dataMap.put('totalPrincipalWrittenOff', 0);
        dataMap.put('totalInterestWrittenOff', 0);
        dataMap.put('totalFeesWrittenOff', 0);
        dataMap.put('totalPenaltiesWrittenOff', 0);
        return DisburseLoanButtonController.processDisbursedTransactions(loanId, JSONtransactionsNew, JSONtransactionsOld, dataMap, preview);

    }

    /**
     * @description          Process transactions with the 'Disbursed' status.
     */
    public static Map<String, String> processDisbursedTransactions(String loanId, String JSONtransactionsNew, String JSONtransactionsOld, Map<String, Object> dataMap, Boolean preview){
        System.debug('DisburseLoanButtonController.processDisbursedTransactions');
        Map<String, String> returnMap = new Map<String, String>();
        
        List<Investment__c> loans = [
            SELECT Id, Status__c, Recalculation_Status__c, Number_of_Instalments__c, Repayment_Frequency__c, Repayment_Frequency_Unit__c, 
                Number_of_Grace_Periods__c, Grace_Period_Type__c, Amount__c, Capitalized_Amount__c, Capitalized_Fee_Amount__c, 
                Interest_Rate__c, Variable_Interest_Spread__c, Day_Count_Convention__c, Non_Working_Days_Rescheduling__c,
                Open_Ended_Loan__c, Disbursement_Date__c, First_Repayment_Date__c, Disbursement_Method__c, Expected_End_Date__c,
                Setup_Fee_Charging_Method__c, Setup_Fee__c, Setup_Fee_Expected__c, Setup_Fees_Expected__c, Percent_of_Disbursement_Amount__c,
                Loan_Product__c, Loan_Product__r.Interest_Rate_Source__c, Loan_Product__r.Interest_Reference_Rate__c,
                Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c, 
                Loan_Product__r.Interest_Rate_Review_Frequency__c, Last_Instalment_Amount__c, Monitoring_Fee_Percentage__c,
                (
                    SELECT Id, Active__c, Total_Paid__c, Principal_Remaining__c, Principal_Written_Off__c, Interest_Remaining__c, Interest_Written_Off__c, 
                        Due_Date__c, Fees_Remaining__c, Fees_Written_Off__c, Late_Repayment_Fees_Remaining__c, Late_Repayment_Fees_Written_Off__c, Loan__c, 
                        Total_Due__c, Principal_Balance__c, Status__c, Loan__r.Amount__c, Fees_Paid__c, Interest_Paid__c, Late_Repayment_Fees_Paid__c, 
                        Principal_Paid__c, Principal_Expected__c, Interest_Expected_Standard_Loan__c, Fees_Expected__c, Start_Date__c, 
                        Theoretical_Due_Date__c, Monitoring_Fees_Expected__c 
                    FROM Repayment_Schedules__r 
                    WHERE Active__c = true 
                    ORDER BY Due_Date__c ASC
                ),
                (
                    SELECT Id, Amount__c, Status__c, Type__c, Transaction_Date__c
                    FROM Transactions__r 
                    WHERE Type__c = 'Disbursement'
                    ORDER BY Transaction_Date__c ASC
                ),
                (
                    SELECT Interest_Rate__c, Repayment_Frequency__c, Repayment_Frequency_Unit__c, Variable_Interest_Spread__c
                    FROM Loan_Events__r
                    WHERE Loan_Event_Type__c IN ('Disbursement', 'Reschedule')
                    ORDER BY Event_Date__c DESC
                    LIMIT 1
                ) 
            FROM Investment__c 
            WHERE Id =:loanId
        ];

        if (loans.isEmpty()) {
            returnMap.put('error', System.Label.sfims.error_message_8);
            return returnMap;
        }
        Investment__c theLoan = loans[0];

        if (!theLoan.Loan_Events__r.isEmpty()) {
            // use actual loan parameters from the latest loan event
            Loan_Event__c le = theLoan.Loan_Events__r[0];
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

        //------------------------------------VALIDATIONS-------------------------------------------------------
        if (theLoan.Repayment_Schedules__r.isEmpty()) {
            returnMap.put('error', System.Label.sfims.error_message_9);
            return returnMap;
        } 

        List<Transaction__c> existingDisbursedTransactions = new List<Transaction__c>();
        if (!theLoan.Transactions__r.isEmpty()) {
            for (Transaction__c tr : theLoan.Transactions__r) {
                if (tr.Status__c == 'Disbursed') {
                    existingDisbursedTransactions.add(tr);
                    break;
                }
            }    
        }
        if (theLoan.Status__c == 'Active' && existingDisbursedTransactions.isEmpty()) {
            returnMap.put('error', System.Label.sfims.error_message_10);
            return returnMap;
        }
        
        List<Repayment_Schedule__c> repaymentSchedules = theLoan.Repayment_Schedules__r;

        List<Transaction__c> newTransactions = new List<Transaction__c>((List<Transaction__c>)JSON.deserialize(JSONtransactionsNew, List<Transaction__c>.class));
        List<Transaction__c> oldTransactions = new List<Transaction__c>((List<Transaction__c>)JSON.deserialize(JSONtransactionsOld, List<Transaction__c>.class));
    
        List<Transaction__c> trToUpdate = new List<Transaction__c>();
        List<Transaction__c> trToInsert = new List<Transaction__c>();
        List<Transaction__c> trToProcess = new List<Transaction__c>();
        
        Map<Id, Transaction__c> newTransactionsMap = new Map<Id, Transaction__c>();
        Map<Id, Transaction__c> oldTransactionsMap = new Map<Id, Transaction__c>();
        if (!oldTransactions.isEmpty()) {
            oldTransactionsMap = new Map<Id, Transaction__c>(oldTransactions);
        }
        
        List<Transaction__c> disbursedTransactions = new List<Transaction__c>();
        Integer numberOfDisbursedTransactionsAfterFirstRepaymentDate = 0;
        Id recordTypeId = Schema.Sobjecttype.Transaction__c.getRecordTypeInfosByName().get('Investment Transaction').getRecordTypeId();
        for (Transaction__c tr : newTransactions) {
            if (tr.Status__c == 'Disbursed') {
                disbursedTransactions.add(tr);
                if (tr.Transaction_Date__c > theLoan.First_Repayment_Date__c) 
                    numberOfDisbursedTransactionsAfterFirstRepaymentDate++;
            }
            if (!theLoan.Open_Ended_Loan__c && tr.Transaction_Date__c >= theLoan.Expected_End_Date__c) {
                returnMap.put('error', System.Label.sfims.error_message_11);
                return returnMap;
            }
            if (tr.Id != null) {
                newTransactionsMap.put(tr.Id, tr);
                if (oldTransactionsMap.isEmpty() || tr.Amount__c != oldTransactionsMap.get(tr.Id).Amount__c
                    || tr.Transaction_Date__c != oldTransactionsMap.get(tr.Id).Transaction_Date__c
                    || tr.Status__c != oldTransactionsMap.get(tr.Id).Status__c) 
                {
                    if (tr.Status__c == 'Disbursed') {
                        tr.Created_Using_The_Disburse_Button__c = true;
                        trToProcess.add(tr);
                    } else {
                        trToUpdate.add(tr);
                    }
                }
            } else {
                tr.RecordTypeId = recordTypeId;
                if (tr.Status__c == 'Disbursed') {
                    tr.Created_Using_The_Disburse_Button__c = true;
                    trToProcess.add(tr);
                } else {
                    trToInsert.add(tr);
                }
            }
        }

        if (numberOfDisbursedTransactionsAfterFirstRepaymentDate != 0 
            && disbursedTransactions.size() == numberOfDisbursedTransactionsAfterFirstRepaymentDate) 
        {
            returnMap.put('error', System.Label.sfims.error_message_12);
            return returnMap;
        }

        List<Transaction__c> trToDelete = new List<Transaction__c>();
        for (Transaction__c tr : oldTransactionsMap.values()) {
            if (!newTransactionsMap.containsKey(tr.Id)) {
                trToDelete.add(tr);
                if (tr.Status__c == 'Disbursed' && preview) {
                    returnMap.put('error', System.Label.sfims.error_message_13);
                    return returnMap;
                }
            }
        }

        // If the investment current transaction related to has the 'Full disbursement at start' type of the disbursement method, 
        // then check if the transaction amount is equal to the Amount field on the Investment object
        if (theLoan.Disbursement_Method__c == 'Full disbursement at start') {
            // verify the number of transactions with the type 'Disbursement' (it must be 1)
            if (newTransactions.size() > 1) {
                returnMap.put('error', System.Label.sfims.error_message_14);
                return returnMap;
            }
            if (newTransactions.size() == 1) {
                // verify the transaction amount 
                Transaction__c tr = newTransactions[0];
                switch on theLoan.Setup_Fee_Charging_Method__c {
                    when 'Deducted From Principal' {
                        // if admin fee charging method is "Deducted From Principal", 
                        // then only accept a transaction amount equal to Capitalized Amount - Admin Fee Amount
                        if (tr.Amount__c != theLoan.Amount__c - theLoan.Setup_Fee_Expected__c) {
                            returnMap.put('error', System.Label.sfims.error_message_15);
                            return returnMap;
                        }
                    }
                    when else {
                        if (tr.Amount__c != theLoan.Amount__c) {
                            returnMap.put('error', System.Label.sfims.error_message_16);
                            return returnMap;
                        }
                            
                    }
                }
            } 
        } else if (theLoan.Disbursement_Method__c == 'Tranched disbursement allowed') {
            // verify the transaction date of new transactions
            Date theEarliestPlanned;
            Date theLatestDisbursed;
            for (Transaction__c tmp : newTransactions) {
                if (tmp.Status__c == 'Planned' && (theEarliestPlanned == null || theEarliestPlanned > tmp.Transaction_Date__c)) {
                    theEarliestPlanned = tmp.Transaction_Date__c;
                }
                if (tmp.Status__c == 'Disbursed' && (theLatestDisbursed == null || theLatestDisbursed < tmp.Transaction_Date__c)) {
                    theLatestDisbursed = tmp.Transaction_Date__c;
                }
            }
            
            if (theEarliestPlanned < theLatestDisbursed) {
                returnMap.put('error', System.Label.sfims.error_message_17);
                return returnMap;
            }
            
            // verify the total amount of transactions
            Decimal totalAmount = 0;
            for (Transaction__c tmp : newTransactions) {
                Decimal amount = 0;
                if (tmp.Amount__c != null) amount = tmp.Amount__c;
                totalAmount += amount; 
            }
            
            if (totalAmount > theLoan.Amount__c) {
                returnMap.put('error', System.Label.sfims.error_message_18);
                return returnMap;   
            }
        }

        //------------------------------------MAIN DISBURSE LOGIC-------------------------------------------------------
        // sort by Transaction Date
        List<TransactionWrapper> trws = new List<TransactionWrapper>();
        for (Transaction__c tr : trToProcess) {
            trws.add(new TransactionWrapper(tr));
        }
        trws.sort();
        trToProcess = new List<Transaction__c>();
        for (TransactionWrapper trw : trws) {
            trToProcess.add(trw.tr);
        }
        
        // each time a 'Disbursed' transaction is saved, this means that at that point there is a reschedule of the Loan 
        Map<String, List<SObject>> resultMap = new Map<String, List<SObject>>();
        if (!trToDelete.isEmpty()) resultMap.put('trToDelete', trToDelete);
        if (!trToUpdate.isEmpty()) resultMap.put('trToUpdate', trToUpdate);
        if (!trToInsert.isEmpty()) resultMap.put('trToInsert', trToInsert);
        if (!trToProcess.isEmpty()) resultMap.put('trToProcess', trToProcess);

        if (!trToProcess.isEmpty()) {
        
            Boolean createFeesSchedule = false;
            Decimal currentFeesAmount = 0;
            if (theLoan.Setup_Fee_Charging_Method__c == 'Paid Up Front (scheduled)' 
                && theLoan.Setup_Fee__c == '% of Disbursement Amount')
            {
                // if the setup fee charging method is 'Paid Up Front (scheduled)' and the setup fee is '% of Disbursement Amount'
                // then incorporate % into first schedule for each new disbursement
                if (!existingDisbursedTransactions.isEmpty()) {
                    if (theLoan.Setup_Fees_Expected__c > theLoan.Setup_Fee_Expected__c) {
                        returnMap.put('error', System.Label.sfims.error_message_19);
                        return returnMap;
                    } else if (theLoan.Setup_Fees_Expected__c < theLoan.Setup_Fee_Expected__c)  {
                        createFeesSchedule = true;
                        currentFeesAmount = theLoan.Setup_Fees_Expected__c;
                    }
                } else {
                    createFeesSchedule = true;
                }
            }

            List<Loan_Event__c> newInterestLoanEvents = new List<Loan_Event__c>();
            if (theLoan.Loan_Product__c != null && theLoan.Loan_Product__r.Interest_Rate_Source__c == 'Variable Interest'
                && theLoan.Loan_Product__r.Interest_Reference_Rate__c != null) 
            {
                // check if there is an Interest Rate on the Disbursement Date or earlier
                Date startDate = existingDisbursedTransactions.isEmpty() ? 
                    trToProcess[0].Transaction_Date__c : existingDisbursedTransactions[0].Transaction_Date__c;
                
                List<Interest_Rate__c> interestRates = [
                    SELECT Id
                    FROM Interest_Rate__c
                    WHERE Interest_Rate_Source__c =: theLoan.Loan_Product__r.Interest_Reference_Rate__c
                        AND Date__c <= :startDate
                    LIMIT 1
                ];
                if (interestRates.isEmpty()) {
                    returnMap.put('error', System.Label.sfims.error_message_20);
                    return returnMap;
                }

                if (preview) returnMap.put('variableInterest', System.Label.sfims.warning_message_1);
                
                interestRates = [
                    SELECT Rate__c, Date__c, Interest_Rate_Source__c
                    FROM Interest_Rate__c
                    WHERE Interest_Rate_Source__c =: theLoan.Loan_Product__r.Interest_Reference_Rate__c
                        AND Date__c < TODAY
                    ORDER BY Date__c, Name
                ];
                
                Investment__c theLoanToProcessInterestRates = [
                    SELECT Open_Ended_Loan__c, Recalculation_Status__c, Loan_Product__c, Expected_End_Date__c, Disbursement_Date__c,
                        Loan_Product__r.Interest_Reference_Rate__c, Loan_Product__r.Interest_Rate_Review_Frequency__c, 
                    (
                        SELECT Start_Date__c, Due_Date__c 
                        FROM Repayment_Schedules__r 
                        WHERE Active__c = true AND Migration__c = false
                        ORDER BY Start_Date__c ASC, Name DESC 
                        LIMIT 1
                    ),
                    (
                        SELECT Event_Date__c 
                        FROM Loan_Events__r 
                        WHERE Loan_Event_Type__c = 'Interest Rate Change' 
                        ORDER BY Event_Date__c
                    ) 
                    FROM Investment__c 
                    WHERE Id = :theLoan.Id
                ];
                
                Map<String, List<SObject>> loanEventsMap = TriggerHelper.processInterestRates(theLoanToProcessInterestRates, startDate, interestRates);
                // System.debug(loanEventsMap.containsKey('loans'));
                // System.debug(loanEventsMap.containsKey('loanEvents'));
                // System.debug(loanEventsMap.get('loanEvents').size());
                if (loanEventsMap.containsKey('loans')) returnMap.put('recalculate', theLoan.Id);
                if (loanEventsMap.containsKey('loanEvents')) newInterestLoanEvents.addAll((List<Loan_Event__c>)loanEventsMap.get('loanEvents'));
            }
            
            if (theLoan.Open_Ended_Loan__c) {
                List<Loan_Event__c> loanEvents = new List<Loan_Event__c>();
                for (Integer i = 0; i < trToProcess.size(); i++) {
                    Transaction__c tr = trToProcess[i];

                    loanEvents.add(new Loan_Event__c(
                        Loan_Event_Type__c = 'Disbursement',
                        Event_Date__c = tr.Transaction_Date__c,
                        Amount__c = tr.Amount__c,
                        Investment__c = theLoan.Id,
                        Loan_Product__c = theLoan.Loan_Product__c
                    ));
                }

                resultMap.put('loanEvents', loanEvents);
                returnMap.put('openEndedLoan', theLoan.Id);

            } else {
                for (Integer i = 0; i < trToProcess.size(); i++) {
                    Transaction__c tr = trToProcess[i];
                    
                    if (i == 0 && existingDisbursedTransactions.isEmpty()) {
                        // this means that the loan had no disbursement 
                        // check if the recalculation is needed
                        Boolean recalculate = false;
                        switch on theLoan.Disbursement_Method__c {
                            when 'Full disbursement at start' {
                                if (theLoan.Disbursement_Date__c != tr.Transaction_Date__c) {
                                    theLoan.Disbursement_Date__c = tr.Transaction_Date__c;
                                    recalculate = true;
                                }
                            }
                            when 'Tranched disbursement allowed' {
                                if (theLoan.Disbursement_Date__c != tr.Transaction_Date__c) {
                                    theLoan.Disbursement_Date__c = tr.Transaction_Date__c;
                                    recalculate = true;
                                }
                                if (theLoan.Amount__c != tr.Amount__c) {
                                    theLoan.Capitalized_Amount__c = tr.Amount__c + theLoan.Capitalized_Fee_Amount__c;
                                    if (!recalculate) recalculate = true;
                                }
                            }
                        }

                        if (recalculate || preview) {
                            // do recalculate
                            if (!resultMap.containsKey('toDelete')) resultMap.put('toDelete', new List<SObject>());
                            resultMap.get('toDelete').addAll([SELECT Id FROM Repayment_Schedule__c WHERE Loan__c = :loanId AND Migration__c = false]);
                            // System.debug(theLoan.Capitalized_Amount__c);
                            // System.debug(theLoan.Disbursement_Date__c);
                            if (createFeesSchedule) {
                                Decimal feesExpected = (tr.Amount__c * theLoan.Percent_of_Disbursement_Amount__c/100).setScale(2);
                                if (feesExpected >= theLoan.Setup_Fee_Expected__c) {
                                    feesExpected = theLoan.Setup_Fee_Expected__c;
                                    createFeesSchedule = false;
                                }
                                currentFeesAmount = feesExpected; 
                                
                                if (!resultMap.containsKey('toInsert')) resultMap.put('toInsert', new List<SObject>());
                                resultMap.get('toInsert').add(LoanScheduler.createFeesRepaymentSchedule(theLoan.Id, tr.Transaction_Date__c, feesExpected));
                                theLoan.Setup_Fee_Charging_Method__c = null;
                            }
                            
                            List<Repayment_Schedule__c> rsToInsert = LoanScheduler.generateSchedule(theLoan);
                            if (trToProcess.size() == 1) {
                                if (!resultMap.containsKey('toInsert')) resultMap.put('toInsert', new List<SObject>());
                                resultMap.get('toInsert').addAll(rsToInsert);
                            } else if (trToProcess.size() > 1) {
                                repaymentSchedules = rsToInsert;
                            }
                        }
                        if (!resultMap.containsKey('loanEvents')) resultMap.put('loanEvents', new List<SObject>());
                        dataMap.put('loan', JSON.serialize(theLoan));
                        dataMap.put('disbursementDate', tr.Transaction_Date__c);
                        if (Utility.InstalmentAmount == null) Utility.InstalmentAmount = theLoan.Last_Instalment_Amount__c;
                        resultMap.get('loanEvents').add(RescheduleLoanButtonController.createLoanEvent(dataMap));
                        
                        if (theLoan.Grace_Period_Type__c == 'Interest Rollup'
                            && theLoan.Loan_Product__r.Interest_Rate_Source__c == 'Variable Interest') 
                        {
                            Date interestRollupRecalculationDate;
                            for (Repayment_Schedule__c rs : repaymentSchedules) {
                                if (rs.Status__c != 'Fee' && rs.Status__c != 'Grace') {
                                    interestRollupRecalculationDate = rs.Start_Date__c;
                                    break;
                                }
                            }
                            if (interestRollupRecalculationDate != null && interestRollupRecalculationDate < System.today()) {
                                Loan_Event__c le = new Loan_Event__c( 
                                    Event_Date__c = interestRollupRecalculationDate,
                                    Investment__c = theLoan.Id,
                                    Loan_Event_Type__c = 'Interest Rollup Recalculation',
                                    Loan_Product__c = theLoan.Loan_Product__c
                                );
                                resultMap.get('loanEvents').add(le);
                            }
                        }

                        continue;
                    }

                    System.debug('----------');
                    // calculate reschedule amount and determine loan parameters
                    List<Repayment_Schedule__c> rsPrevious = new List<Repayment_Schedule__c>();
                    Integer instalments = 0;
                    Decimal principalRemaining = 0;
                    Decimal feesRemaining = 0;

                    List<Repayment_Schedule__c> rsToReschedule = new List<Repayment_Schedule__c>();
                    for (Repayment_Schedule__c rs : repaymentSchedules) {    
                        if (rs.Due_Date__c <= tr.Transaction_Date__c) {
                            if (preview && i == 0) {
                                if (!resultMap.containsKey('toInsert')) resultMap.put('toInsert', new List<SObject>());
                                resultMap.get('toInsert').add(rs);
                            }
                            if (i > 0) rsPrevious.add(rs);
                        }

                        if (rs.Due_Date__c > tr.Transaction_Date__c) {
                            rsToReschedule.add(rs);
                        
                            Decimal principalExpected = 0;
                            Decimal principalPaid = 0;
                            Decimal principalWrittenOff = 0;
                            Decimal feesExpected = 0;
                            Decimal feesPaid = 0;
                            Decimal feesWrittenOff = 0;

                            if (rs.Principal_Expected__c != null) principalExpected = rs.Principal_Expected__c;
                            if (rs.Principal_Paid__c != null) principalPaid = rs.Principal_Paid__c;
                            if (rs.Principal_Written_Off__c != null) principalWrittenOff = rs.Principal_Written_Off__c;
                            if (rs.Fees_Expected__c != null) feesExpected = rs.Fees_Expected__c;
                            if (rs.Fees_Paid__c != null) feesPaid = rs.Fees_Paid__c;
                            if (rs.Fees_Written_Off__c != null) feesWrittenOff = rs.Fees_Written_Off__c;

                            // calculate Amounts Remaining based on the repayment schedule parameters
                            principalRemaining += principalExpected - principalPaid - principalWrittenOff;
                            feesRemaining += feesExpected - feesPaid - feesWrittenOff;    
                        }
                    }

                    Decimal additionalInterest = 0;
                    Decimal additionalMonitoringFee = 0;
                    Date startDate;
                    
                    theLoan.Number_of_Instalments__c = rsToReschedule.size();
                    theLoan.First_Repayment_Date__c = rsToReschedule[0].Theoretical_Due_Date__c;
                    Repayment_Schedule__c rs = rsToReschedule[0];
                    startDate = rs.Start_Date__c;
                    additionalInterest = (rs.Interest_Expected_Standard_Loan__c * (rs.Start_Date__c.daysBetween(tr.Transaction_Date__c)) / (rs.Start_Date__c.daysBetween(rs.Due_Date__c))).setScale(2);
                    additionalMonitoringFee = (rs.Monitoring_Fees_Expected__c * (rs.Start_Date__c.daysBetween(tr.Transaction_Date__c)) / (rs.Start_Date__c.daysBetween(rs.Due_Date__c))).setScale(2);

                    theLoan.Disbursement_Date__c = tr.Transaction_Date__c;
                    if (theLoan.Grace_Period_Type__c != 'None') theLoan.Grace_Period_Type__c = 'None';
                    if (theLoan.Number_of_Grace_Periods__c != 0) theLoan.Number_of_Grace_Periods__c = 0;
                    // set the reschedule amount
                    if (theLoan.Setup_Fee_Charging_Method__c == 'Capitalized') {
                        theLoan.Capitalized_Fee_Amount__c = feesRemaining;
                        theLoan.Capitalized_Amount__c = principalRemaining + tr.Amount__c + theLoan.Capitalized_Fee_Amount__c;
                    } else {
                        theLoan.Capitalized_Amount__c = principalRemaining + tr.Amount__c;
                    }

                    dataMap.put('loan', JSON.serialize(theLoan));
                    dataMap.put('disbursementDate', tr.Transaction_Date__c);
                    dataMap.put('additionalInterest', additionalInterest);
                    dataMap.put('additionalMonitoringFee', additionalMonitoringFee);
                    if (i == 0) dataMap.put('repaymentSchedules', JSON.serialize(rsToReschedule));
                    else dataMap.put('repaymentSchedules', ''); // set up repaymentSchedules as a blank string to skip write off logic
                    
                    // ----- Reschedule the loan ---------------------------------------------------
                    Map<String, List<SObject>> rescheduleMap = RescheduleLoanButtonController.processRescheduling(dataMap);
                    if (i == 0) {
                        if (rescheduleMap.containsKey('toUpdate')) {
                            if (!resultMap.containsKey('toUpdate')) resultMap.put('toUpdate', new List<SObject>());
                            resultMap.get('toUpdate').addAll(rescheduleMap.get('toUpdate'));
                        }
                        if (rescheduleMap.containsKey('toDelete')) {
                            if (!resultMap.containsKey('toDelete')) resultMap.put('toDelete', new List<SObject>());
                            resultMap.get('toDelete').addAll(rescheduleMap.get('toDelete'));
                        }    
                    }
                    if (!resultMap.containsKey('loanEvents')) resultMap.put('loanEvents', new List<SObject>());

                    resultMap.get('loanEvents').addAll(rescheduleMap.get('loanEvent'));
                    // add repayment schedules to the result map if the current transaction is the last in the scope 
                    if (!rsPrevious.isEmpty()) {
                        if (!resultMap.containsKey('toInsert')) resultMap.put('toInsert', new List<SObject>());
                        resultMap.get('toInsert').addAll(rsPrevious);
                    }
                    if (createFeesSchedule) {
                        Decimal feesExpected = tr.Amount__c * theLoan.Percent_of_Disbursement_Amount__c/100;
                        if (feesExpected >= theLoan.Setup_Fee_Expected__c - currentFeesAmount) {
                            feesExpected = theLoan.Setup_Fee_Expected__c - currentFeesAmount;
                            createFeesSchedule = false;
                        }
                        currentFeesAmount += feesExpected;
                        
                        if (!resultMap.containsKey('toInsert')) resultMap.put('toInsert', new List<SObject>());
                        resultMap.get('toInsert').add(LoanScheduler.createFeesRepaymentSchedule(theLoan.Id, tr.Transaction_Date__c, feesExpected));
                    }
                    if (rescheduleMap.containsKey('toInsert')) {
                        // System.debug(rescheduleMap.get('toInsert').size());
                        List<Repayment_Schedule__c> rsAfterDisburse = (List<Repayment_Schedule__c>) rescheduleMap.get('toInsert');
                        rsAfterDisburse[0].Start_Date__c = startDate;
                        
                        if (i == trToProcess.size() - 1) {   
                            if (!resultMap.containsKey('toInsert')) resultMap.put('toInsert', new List<SObject>());
                            resultMap.get('toInsert').addAll(rsAfterDisburse);
                        } else {
                            repaymentSchedules = rsAfterDisburse;
                        }
                    }
                }
            }

            if (!newInterestLoanEvents.isEmpty()) resultMap.get('loanEvents').addAll(newInterestLoanEvents);
        } else {
            if (preview) {
                if (existingDisbursedTransactions.isEmpty()) {
                    returnMap.put('error', System.Label.sfims.error_message_21);
                } else {
                    returnMap.put('toInsert', JSON.serialize(theLoan.Repayment_Schedules__r));
                }
                return returnMap;
            }
        }
            
        for (String key : resultMap.keySet()) {
            returnMap.put(key, JSON.serialize(resultMap.get(key)));
        }
        
        return returnMap;
    }

    public class TransactionWrapper implements Comparable {
        public Transaction__c tr;
        
        // constructor
        public TransactionWrapper(Transaction__c tr) {
            this.tr = tr;
        }

        // implement the compareTo() method
        public Integer compareTo(Object compareTo) {
            // needs bus logic to decide if null date is < non null date or vice-versa
            TransactionWrapper compareToTr = (TransactionWrapper) compareTo;
            if (tr.Transaction_Date__c > compareToTr.tr.Transaction_Date__c) return +1;
            if (tr.Transaction_Date__c < compareToTr.tr.Transaction_Date__c) return -1;
            return 0;
        } 
    }
}