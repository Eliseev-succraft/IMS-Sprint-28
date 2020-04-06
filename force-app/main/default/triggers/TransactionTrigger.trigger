trigger TransactionTrigger on Transaction__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        System.debug('TransactionTrigger.Trigger.isBefore && Trigger.isInsert');
        setDefaultFields(Trigger.new);
        runValidations(Trigger.new, null);
        updateFields(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        System.debug('TransactionTrigger.Trigger.isAfter && Trigger.isInsert');
        new TransactionTriggerHandler().processTransactions(Trigger.newMap, null);
        populateFundFields(Trigger.newMap, null);
        updateInvestmentFields(Trigger.new, null);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        System.debug('TransactionTrigger.Trigger.isBefore && Trigger.isUpdate');
        runValidations(Trigger.new, Trigger.oldMap);
        updateFields(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        System.debug('TransactionTrigger.Trigger.isAfter && Trigger.isUpdate');
        new TransactionTriggerHandler().processTransactions(Trigger.newMap, Trigger.oldMap);
        populateFundFields(Trigger.newMap, Trigger.oldMap);
        updateInvestmentFields(Trigger.new, Trigger.old);
    }
    
    if (Trigger.isBefore && Trigger.isDelete) {
        System.debug('TransactionTrigger.Trigger.isBefore && Trigger.isDelete');
        if (!Utility.executeFromDeleteMethodOfInvestmentTrigger) runDeleteValidations();
    }
    
    if (Trigger.isAfter && Trigger.isDelete) {
        System.debug('TransactionTrigger.Trigger.isAfter && Trigger.isDelete');
        if (!Utility.executeFromDeleteMethodOfInvestmentTrigger) deleteTransactionsRelatedToLoanEvents(Trigger.old);
        if (!Utility.executeFromDeleteMethodOfInvestmentTrigger) new TransactionTriggerHandler().processTransactions(null, Trigger.oldMap);
        populateFundFields(null, Trigger.oldMap);
        if (!Utility.executeFromDeleteMethodOfInvestmentTrigger) updateInvestmentFields(null, Trigger.old); 
    }

    /**
     * @description         Automatically set default values for some fields on the transaction
     */
    public void setDefaultFields(List<Transaction__c> newTransactions){
        // collect fund info
        Map<Id,Investment__c> investmentIdToInvestment = new Map<Id,Investment__c>();
        for (Transaction__c tr : newTransactions){
            // set default object type (if not filled by user)
            if (tr.Object_Type__c == null) tr.Object_Type__c = 'Transaction';
            // set investment reporting field if investment is filled
            if (tr.Investment__c != null) tr.Investment_Reporting__c = tr.Investment__c;

            // gather investment (for setting the correct fund) if new transaction or investment changed. 
            if (tr.Investment_Reporting__c != null){
                if (!investmentIdToInvestment.containsKey(tr.Investment_Reporting__c))
                    investmentIdToInvestment.put(tr.Investment_Reporting__c,null);
            } 
        }
        if (!investmentIdToInvestment.isEmpty()){
            for (Investment__c inv : [SELECT Id, Account__c, Loan_Fund__c, Loan_Product__r.Repayment_Allocation_Order__c 
                FROM Investment__c WHERE Id IN :investmentIdToInvestment.keySet()]){
                investmentIdToInvestment.put(inv.Id,inv);
            }
        }
        for (Transaction__c tr : newTransactions){
            // set fund (copy from investment)
            if (investmentIdToInvestment.containsKey(tr.Investment_Reporting__c)){
                Investment__c inv = investmentIdToInvestment.get(tr.Investment_Reporting__c);
                tr.Fund__c = inv.Loan_Fund__c;
                if (String.isBlank(tr.Repayment_Allocation_Order__c)) tr.Repayment_Allocation_Order__c = inv.Loan_Product__r.Repayment_Allocation_Order__c;
                if (tr.Object_Type__c == 'Transaction') tr.Account__c  = inv.Account__c;
            }
        }
    } 

    /**
     * @description         Automatically update fields on transaction
     */
    public void updateFields(List<Transaction__c> newTransactions){
        for(Transaction__c tr : newTransactions){
            // set Original Amounts (if not filled by user)
            if(tr.Amount_Original__c != tr.Amount__c) tr.Amount_Original__c = tr.Amount__c;
            if(tr.Interest_Amount_Original__c != tr.Interest_Amount__c) tr.Interest_Amount_Original__c = tr.Interest_Amount__c;
            if(tr.Principal_Amount_Original__c != tr.Principal_Amount__c) tr.Principal_Amount_Original__c = tr.Principal_Amount__c;

        }
    }

    /**
     * @description         Runs some validations to ensure data consistency etc
     *                      In the package we prefer this over validation rules to prevent namespacing issues
     */
    public void runValidations(List<Transaction__c> newTransactions, Map<Id,Transaction__c> oldTransactionsMap){
        Map<Id,List<Transaction__c>> investmentIdToTransactions = new Map<Id,List<Transaction__c>>();
        Map<Id,List<Transaction__c>> investmentIdToTransactionsV0 = new Map<Id,List<Transaction__c>>();
        Map<Id,List<Transaction__c>> investmentIdToTransactionsV1 = new Map<Id,List<Transaction__c>>();
        Map<Id,List<Transaction__c>> investmentIdToTransactionsV2 = new Map<Id,List<Transaction__c>>();
        for (Transaction__c tr : newTransactions){
            if (tr.Investment__c != null) {
                if (!investmentIdToTransactions.containsKey(tr.Investment__c))
                        investmentIdToTransactions.put(tr.Investment__c, new List<Transaction__c>());
                    investmentIdToTransactions.get(tr.Investment__c).add(tr);

                if (tr.Type__c == 'Repayment') {
                    if (Trigger.isInsert) {
                        if (FeatureManagement.checkPermission('Enter_Repayments')) {
                            if (tr.Amount__c < 0 && !FeatureManagement.checkPermission('Apply_Loan_Adjustments')) {
                                tr.addError(System.Label.sfims.error_message_69);
                                continue;
                            }
                        } else {
                            tr.addError(System.Label.sfims.error_message_68);
                            continue;
                        }
                    }      
                    
                    if (tr.Status__c == 'Received') {
                        if (!investmentIdToTransactionsV0.containsKey(tr.Investment__c))
                            investmentIdToTransactionsV0.put(tr.Investment__c, new List<Transaction__c>());
                        investmentIdToTransactionsV0.get(tr.Investment__c).add(tr);
                    }     
                }
                
                if (oldTransactionsMap == null || tr.Investment__c != oldTransactionsMap.get(tr.Id).Investment__c) {
                    if (!investmentIdToTransactionsV1.containsKey(tr.Investment__c))
                        investmentIdToTransactionsV1.put(tr.Investment__c, new List<Transaction__c>());
                    investmentIdToTransactionsV1.get(tr.Investment__c).add(tr);
                }

                // repayment allocation order validations
                if (oldTransactionsMap != null && tr.Repayment_Allocation_Order__c != oldTransactionsMap.get(tr.Id).Repayment_Allocation_Order__c) {
                    
                    if (tr.Repayment_Allocation_Order__c != null) {
                        Boolean invalid = false;
                        if (tr.Repayment_Allocation_Order__c.indexOf(';') == -1) {
                            invalid = true;
                        } else {
                            List<String> stringList = tr.Repayment_Allocation_Order__c.split(';');
                            if (stringList.size() != 4) {invalid = true;}
                            else {
                                Integer feesNumber = 0;
                                Integer interestNumber = 0;
                                Integer lateRepaymentFeesNumber = 0;
                                Integer principalNumber = 0;
                                for (String str : stringList) {
                                    switch on str {
                                        when 'Fees' {
                                            feesNumber++;
                                        }
                                        when 'Interest' {
                                            interestNumber++;
                                        }
                                        when 'Late Repayment Fees' {
                                            lateRepaymentFeesNumber++;
                                        }
                                        when 'Principal' {
                                            principalNumber++;
                                        }
                                    }
                                }
                                if (feesNumber != 1 || interestNumber != 1 || lateRepaymentFeesNumber != 1 || principalNumber != 1) {
                                    invalid = true;
                                }
                            } 
                        }
                        
                        if (invalid) tr.addError(System.Label.sfims.error_message_48);    

                    } else {
                        tr.addError(System.Label.sfims.error_message_49);
                    }
                    
                    if (!investmentIdToTransactionsV2.containsKey(tr.Investment__c))
                        investmentIdToTransactionsV2.put(tr.Investment__c, new List<Transaction__c>());
                    investmentIdToTransactionsV2.get(tr.Investment__c).add(tr);
                }
            }    
        }
        if (!investmentIdToTransactions.isEmpty()){
            // prevent anybody (except admin) from manually editing the transactions            
            preventFromManuallyEditing(investmentIdToTransactions);
        }

        if (!investmentIdToTransactionsV0.isEmpty()){
            // prevent from inserting / editing of repayment transactions that were applied before the reschedule/disbursement loan event
            preventFromSavingAndDeletionOfRepaymentsBeforeLoanEvent(investmentIdToTransactionsV0);
        }

        if (!investmentIdToTransactionsV1.isEmpty()){
            // prevent entering transactions when no schedule is generated yet
            preventEnteringTransactions(investmentIdToTransactionsV1);
        }

        if (!investmentIdToTransactionsV2.isEmpty()){
            // block updating Repayment Allocation Order if Repayment Allocation Type 'Loan-based' on the Loan Product level is selected             
            validateRepaymentAllocationOrder(investmentIdToTransactionsV2);
        }
    }

    public void preventFromManuallyEditing(Map<Id,List<Transaction__c>> investmentIdToTransactions){
        System.debug('TransactionTrigger.preventFromManuallyEditing');
        for (Investment__c inv : [SELECT Id FROM Investment__c WHERE Id IN :investmentIdToTransactions.keySet() AND RecordTypeId = :Utility.loanRecordTypeId]) {
            for (Transaction__c tr : investmentIdToTransactions.get(inv.Id)) {
                if (tr.Type__c == 'Disbursement' && tr.Status__c == 'Disbursed' && !tr.Created_Using_The_Disburse_Button__c && !Utility.currentUserIsAdmin) 
                    tr.addError(System.Label.sfims.error_message_50);

                if (tr.Type__c == 'Disbursement' && tr.Status__c == 'Disbursed' && tr.Created_Using_The_Disburse_Button__c) 
                    tr.Created_Using_The_Disburse_Button__c = false;
            }
        }
    }

    public void preventFromSavingAndDeletionOfRepaymentsBeforeLoanEvent(Map<Id,List<Transaction__c>> investmentIdToTransactions) {
        System.debug('TransactionTrigger.preventFromSavingAndDeletionOfRepaymentsBeforeLoanEvent');
        Set<String> fields = new Set<String>();
        if (Trigger.isUpdate) { 
            Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get('sfims__Transaction__c').getDescribe().fields.getMap();
            Set<String> fieldsToIgnore = new Set<String>{
                'id',
                'ownerid',
                'isdeleted',
                'name',
                'createddate',
                'createdbyid',
                'lastmodifieddate',
                'lastmodifiedbyid',
                'systemmodstamp',
                'lastactivitydate',
                'lastvieweddate',
                'lastreferenceddate',
                'sfims__fee_amount__c',
                'sfims__interest_amount__c',
                'sfims__late_repayment_fee_amount__c',
                'sfims__principal_amount__c',
                'sfims__principal_balance__c'
            };
            fields = new Set<String>();
            for (String field : fieldsMap.keySet()) {
                if (!fieldsToIgnore.contains(field)) fields.add(String.valueOf(fieldsMap.get(field)));
            }
        }
        for (Investment__c inv : [SELECT Id, (SELECT Event_Date__c, CreatedDate FROM Loan_Events__r 
            WHERE Loan_Event_Type__c IN ('Disbursement', 'Reschedule') ORDER BY Event_Date__c DESC LIMIT 1) 
            FROM Investment__c WHERE Id IN :investmentIdToTransactions.keySet() AND RecordTypeId = :Utility.loanRecordTypeId])
        {
            if (!inv.Loan_Events__r.isEmpty()) {
                Loan_Event__c le = inv.Loan_Events__r[0];
                Integer i = 0;
                for (Transaction__c tr : investmentIdToTransactions.get(inv.Id)) {
                    Boolean changed = false;
                    if (Trigger.isUpdate) {
                        for (String field : fields) {
                            if (Trigger.newMap.get(tr.Id).get(field) != Trigger.oldMap.get(tr.Id).get(field)) {
                                changed = true;
                                break;
                            }
                        }
                    }
                    if (((Trigger.isUpdate && changed) || !Trigger.isUpdate) && (tr.Transaction_Date__c < le.Event_Date__c 
                        || (tr.Transaction_Date__c == le.Event_Date__c && tr.CreatedDate < le.CreatedDate))) 
                    {
                        tr.addError(System.Label.sfims.error_message_66);
                    }
                }    
            }
        }
    }
    
    public void preventEnteringTransactions(Map<Id,List<Transaction__c>> investmentIdToTransactions){
        for (Investment__c inv : [SELECT Recalculation_Status__c, Status__c,(SELECT Id FROM Repayment_Schedules__r LIMIT 1) 
            FROM Investment__c WHERE Id IN :investmentIdToTransactions.keySet() AND RecordTypeId = :Utility.loanRecordTypeId])
        {
            if (inv.Recalculation_Status__c == 'Pending Recalculation' || inv.Recalculation_Status__c == 'In Progress') {
                addErrorToTransactions(investmentIdToTransactions.get(inv.Id), System.Label.sfims.part_of_error_message_14);
            }
            switch on inv.Status__c {
                when 'Closed - All Obligations Met', 'Closed - Written Off', 'Closed - Early Repayment', 'Closed' {
                    addErrorToTransactions(investmentIdToTransactions.get(inv.Id), System.Label.sfims.part_of_error_message_15);
                }
            }
            if (inv.Repayment_Schedules__r.isEmpty()) {
                addErrorToTransactions(investmentIdToTransactions.get(inv.Id), System.Label.sfims.part_of_error_message_16);
            }
        }
    }

    public void addErrorToTransactions(List<Transaction__c> transactions, String errorMessage) {
        for (Transaction__c tr : transactions) {
            tr.addError(System.Label.sfims.part_of_error_message_17 + ' ' + errorMessage);
        }
    }

    public void validateRepaymentAllocationOrder(Map<Id,List<Transaction__c>> investmentIdToTransactions){
        for (Investment__c inv : [SELECT Loan_Product__r.Repayment_Allocation_Type__c
            FROM Investment__c WHERE Id IN :investmentIdToTransactions.keySet()])
        {
            if (inv.Loan_Product__r.Repayment_Allocation_Type__c == 'Loan-based') {
                for (Transaction__c tr : investmentIdToTransactions.get(inv.Id)) {
                    tr.Repayment_Allocation_Order__c.addError(System.Label.sfims.error_message_51);
                }
            }
        }
    }
    
    /**
     * @description         Populate fields of the Fund record associated with the current Transaction.
     */  
    public void populateFundFields(Map<Id,Transaction__c> newTransactionsMap, Map<Id,Transaction__c> oldTransactionsMap){
        Set<Id> fundIds = new Set<Id>();
        if (newTransactionsMap == null) newTransactionsMap = oldTransactionsMap;
        for (Transaction__c tr : newTransactionsMap.values()) {
            if (tr.Fund__c != null) {
                switch on tr.Type__c {
                    when 'Disbursement', 'Repayment', 'Fund Drawdown', 'Fund Repayment' {
                        fundIds.add(tr.Fund__c);
                    }
                }    
            }
        }
        if (fundIds.size() > 0) {
            Database.executeBatch(new PopulateFundFieldsBatch(fundIds), 1000);
        }

        /*
        Map<Id, Fund__c> fundIdToFund = new Map<Id, Fund__c>();
        if (!fundIds.isEmpty()) {
            AggregateResult[] results = [
                SELECT Fund__c, Type__c, SUM(Amount__c)amount, SUM(Fund_Cashflow_Amount__c)fundCashflowAmount,
                    SUM(Interest_Amount__c)interestRepaid, SUM(Fee_Amount__c)feeRepaid, SUM(Late_Repayment_Fee_Amount__c)penaltiesRepaid
                FROM Transaction__c
                WHERE Type__c IN ('Disbursement', 'Repayment', 'Fund Drawdown', 'Fund Repayment') AND Fund__c IN :fundIds
                GROUP BY Fund__c, Type__c
            ];
            for (AggregateResult ar : results)  {
                System.debug(ar);
                
                Id fundId = (Id)ar.get('sfims__Fund__c');
                Fund__c f = new Fund__c();
                if (fundIdToFund.containsKey(fundId)) {
                    f = fundIdToFund.get(fundId);
                } else {
                    f.Id = fundId;
                    f.Fund_Balance__c = 0;
                    f.Total_Fund_Repayments__c = 0;
                }
                
                switch on (String)ar.get('sfims__Type__c') {
                    when 'Disbursement' {
                        f.Investment_Principal_Disbursed__c = (Decimal)ar.get('amount');
                    }
                    when 'Repayment' {
                        f.Total_Fund_Repayments__c += (Decimal)ar.get('amount');  
                        f.Interest_Repaid__c = (Decimal)ar.get('interestRepaid');
                        f.Fees_Paid__c = (Decimal)ar.get('feeRepaid');
                        f.Penalties_Paid__c = (Decimal)ar.get('penaltiesRepaid');
                    }
                    when 'Fund Drawdown' {
                        f.Total_Draw_Down__c = (Decimal)ar.get('amount');
                    }
                    when 'Fund Repayment' {
                        f.Total_Fund_Repayments__c += (Decimal)ar.get('amount');
                    }
                }

                f.Fund_Balance__c += (Decimal)ar.get('fundCashflowAmount');
                fundIdToFund.put(fundId, f);
            }     
        }

        if (!fundIdToFund.isEmpty()) update fundIdToFund.values();
        */
    }

    /**
     * @description         This method updates investment fields when the first 'disbursement' transaction is saved.
     */ 
    public void updateInvestmentFields(List<Transaction__c> newTransactions, List<Transaction__c> oldTransactions){
        // gather investment data
        Set<Id> investmentIds = new Set<Id>();
        if (newTransactions == null) newTransactions = oldTransactions;
           
        for (Transaction__c tr : newTransactions) {
            if (tr.Type__c == 'Disbursement' && tr.Investment__c != null) {
                investmentIds.add(tr.Investment__c);
            }              
        }

        List<Investment__c> investmentsToUpdate = new List<Investment__c>();
        if (!investmentIds.isEmpty()){
            for (Investment__c inv : [SELECT Disbursed_Amount__c, Planned_Disbursement_Amount__c, Disbursement_Date__c, 
                Status__c, Disbursement_Method__c, (SELECT Amount__c, Status__c, Transaction_Date__c 
                FROM Transactions__r WHERE Type__c = 'Disbursement' ORDER BY Transaction_Date__c ASC) 
                FROM Investment__c WHERE Id IN :investmentIds])
            {   
                Decimal disbursedAmount = 0;
                Decimal plannedDisbursementAmount = 0;
                Boolean isChanged = false;

                // calculate disbursed and planned amount
                List<Transaction__c> disbursedTransactions = new List<Transaction__c>();
                if (!inv.Transactions__r.isEmpty()) {                  
                    for (Transaction__c tr : inv.Transactions__r) {
                        if (tr.Status__c == 'Disbursed') {
                            disbursedAmount += tr.Amount__c;
                            disbursedTransactions.add(tr);
                        }
                        if (tr.Status__c == 'Planned' && inv.Disbursement_Method__c == 'Tranched disbursement allowed') 
                            plannedDisbursementAmount += tr.Amount__c;
                    }

                    // if there is any disbursement on the loan, the status must be 'Active' 
                    if (inv.Status__c != 'Active' && !disbursedTransactions.isEmpty()) {
                        inv.Status__c = 'Active';
                        isChanged = true;
                        // the Disbursement Date on the loan should be equal to the Transaction Date of the first disbursed transaction
                        if (inv.Disbursement_Date__c != disbursedTransactions[0].Transaction_Date__c) 
                            inv.Disbursement_Date__c = disbursedTransactions[0].Transaction_Date__c;
                    }
                } 
                
                // if there are no disbursed transactions on the loan or all of them have been removed
                // the loan status must be 'Inactive'
                if (disbursedTransactions.isEmpty() && inv.Status__c == 'Active') {
                    inv.Status__c = 'Inactive';
                    isChanged = true;
                }
                
                if (inv.Disbursed_Amount__c != disbursedAmount) {
                    inv.Disbursed_Amount__c = disbursedAmount;
                    if (!isChanged) isChanged = true;
                }

                if (inv.Planned_Disbursement_Amount__c != plannedDisbursementAmount) {
                    inv.Planned_Disbursement_Amount__c = plannedDisbursementAmount;
                    if (!isChanged) isChanged = true;
                }
                
                if (isChanged) investmentsToUpdate.add(inv);
            }
        }

        if (!investmentsToUpdate.isEmpty()) update investmentsToUpdate;
    
    }

    public void runDeleteValidations() {
        Map<Id,List<Transaction__c>> investmentIdToTransactionsV0 = new Map<Id,List<Transaction__c>>();
        Map<Id,List<Transaction__c>> investmentIdToTransactionsV1 = new Map<Id,List<Transaction__c>>();
        for (Transaction__c tr : Trigger.old) {
            if (tr.Investment__c != null) {
                if (!investmentIdToTransactionsV0.containsKey(tr.Investment__c))
                        investmentIdToTransactionsV0.put(tr.Investment__c, new List<Transaction__c>());
                    investmentIdToTransactionsV0.get(tr.Investment__c).add(tr);

                if (tr.Type__c == 'Repayment' && tr.Status__c == 'Received') {
                    if (!investmentIdToTransactionsV1.containsKey(tr.Investment__c))
                        investmentIdToTransactionsV1.put(tr.Investment__c, new List<Transaction__c>());
                    investmentIdToTransactionsV1.get(tr.Investment__c).add(tr);    
                }
            }
        }
        if (!investmentIdToTransactionsV0.isEmpty()){
            // prevent anybody (except admin) from manually deleting the transactions            
            preventFromManuallyEditing(investmentIdToTransactionsV0);
        }
        if (!investmentIdToTransactionsV1.isEmpty()){
            // prevent from deletion of repayment transactions that were applied before the reschedule/disbursement loan event
            preventFromSavingAndDeletionOfRepaymentsBeforeLoanEvent(investmentIdToTransactionsV1);
        }
    }

    public void deleteTransactionsRelatedToLoanEvents(List<Transaction__c> oldTransactions){
        Set<Id> loanEventIds = new Set<Id>();
        for (Transaction__c tr : oldTransactions) {
            if (tr.Loan_Event__c != null) {
                loanEventIds.add(tr.Loan_Event__c);
            }
        }
        
        try {
            delete [SELECT Id FROM Loan_Event__c WHERE Id IN :loanEventIds];
        } catch(System.DmlException e) {
            System.debug(e.getDmlMessage(0));
            for (Transaction__c tr : oldTransactions) {
                if (tr.Loan_Event__c != null) tr.addError(System.Label.sfims.part_of_error_message_18 + ': ' + e.getDmlMessage(0));
            }
        }
    }
}