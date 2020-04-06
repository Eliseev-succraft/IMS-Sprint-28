public with sharing class RecalculateButtonController {
    
    @AuraEnabled
    public static Map<String, String> getLoanData(String loanId){
        Map<String, String> returnMap = new Map<String, String>();
        List<Investment__c> loans = [
            SELECT Status__c, Number_of_Instalments__c, Repayment_Frequency__c, Repayment_Frequency_Unit__c, Day_Count_Convention__c,
                Number_of_Grace_Periods__c, Grace_Period_Type__c, Amount__c, Capitalized_Amount__c, Capitalized_Fee_Amount__c, 
                Open_Ended_Loan__c, Interest_Rate__c, Variable_Interest_Spread__c, Disbursement_Date__c, First_Repayment_Date__c, 
                Disbursement_Method__c, Expected_End_Date__c, Setup_Fee_Charging_Method__c, Setup_Fee__c, Setup_Fee_Expected__c, 
                Percent_of_Disbursement_Amount__c, Non_Working_Days_Rescheduling__c, Monitoring_Fee_Percentage__c,
                Last_Instalment_Amount__c, Recalculation_Status__c, Recalculation_Error_Message__c, Last_Recalculation_Date__c, 
                Loan_Product__r.Interest_Rate_Source__c, Loan_Product__r.Interest_Reference_Rate__c, 
                Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c, 
                Migrated_Instalment_Amount__c, Migrated_Next_First_Repayment_Date__c, 
                Migrated_Outstanding_Capital__c, Migrated_Remaining_Grace_Periods__c
            FROM Investment__c
            WHERE Id = :loanId
        ];

        List<Loan_Event__c> loanEvents = [
            SELECT Loan_Event_Type__c, Event_Date__c, Investment__c, Amount__c, First_Repayment_Date__c, Number_of_Instalments__c,
                Grace_Period_Type__c, Number_of_Grace_Periods__c, Repayment_Frequency__c, Repayment_Frequency_Unit__c, Interest_Rate__c,  
                Fees_Written_Off__c, Interest_Written_Off__c, Late_Repayment_Fees_Written_Off__c, Principal_Written_Off__c, 
                Balloon_Repayment_Period__c, Reschedule_Type__c, Variable_Interest_Spread__c, Approval_Status__c, Instalment_Amount__c,
            (
                SELECT Amount__c
                FROM Transactions__r
            ),
            (
                SELECT Due_Date__c, Cancel_Late_Repayment_Fee__c
                FROM Loan_Event_Details__r
            )
            FROM Loan_Event__c
            WHERE Investment__c = :loanId AND Loan_Event_Type__c != 'Loan Creation'
            ORDER BY Event_Date__c, CreatedDate
        ];
        
        if (!loans.isEmpty()) returnMap.put('loan', JSON.serialize(loans[0]));
        if (!loanEvents.isEmpty()) {
            for (Loan_Event__c le : loanEvents) {
                if (le.Loan_Event_Type__c == 'Disbursement') {
                    returnMap.put('loanEvents', JSON.serialize(loanEvents));
                    break;
                }
            }
        }
        return returnMap;
    }
    
    @AuraEnabled
    public static void runRecalculationWithoutLoanEvents(String loanString){
        Investment__c theLoan = (Investment__c) JSON.deserialize(loanString, Investment__c.class);
        
        finishWithoutLoanEvents(theLoan);
    }
    
    @AuraEnabled
    public static String runRecalculationScheduler(String loanString){
        Investment__c theLoan = (Investment__c) JSON.deserialize(loanString, Investment__c.class);
        
        // String jobName = 'Recalculation Job ' + theLoan.Id;
        // List<CronTrigger> cts = [
        //     SELECT Id, CronJobDetailId
        //     FROM CronTrigger 
        //     WHERE CronJobDetail.Name = :jobName
        // ];
        // if (!cts.isEmpty()) {
        //     System.abortJob(cts[0].Id);
        // }
        
        startManualRecalculation(theLoan);
        DMLManager.deleteAsUser([SELECT Id FROM Repayment_Schedule__c WHERE Loan__c = :theLoan.Id AND Migration__c = false]);
        
        // run schedule in 30 minutes from now to prevent a case when a user has closed the browser before recalculation completed
        Datetime cronDate = System.now().addMinutes(30);
        String cronExpression = '0 ' + cronDate.minute() + ' ' + cronDate.hour() + ' ' + cronDate.day() + ' ' + cronDate.month() + ' ? ' + cronDate.year();
        return System.schedule('Recalculation Job ' + theLoan.Id, cronExpression, new RecalculationScheduler(theLoan.Id));
    }

    @AuraEnabled
    public static Map<String, String> processLoanEvent(String loanString, String loanEventsString, Integer eventNumber, String eventDate, Integer index, String jobID){
        System.debug('RecalculateButtonController.processLoanEvent');
        // Check to see whether the caller has access to this information. 
        if (!Investment__c.SObjectType.getDescribe().isAccessible()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isCreateable()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isDeletable()) { 
            throw new AuraHandledException(System.Label.sfims.error_message_30);
        }

        System.debug(loanString);
        System.debug(eventNumber);
        System.debug(eventDate);
        System.debug(index);

        Investment__c theLoan = (Investment__c) JSON.deserialize(loanString, Investment__c.class);
        List<Loan_Event__c> loanEvents = (List<Loan_Event__c>) JSON.deserialize(loanEventsString, List<Loan_Event__c>.class);
        Loan_Event__c le = loanEvents[eventNumber];
        // use savepoint to roll back if an error has been caught
        Savepoint sp = database.setSavepoint();
        Map<String, String> resultMap = new Map<String, String>();
        try {
            Date entryDate = eventDate == null ? null : Date.valueOf(eventDate);
            TransactionTriggerHandler.bypassProcessTransactions = true;
            resultMap = RecalculateLoanFromScratchBatch.processLoanEvent(theLoan, le, entryDate, index);
            if (resultMap.containsKey('loanEventToDelete')) {
                Utility.bypassLoanEventTrigger = true; 
                DMLManager.deleteAsSystem(new List<Loan_Event__c>{le});
                Utility.bypassLoanEventTrigger = false; 
            }
            System.debug(JSON.serialize(theLoan));

            System.debug('----------');
            if (eventNumber == loanEvents.size() - 1) {
                System.debug('finish');
                
                LoanTransactionProcessor.processLoanTransactions(new Set<Id>{theLoan.Id});
                TransactionTriggerHandler.bypassProcessTransactions = false;
                
                theLoan = (Investment__c) JSON.deserialize(loanString, Investment__c.class);
                finishWithSuccess(theLoan);
                System.abortJob(jobID);
            }
            
            return resultMap;

        } catch(Exception e) {
            System.debug(e.getMessage());
            theLoan = (Investment__c) JSON.deserialize(loanString, Investment__c.class);
            System.abortJob(jobID);
            finishWithError(theLoan, sp, System.Label.sfims.part_of_error_message_5 + ': ' + e.getMessage());
            throw new AuraHandledException(System.Label.sfims.part_of_error_message_5 + ': ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void recalculateOpenEndedLoan(String loanId){
        // Check to see whether the caller has access to this information. 
        if (!Investment__c.SObjectType.getDescribe().isAccessible()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isCreateable()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isDeletable()) { 
            throw new AuraHandledException(System.Label.sfims.error_message_30);
        }

        // gather the Loan data
        Investment__c theLoan = [
            SELECT Amount__c, Interest_Rate__c, Disbursement_Date__c, Capitalized_Amount__c, Capitalized_Fee_Amount__c,
                Interest_Expected_Open_Ended_Loan__c, Disbursement_Method__c, Variable_Interest_Spread__c, Loan_Product__c, 
                Loan_Product__r.Interest_Rate_Review_Frequency__c, Loan_Product__r.Interest_Reference_Rate__c, Status__c, 
                Loan_Product__r.Default_Interest_Rate__c, Loan_Product__r.Interest_Rate_Source__c, Open_Ended_Loan__c,
                Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c, 
                Loan_Product__r.Repayment_Allocation_Order__c, Recalculation_Status__c, Recalculation_Error_Message__c, Setup_Fee_Charging_Method__c,
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
            WHERE Id = :loanId
        ];

        String loanString = JSON.serialize(theLoan);

        // use savepoint to roll back if an error has been caught
        Savepoint sp = database.setSavepoint();
        try {
            if ([SELECT Id FROM Loan_Event__c WHERE Investment__c = :loanId AND Loan_Event_Type__c = 'Disbursement' LIMIT 1].isEmpty()) {
                finishWithoutLoanEvents(theLoan);
            } else {
                startManualRecalculation(theLoan);
                
                Map<String, String> resultMap = RecalculateOpenEndedLoan.processOpenEndedLoan(theLoan);
                theLoan = (Investment__c) JSON.deserialize(loanString, Investment__c.class);
                if (resultMap.containsKey('error')) {
                    System.debug(resultMap.get('error'));
                    
                    finishWithError(theLoan, sp, System.Label.sfims.part_of_error_message_5 + ': ' + resultMap.get('error'));
                } else {
                    finishWithSuccess(theLoan); 
                }
            } 
        } catch(Exception e) {
            System.debug(e.getMessage());
            finishWithError(theLoan, sp, System.Label.sfims.part_of_error_message_5 + ': ' + e.getMessage());
            throw new AuraHandledException(System.Label.sfims.part_of_error_message_5 + ': ' + e.getMessage());
        }      
    }

    public static void startManualRecalculation(Investment__c theLoan) {
        theLoan.Status__c = 'Active';
        theLoan.Recalculation_Status__c = 'Manual Recalculation';
        theLoan.Recalculation_Error_Message__c = null;
        
        DMLManager.updateAsSystem(new List<Investment__c>{theLoan});
    }

    public static void finishWithError(Investment__c theLoan, Savepoint sp, String errorMessage) {
        if (sp != null) Database.rollback(sp);
        theLoan.Recalculation_Status__c = 'Failed';
        theLoan.Recalculation_Error_Message__c = errorMessage; 
        theLoan.Last_Recalculation_Date__c = System.now();
        
        DMLManager.updateAsSystem(new List<Investment__c>{theLoan});
    }

    public static void finishWithSuccess(Investment__c theLoan) {
        theLoan.Recalculation_Status__c = 'Done';
        theLoan.Last_Recalculation_Date__c = System.now(); 
        if (!theLoan.Open_Ended_Loan__c) {
            List<Loan_Event__c> loanEvents = [
                SELECT Instalment_Amount__c 
                FROM Loan_Event__c 
                WHERE Investment__c = :theLoan.Id AND Loan_Event_Type__c IN ('Disbursement', 'Reschedule', 'Refinance') 
                ORDER BY Event_Date__c DESC, CreatedDate DESC 
                LIMIT 1
            ];
            if (!loanEvents.isEmpty()) theLoan.Last_Instalment_Amount__c = loanEvents[0].Instalment_Amount__c;
        }
        DMLManager.updateAsSystem(new List<Investment__c>{theLoan});
    }

    public static void finishWithoutLoanEvents(Investment__c theLoan) {
        theLoan.Status__c = 'Inactive';
        theLoan.Recalculation_Status__c = 'Not Needed';
        theLoan.Last_Recalculation_Date__c = null;
        theLoan.Recalculation_Error_Message__c = null;
        if (!theLoan.Open_Ended_Loan__c) theLoan.Last_Instalment_Amount__c = null; 
        
        DMLManager.updateAsSystem(new List<Investment__c>{theLoan});
        DMLManager.deleteAsUser([SELECT Id FROM Repayment_Schedule__c WHERE Loan__c = :theLoan.Id AND Migration__c = false]);
        DMLManager.deleteAsUser([SELECT Id FROM Loan_Event__c WHERE Investment__c = :theLoan.Id AND Loan_Event_Type__c != 'Loan Creation']);
    }

}