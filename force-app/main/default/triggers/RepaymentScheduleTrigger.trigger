trigger RepaymentScheduleTrigger on Repayment_Schedule__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
    // System.debug('RepaymentScheduleTrigger');
    // if (Trigger.isUpdate || Trigger.isInsert) {
    //     Set<String> fields = new Set<String>(); 
    //     Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get('sfims__Repayment_Schedule__c').getDescribe().fields.getMap();
    //     Set<String> fieldsToIgnore = new Set<String>{
    //         'id',
    //         'ownerid',
    //         'createddate',
    //         'createdbyid',
    //         'lastmodifieddate',
    //         'lastmodifiedbyid',
    //         'systemmodstamp',
    //         'lastactivitydate',
    //         'lastvieweddate',
    //         'lastreferenceddate'
    //     };
    //     fields = new Set<String>();
    //     for (String field : fieldsMap.keySet()) {
    //         if (!fieldsToIgnore.contains(field)) fields.add(String.valueOf(fieldsMap.get(field)));
    //     }
            
    //     for (Integer i = 0; i < Trigger.new.size(); i++) {
    //         Repayment_Schedule__c rs = Trigger.new[i];
    //         System.debug('NUMBER OF SCHEDULE: ' + i);
    //         for (String field : fields) {
    //             System.debug(field + ' : ' + rs.get(field));
    //         }
    //     }
    // }

    if (Trigger.isBefore && Trigger.isInsert) {
        System.debug('RepaymentScheduleTrigger.Trigger.isBefore && Trigger.isInsert');
        updateFields(Trigger.new, null);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        System.debug('RepaymentScheduleTrigger.Trigger.isAfter && Trigger.isInsert');
        //-----Syncs to the corresponding Transaction record------------------------------------------------------------
        List<Transaction__c> transactionsToUpsert = new List<Transaction__c>();
        for (Repayment_Schedule__c rs : Trigger.new) {
            transactionsToUpsert.add(mapScheduleToTransaction(rs, null));
        }

        insert transactionsToUpsert;
        //--------------------------------------------------------------------------------------------------------------

        runValidations(Trigger.newMap, null);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        System.debug('RepaymentScheduleTrigger.Trigger.isBefore && Trigger.isUpdate');
        updateFields(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        System.debug('RepaymentScheduleTrigger.Trigger.isAfter && Trigger.isUpdate');
        //-----Syncs to the corresponding Transaction record------------------------------------------------------------
        List<Transaction__c> transactionsToUpsert = new List<Transaction__c>();
        Map<Id,Id> scheduleIdToExistingTransactionId = new Map<Id,Id>();
        // fetch existing transactions (for update)
        for (Transaction__c t : [SELECT Id, Repayment_Schedule__c FROM Transaction__c WHERE Repayment_Schedule__c IN :Trigger.newMap.keySet()]) {
            scheduleIdToExistingTransactionId.put(t.Repayment_Schedule__c, t.Id);
        }
        // System.debug(scheduleIdToExistingTransactionId);
        if (!scheduleIdToExistingTransactionId.isEmpty()) {
            for (Repayment_Schedule__c rs : Trigger.new) {
                transactionsToUpsert.add(mapScheduleToTransaction(rs, scheduleIdToExistingTransactionId.get(rs.Id)));
            }
            // System.debug(transactionsToUpsert);

            update transactionsToUpsert;
        }
        
        //--------------------------------------------------------------------------------------------------------------

        runValidations(Trigger.newMap, Trigger.oldMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        System.debug('RepaymentScheduleTrigger.Trigger.isBefore && Trigger.isDelete');
        //-----Syncs to the corresponding Transaction record------------------------------------------------------------
        delete [SELECT Id FROM Transaction__c WHERE Repayment_Schedule__c IN :Trigger.oldMap.keySet()];
        //--------------------------------------------------------------------------------------------------------------
    }
    
    
    /**
     * @description         Runs some validations to ensure data consistency etc
     *                      In the package we prefer this over validation rules to prevent namespacing issues
     */
    private void runValidations(Map<Id,Repayment_Schedule__c> newSchedulesMap, Map<Id,Repayment_Schedule__c> oldSchedulesMap){
        System.debug('RepaymentScheduleTrigger.runValidations');
        // gather investment data
        Map<Id,Investment__c> investmentIdToInvestment = new Map<Id,Investment__c>();
        for(Repayment_Schedule__c rs : newSchedulesMap.values()){
            if(rs.Fund__c != null){
                if(!investmentIdToInvestment.containsKey(rs.Loan__c))
                    investmentIdToInvestment.put(rs.Loan__c,null);
            }
        }
        if(!investmentIdToInvestment.isEmpty()){
            for(Investment__c inv : [Select Id, Loan_Fund__c From Investment__c Where Id in :investmentIdToInvestment.keySet()]){
                investmentIdToInvestment.put(inv.Id,inv);
            }
        }

        // do checks
        for(Repayment_Schedule__c rs : newSchedulesMap.values()){
            if(rs.Fund__c != null && rs.Fund__c != investmentIdToInvestment.get(rs.Loan__c).Loan_Fund__c){
                rs.Fund__c.addError(System.Label.sfims.error_message_46);
            }
        }
    }    

    /**
     * @description         Automatically update fields on schedule
     */
    private void updateFields(List<Repayment_Schedule__c> newSchedules, Map<Id,Repayment_Schedule__c> oldSchedulesMap){
        System.debug('RepaymentScheduleTrigger.updateFields');
        // collect fund info
        Map<Id,Id> investmentIdToFundId = new Map<Id,Id>();
        Map<Id,Decimal> investmentIdToLateRepaymentFixedFee = new Map<Id,Decimal>();
        for (Repayment_Schedule__c rs : newSchedules){
            if (oldSchedulesMap == null || rs.Loan__c != oldSchedulesMap.get(rs.Id).Loan__c){
                investmentIdToFundId.put(rs.Loan__c, null);
            }
            investmentIdToLateRepaymentFixedFee.put(rs.Loan__c, null);
        }
        if (!investmentIdToLateRepaymentFixedFee.isEmpty()){
            for(Investment__c inv : [SELECT Loan_Fund__c, Late_Repayment_Calculation_Method__c, Late_Repayment_Fixed_Fee__c 
                FROM Investment__c WHERE Id IN :investmentIdToLateRepaymentFixedFee.keySet() AND Open_Ended_Loan__c = FALSE])
            {
                if (investmentIdToFundId.containsKey(inv.Id)) investmentIdToFundId.put(inv.Id,inv.Loan_Fund__c);
                
                if (inv.Late_Repayment_Calculation_Method__c == 'Fixed Fee') 
                    investmentIdToLateRepaymentFixedFee.put(inv.Id,inv.Late_Repayment_Fixed_Fee__c);
                
            }
        }

        for (Repayment_Schedule__c rs : newSchedules){
            if (rs.Status__c != 'Grace' && rs.Status__c != 'Fee' && rs.Status__c != 'Defaulted' && rs.Status__c != 'Planned') {
                // set correct status & dates
                if (rs.Last_Paid_Date__c == null){
                    // Nothing Paid
                    if (rs.Due_Date__c > system.today()){
                        rs.Status__c = 'Not Due';
                        rs.Repaid_Date__c = null;
                    } else {
                        rs.Status__c = 'Late';
                        rs.Repaid_Date__c = null;
                    }
                } else if (rs.Last_Paid_Date__c != null && rs.Total_Remaining__c > 0){
                    // Partially Paid
                    if (rs.Due_Date__c == rs.Last_Paid_Date__c) {
                        rs.Status__c = 'Partially Paid (On Time)';
                        rs.Repaid_Date__c = null;
                    } else if (rs.Due_Date__c > rs.Last_Paid_Date__c){
                        rs.Status__c = 'Partially Paid (Early)';
                        rs.Repaid_Date__c = null;
                    } else {
                        rs.Status__c = 'Partially Paid (Late)';
                        rs.Repaid_Date__c = null;
                    }                
                } else {
                    if (rs.Last_Paid_Date__c == rs.Due_Date__c){
                        rs.Status__c = 'Paid (On Time)';
                        rs.Repaid_Date__c = rs.Last_Paid_Date__c;
                    } else if (rs.Last_Paid_Date__c < rs.Due_Date__c){
                        rs.Status__c = 'Paid (Early)';
                        rs.Repaid_Date__c = rs.Last_Paid_Date__c;                    
                    } else if (rs.Last_Paid_Date__c > rs.Due_Date__c){
                        rs.Status__c = 'Paid (Late)';
                        rs.Repaid_Date__c = rs.Last_Paid_Date__c;                    
                    }
                }

                // set fund (copy from investment)
                if(investmentIdToFundId.containsKey(rs.Loan__c)){
                    rs.Fund__c = investmentIdToFundId.get(rs.Loan__c);
                }

                if (rs.Active__c && rs.Late_Repayment_Fixed_Fee__c == null && rs.Total_Remaining__c > 0
                    && rs.Due_Date_with_Tolerance_Period__c < System.today() 
                    && investmentIdToLateRepaymentFixedFee.containsKey(rs.Loan__c)) 
                {
                    rs.Late_Repayment_Fixed_Fee__c = investmentIdToLateRepaymentFixedFee.get(rs.Loan__c);
                }
                    
                // set amount due fields (if schedule is due). There is also a batch job that does this, but by adding it to the trigger we make sure that it is also immediately set
                // upon creation/update of the record
                if(rs.Due_Date__c < System.today()){
                    if (rs.Principal_Due__c != rs.Principal_Expected__c) rs.Principal_Due__c = rs.Principal_Expected__c;
                    if (rs.Interest_Due__c != rs.Interest_Expected_Standard_Loan__c) rs.Interest_Due__c = rs.Interest_Expected_Standard_Loan__c;
                    if (rs.Fees_Due__c != rs.Fees_Expected__c) rs.Fees_Due__c = rs.Fees_Expected__c;
                    if (rs.Late_Repayment_Fees_Due__c != rs.Late_Repayment_Fees_Expected0__c) rs.Late_Repayment_Fees_Due__c = rs.Late_Repayment_Fees_Expected0__c;                
                }
            }    
        }
        System.debug('RepaymentScheduleTrigger.updateFields.END');
    }    
 
    public Transaction__c mapScheduleToTransaction(Repayment_Schedule__c rs,Id transactionId){
        Id recordTypeId = Schema.Sobjecttype.Transaction__c.getRecordTypeInfosByName().get('Investment Transaction').getRecordTypeId();
        return new Transaction__c(
            Id = transactionId,
            RecordTypeId = recordTypeId,
            Amount_Original__c = rs.Total_Expected__c,
            Amount__c = rs.Total_Remaining__c,
            Fund__c = rs.Fund__c,
            Interest_Amount__c = rs.Interest_Remaining__c,
            Interest_Amount_Original__c = rs.Interest_Expected0__c,
            Investment_Reporting__c = rs.Loan__c,
            Object_Type__c = 'Repayment Schedule',
            Principal_Amount__c = rs.Principal_Remaining__c,
            Principal_Amount_Original__c = rs.Principal_Expected__c,
            Repayment_Schedule__c = rs.Id,
            Transaction_Date__c = rs.Due_Date__c,
            Type__c = 'Schedule ('+rs.Status__c+')',
            Status__c = 'Planned'
        );
    }    
}