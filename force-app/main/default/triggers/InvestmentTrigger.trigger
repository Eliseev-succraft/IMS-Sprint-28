trigger InvestmentTrigger on Investment__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {

    if (Trigger.isBefore && Trigger.isInsert) {
        runValidationForLoanCreation();
        updateFields(Trigger.new, null);
    }
    
    if (Trigger.isAfter && Trigger.isInsert) {
        populateFundFields(Trigger.newMap, null);
        createMilestoneHistory(Trigger.newMap, null);
        createLoanEvent(Trigger.new);
    
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        runValidations(Trigger.new, Trigger.oldMap);
        updateFields(Trigger.new, Trigger.oldMap);
        
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        updateChildRecords(Trigger.new, Trigger.oldMap);
        populateFundFields(Trigger.newMap, Trigger.oldMap);
        createMilestoneHistory(Trigger.newMap, Trigger.oldMap);
        
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        deleteChildRecords(Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        populateFundFields(null, Trigger.oldMap);
    }

    public void runValidationForLoanCreation(){
        Map<Id, Loan_Product__c> loanProductIdToLoanProduct = new Map<Id, Loan_Product__c>();
        for (Investment__c inv : Trigger.new) {
            if (inv.RecordTypeId == Utility.loanRecordTypeId) {
                if (inv.Loan_Product__c != null) loanProductIdToLoanProduct.put(inv.Loan_Product__c, null);
                // else inv.Loan_Product__c.addError(System.Label.sfims.aura_label_64);
            }
        }

        if (!loanProductIdToLoanProduct.isEmpty()) {
            loanProductIdToLoanProduct = new Map<Id, Loan_Product__c>([
                SELECT Active__c 
                FROM Loan_Product__c
                WHERE Id IN :loanProductIdToLoanProduct.keySet()
            ]);
            for (Investment__c inv : Trigger.new) {
                if (inv.RecordTypeId == Utility.loanRecordTypeId) {
                    if (inv.Loan_Product__c != null && loanProductIdToLoanProduct.containsKey(inv.Loan_Product__c)) {
                        if (!loanProductIdToLoanProduct.get(inv.Loan_Product__c).Active__c) 
                            inv.addError(System.Label.sfims.error_message_52); 
                    }
                }
            }    
        } 
    }

    public void updateFields(List<Investment__c> newInvestments, Map<Id, Investment__c> oldInvestmentsMap){
        for (Investment__c inv : newInvestments) {
            // populate Capitalized Amount and Capitalized Fee Amount 
            if (inv.RecordTypeId == Utility.loanRecordTypeId) {
                Decimal capitalizedFeeAmount = 0;
                Decimal capitalizedAmount = 0;
                if (inv.Amount__c != null) capitalizedAmount = inv.Amount__c;

                switch on inv.Setup_Fee_Charging_Method__c {
                    when 'Capitalized' {
                        capitalizedFeeAmount = inv.Setup_Fee_Expected__c;
                        capitalizedAmount += inv.Setup_Fee_Expected__c;
                    }
                    when 'Deducted From Principal' {
                        // capitalizedFeeAmount = inv.Setup_Fee_Expected__c;
                    }
                }

                inv.Capitalized_Fee_Amount__c = capitalizedFeeAmount;
                inv.Capitalized_Amount__c = capitalizedAmount;
            } 

            // if (inv.Loan_Product__c == null) inv.addError('The Loan Product field must be populated.');
        }
    }

    public void createMilestoneHistory(Map<Id, Investment__c> newInvestmentsMap, Map<Id, Investment__c> oldInvestmentsMap){
        //-----Collect the Investment Statuses that have been changed and create new Milestone History records----------
        Map<String, String> statusMap = new Map<String, String>();
        for (String key : newInvestmentsMap.keySet()) {
            if (oldInvestmentsMap == null || newInvestmentsMap.get(key).Status__c != oldInvestmentsMap.get(key).Status__c) {
                statusMap.put(key, newInvestmentsMap.get(key).Status__c);
            }
        }
    
         //-----Get the Milestone Configuration data and put it in the map using the Stage as a key---------------
        if (!statusMap.isEmpty()) {
            Map<String, Milestone_Configuration__c> milestoneConfigurationsMap = new Map<String, Milestone_Configuration__c>();
            for (Milestone_Configuration__c tempMilestoneConfiguration : [
                SELECT Stage__c, Milestone_Name__c, Sequence__c
                FROM Milestone_Configuration__c
                WHERE Stage__c IN : statusMap.values() AND Object__c = 'Investment'
            ]) {
                milestoneConfigurationsMap.put(tempMilestoneConfiguration.Stage__c, tempMilestoneConfiguration);
            }
            
            //-----Create a new Milestone History records---------------------------------------------
            List<Milestone_History__c> milestoneHistoryList = new List<Milestone_History__c>();
            for (String key : statusMap.keySet()) {
                if (milestoneConfigurationsMap.containsKey(statusMap.get(key))) {
                    Date milestoneDate = System.today();

                    // if a loan switches to Active then the Milestone Date needs to become the Disbursement date (from Investment) 
                    if (newInvestmentsMap.get(key).RecordTypeId == Utility.loanRecordTypeId && newInvestmentsMap.get(key).Status__c == 'Active') {
                        if (newInvestmentsMap.get(key).Disbursement_Date__c != null) {
                            milestoneDate = newInvestmentsMap.get(key).Disbursement_Date__c;
                        } else {
                            newInvestmentsMap.get(key).Disbursement_Date__c.addError(System.Label.sfims.error_message_43);
                        }
                        
                    }
                    
                    milestoneHistoryList.add(new Milestone_History__c(
                        Milestone_Date__c = milestoneDate,
                        Milestone__c = milestoneConfigurationsMap.get(statusMap.get(key)).Milestone_Name__c,
                        Sequence__c = milestoneConfigurationsMap.get(statusMap.get(key)).Sequence__c,
                        Investment__c = key,
                        Application__c = newInvestmentsMap.get(key).Application__c
                    ));
                }
            }

            if (!milestoneHistoryList.isEmpty()) {
                try {
                    insert milestoneHistoryList;
                } catch(System.DmlException e) {
                    System.debug(e.getDmlMessage(0));
                    for (String key : statusMap.keySet()) {
                        newInvestmentsMap.get(key).addError(System.Label.sfims.part_of_error_message_9 + ': ' + e.getDmlMessage(0));
                    }
                }
            }
        }
    }

    public void updateChildRecords(List<Investment__c> newInvestments, Map<Id, Investment__c> oldInvestmentsMap){
        List<SObject> sobjectList = new List<SObject>();
        //-----Updates data on child records where necessary------------------------------------------------------------
        // update Child Records
        Map<Id,Id> investmentIdToNewFundId = new Map<Id,Id>();
        Map<Id,Id> investmentIdToNewAccountId = new Map<Id,Id>();
        for (Investment__c i : newInvestments) {
            if (i.Loan_Fund__c != oldInvestmentsMap.get(i.Id).Loan_Fund__c) {
                investmentIdToNewFundId.put(i.Id, i.Loan_Fund__c);
            }
            if (i.Account__c != oldInvestmentsMap.get(i.Id).Account__c) {
                investmentIdToNewAccountId.put(i.Id, i.Account__c);
            }
        }
        // System.debug(investmentIdToNewFundId);
        // System.debug(investmentIdToNewAccountId);

        Map<Id, Transaction__c> transactionMap = new Map<Id, Transaction__c>();
        if (!investmentIdToNewFundId.isEmpty()) {
            // update schedules
            for (Repayment_Schedule__c rs : [SELECT Id, Fund__c, Loan__c FROM Repayment_Schedule__c WHERE Loan__c IN :investmentIdToNewFundId.keySet()]) {
                if (rs.Fund__c != investmentIdToNewFundId.get(rs.Loan__c)) {
                    System.debug(rs);
                    rs.Fund__c = investmentIdToNewFundId.get(rs.Loan__c);
                    sobjectList.add(rs);
                    System.debug(rs);
                }
            }

            // update transaction Fund__c
            for (Transaction__c tr : [SELECT Id, Fund__c, Account__c, Investment_Reporting__c FROM Transaction__c WHERE Investment_Reporting__c IN :investmentIdToNewFundId.keySet()]) {
                if (tr.Fund__c != investmentIdToNewFundId.get(tr.Investment_Reporting__c)) {
                    tr.Fund__c = investmentIdToNewFundId.get(tr.Investment_Reporting__c);
                    transactionMap.put(tr.Id, tr);
                }
            }
        }
        if (!investmentIdToNewAccountId.isEmpty()) {
            // update progress reports
            for (Progress_Report__c pr : [SELECT Id, Organisation__c, Investment__c FROM Progress_Report__c WHERE Investment__c IN :investmentIdToNewAccountId.keySet()]) {
                if (pr.Organisation__c != investmentIdToNewAccountId.get(pr.Investment__c)) {
                    pr.Organisation__c = investmentIdToNewAccountId.get(pr.Investment__c);
                    sobjectList.add(pr);
                }
            }

            // update transactions Account__c
            for (Transaction__c tr : [SELECT Id, Account__c, Investment_Reporting__c FROM Transaction__c WHERE Object_Type__c = 'Transaction' AND Investment_Reporting__c IN :investmentIdToNewAccountId.keySet()]) {
                if (tr.Account__c != investmentIdToNewAccountId.get(tr.Investment_Reporting__c)) {
                    if (transactionMap.containsKey(tr.Id)) {
                        transactionMap.get(tr.Id).Account__c = investmentIdToNewAccountId.get(tr.Investment_Reporting__c);
                    } else {
                        tr.Account__c = investmentIdToNewAccountId.get(tr.Investment_Reporting__c);
                        transactionMap.put(tr.Id, tr);
                    }
                }
            }
        }
        if (!transactionMap.isEmpty()) {
            sobjectList.addAll(transactionMap.values());
        }
        //--------------------------------------------------------------------------------------------------------------

        if (!sobjectList.isEmpty()) {
            update sobjectList;
        }
    }

    public void createLoanEvent(List<Investment__c> newInvestments){
        //create a new Loan Event                     
        List<Loan_Event__c> loanEvents = new List<Loan_Event__c>();
        for (Investment__c temp : newInvestments) {
            if (temp.RecordTypeId == Utility.loanRecordTypeId) {
                loanEvents.add(new Loan_Event__c(
                    Amount__c = temp.Amount__c,
                    Event_Date__c = System.today(),                     
                    Grace_Period_Type__c = temp.Grace_Period_Type__c,
                    First_Repayment_Date__c = temp.First_Repayment_Date__c,
                    Number_of_Grace_Periods__c = temp.Number_of_Grace_Periods__c,              
                    Interest_Rate__c = temp.Interest_Rate__c,               
                    Investment__c = temp.Id,
                    Loan_Event_Type__c = 'Loan Creation',
                    Loan_Product__c = temp.Loan_Product__c,
                    Number_of_Instalments__c = temp.Number_of_Instalments__c,                   
                    Repayment_Frequency__c = temp.Repayment_Frequency__c
        		));
            }          
        }
        if (!loanEvents.isEmpty()) {
            insert loanEvents;
        }
    }

    public void runValidations(List<Investment__c> newInvestments, Map<Id, Investment__c> oldInvestmentsMap){
        Map<Id, List<Investment__c>> loanProductIdToLoans = new Map<Id, List<Investment__c>>();
        for (Investment__c temp : newInvestments) {
            // gather loan product Ids for loan settings validation
            if (temp.Loan_Product__c != null) {
                if (!loanProductIdToLoans.containsKey(temp.Loan_Product__c)) {
                    loanProductIdToLoans.put(temp.Loan_Product__c, new List<Investment__c>());
                }
                loanProductIdToLoans.get(temp.Loan_Product__c).add(temp);
            }

            List<String> fields = new List<String>();
            if (oldInvestmentsMap.get(temp.Id).Status__c == 'Active' && temp.Status__c == 'Active' && temp.RecordTypeId == Utility.loanRecordTypeId) {
                if (temp.Amount__c != oldInvestmentsMap.get(temp.Id).Amount__c) 
                    fields.add('Amount');
                
                if (temp.Application__c != oldInvestmentsMap.get(temp.Id).Application__c) 
                    fields.add('Application');

                if (temp.Disbursement_Method__c != oldInvestmentsMap.get(temp.Id).Disbursement_Method__c) 
                    fields.add('Disbursement Method');

                if (temp.Disbursement_Date__c != oldInvestmentsMap.get(temp.Id).Disbursement_Date__c) 
                    fields.add('Disbursement Date');

                if (temp.Early_Payment_Method__c != oldInvestmentsMap.get(temp.Id).Early_Payment_Method__c) 
                    fields.add('Early Payment Method');

                if (temp.First_Repayment_Date__c != oldInvestmentsMap.get(temp.Id).First_Repayment_Date__c) 
                    fields.add('First Repayment Date');

                if (temp.Flat_Amount__c != oldInvestmentsMap.get(temp.Id).Flat_Amount__c) 
                    fields.add('Flat Amount');

                if (temp.Grace_Period_Type__c != oldInvestmentsMap.get(temp.Id).Grace_Period_Type__c) 
                    fields.add('Grace Period Type');

                if (temp.Interest_Rate__c != oldInvestmentsMap.get(temp.Id).Interest_Rate__c) 
                    fields.add('Interest Rate');

                if (temp.Late_Repayment_Calculation_Method__c != oldInvestmentsMap.get(temp.Id).Late_Repayment_Calculation_Method__c) 
                    fields.add('Late Repayment Calculation Method');

                if (temp.Late_Repayment_Interest_Rate__c != oldInvestmentsMap.get(temp.Id).Late_Repayment_Interest_Rate__c) 
                    fields.add('Late Repayment Interest Rate');

                if (temp.Late_Repayment_Tolerance_Period__c != oldInvestmentsMap.get(temp.Id).Late_Repayment_Tolerance_Period__c) 
                    fields.add('Late Repayment Tolerance Period (days)');

                if (temp.Monitoring_Fee_Percentage__c != oldInvestmentsMap.get(temp.Id).Monitoring_Fee_Percentage__c) 
                    fields.add('Monitoring Fee Percentage');
                
                if (temp.Number_of_Grace_Periods__c != oldInvestmentsMap.get(temp.Id).Number_of_Grace_Periods__c) 
                    fields.add('Number of Grace Periods');

                if (temp.Number_of_Instalments__c != oldInvestmentsMap.get(temp.Id).Number_of_Instalments__c) 
                    fields.add('Number of Instalments');

                if (temp.Repayment_Frequency__c != oldInvestmentsMap.get(temp.Id).Repayment_Frequency__c) 
                    fields.add('Repayment Frequency');

                if (temp.Repayment_Frequency_Unit__c != oldInvestmentsMap.get(temp.Id).Repayment_Frequency_Unit__c) 
                    fields.add('Repayment Frequency Unit');

                if (temp.Setup_Fee__c != oldInvestmentsMap.get(temp.Id).Setup_Fee__c) 
                    fields.add('Setup Fee');

                if (temp.Percent_Of_Disbursement_Amount__c != oldInvestmentsMap.get(temp.Id).Percent_Of_Disbursement_Amount__c) 
                    fields.add('% of Disbursement Amount');
                
                if (temp.Setup_Fee_Cap__c != oldInvestmentsMap.get(temp.Id).Setup_Fee_Cap__c) 
                    fields.add('Setup Fee Cap');
            }

            if (!fields.isEmpty()) {
                temp.addError(String.join(fields, ', ') + ' cannot be changed on the \'Active\' loan.');
            }
        }

        // loan settings validation
        for (Loan_Product__c lp : [SELECT Id, Day_Count_Convention__c, CBO_Day_Count_Convention__c, Early_Payment_Method__c,
            CBO_Early_Payment_Method__c, Flat_Amount__c, CBO_Flat_Amount__c, Late_Repayment_Calculation_Method__c,
            CBO_Late_Repayment_Calculation_Method__c, Late_Repayment_Interest_Rate__c, CBO_Late_Repayment_Interest_Rate__c,
            Default_Arrears_Tolerance_Period_days__c, CBO_Late_Repayment_Tolerance_Period__c, Percent_Of_Disbursement_Amount__c,
            CBO_Percent_Of_Disbursement_Amount__c, Repayment_Frequency_Unit__c, CBO_Repayment_Frequency_Unit__c,
            Repayment_Frequency__c, CBO_Repayment_Frequency__c, Setup_Fee_Charging_Method__c, CBO_Setup_Fee_Charging_Method__c,
            Setup_Fee__c, CBO_Setup_Fee__c, Default_Loan_Amount__c, CBO_Default_Loan_Amount__c, Disbursement_Method__c, 
            CBO_Disbursement_Method__c, Default_Interest_Rate__c, CBO_Default_Interest_Rate__c, Default_number_of_installments__c, 
            CBO_Default_number_of_installments__c, Open_Ended_Loan__c, CBO_Open_Ended_Loan__c, Non_Working_Days_Rescheduling__c,
            CBO_Non_Working_Days_Rescheduling__c, Default_Variable_Interest_Spread__c, CBO_Default_Variable_Interest_Spread__c, 
            CBO_Setup_Fee_Cap__c, Setup_Fee_Cap__c, CBO_Default_Monitoring_Fee_Percentage__c, Default_Monitoring_Fee_Percentage__c
            FROM Loan_Product__c WHERE Id IN :loanProductIdToLoans.keySet()])
        {
            // check which settings can be overridden
            
            // System.debug(lp);
            List<String> settings = new List<String>();
            
            Boolean canBeOverriddenAmount = false;
            Boolean canBeOverriddenDayCountConvention = false;
            Boolean canBeOverriddenDisbursementMethod = false;
            Boolean canBeOverriddenEarlyPaymentMethod = false;
            Boolean canBeOverriddenFlatAmount = false;
            Boolean canBeOverriddenInterestRate = false;
            Boolean canBeOverriddenLateRepaymentCalculationMethod = false;
            Boolean canBeOverriddenLateRepaymentInterestRate = false;
            Boolean canBeOverriddenLateRepaymentTolerancePeriod = false;
            Boolean canBeOverriddenMonitoringFeePercentage = false;
            Boolean canBeOverriddenNonWorkingDaysRescheduling = false;
            Boolean canBeOverriddenNumberOfInstalments = false;
            Boolean canBeOverriddenOpenEndedLoan = false;
            Boolean canBeOverriddenPercentOfDisbursementAmount = false;
            Boolean canBeOverriddenRepaymentFrequencyUnit = false;
            Boolean canBeOverriddenRepaymentFrequency = false;
            Boolean canBeOverriddenSetupFeeChargingMethod = false;
            Boolean canBeOverriddenSetupFee = false;
            Boolean canBeOverriddenSetupFeeCap = false;
            Boolean canBeOverriddenVariableInterestSpread = false;
            
            if (lp.CBO_Default_Loan_Amount__c 
                || lp.Default_Loan_Amount__c == null) 
            {
                canBeOverriddenAmount = true;
                settings.add('Amount');
            }

            if (lp.CBO_Day_Count_Convention__c 
                || lp.Day_Count_Convention__c == null
                || lp.Day_Count_Convention__c == '') 
            {
                canBeOverriddenDayCountConvention = true;
                settings.add('Day Count Convention');
            }

            if (lp.CBO_Disbursement_Method__c 
                || lp.Disbursement_Method__c == null
                || lp.Disbursement_Method__c == '') 
            {
                canBeOverriddenDisbursementMethod = true;
                settings.add('Disbursement Method');
            }
                
            if (lp.CBO_Early_Payment_Method__c 
                || lp.Early_Payment_Method__c == null
                || lp.Early_Payment_Method__c == '') 
            {
                canBeOverriddenEarlyPaymentMethod = true;
                settings.add('Early Payment Method');
            }
                
            if (lp.CBO_Flat_Amount__c || lp.Flat_Amount__c == null) {
                canBeOverriddenFlatAmount = true;
                settings.add('Flat Amount');
            }

            if (lp.CBO_Default_Interest_Rate__c 
                || lp.Default_Interest_Rate__c == null) 
            {
                canBeOverriddenInterestRate = true;
                settings.add('Interest Rate');
            }
                
            if (lp.CBO_Late_Repayment_Calculation_Method__c 
                || lp.Late_Repayment_Calculation_Method__c == null
                || lp.Late_Repayment_Calculation_Method__c == '') 
            {
                canBeOverriddenLateRepaymentCalculationMethod = true;
                settings.add('Late Repayment Calculation Method');
            }
                
            if (lp.CBO_Late_Repayment_Interest_Rate__c 
                || lp.Late_Repayment_Interest_Rate__c == null) {
                canBeOverriddenLateRepaymentInterestRate = true;
                settings.add('Late Repayment Interest Rate');
            }
                
            if (lp.CBO_Late_Repayment_Tolerance_Period__c 
                || lp.Default_Arrears_Tolerance_Period_days__c == null) {
                canBeOverriddenLateRepaymentTolerancePeriod = true;
                settings.add('Late Repayment Tolerance Period');
            }
            
            if (lp.CBO_Default_Monitoring_Fee_Percentage__c 
                || lp.Default_Monitoring_Fee_Percentage__c == null) 
            {
                canBeOverriddenMonitoringFeePercentage = true;
                settings.add('Monitoring Fee Percentage');
            }

            if (lp.CBO_Non_Working_Days_Rescheduling__c 
                || lp.Non_Working_Days_Rescheduling__c == null
                || lp.Non_Working_Days_Rescheduling__c == '') 
            {
                canBeOverriddenNonWorkingDaysRescheduling = true;
                settings.add('Non-Working Days Rescheduling');
            }

            if (lp.CBO_Default_number_of_installments__c 
                || lp.Default_number_of_installments__c == null) 
            {
                canBeOverriddenNumberOfInstalments = true;
                settings.add('Number Of Instalments');
            }

            if (lp.CBO_Open_Ended_Loan__c) 
            {
                canBeOverriddenOpenEndedLoan = true;
                settings.add('Open Ended Loan');
            }
                
            if (lp.CBO_Percent_Of_Disbursement_Amount__c
                || lp.Percent_Of_Disbursement_Amount__c == null) {
                canBeOverriddenPercentOfDisbursementAmount = true;
                settings.add('% of Disbursement Amount');
            }
                
            if (lp.CBO_Repayment_Frequency_Unit__c 
                || lp.Repayment_Frequency_Unit__c == null
                || lp.Repayment_Frequency_Unit__c == '') 
            {
                canBeOverriddenRepaymentFrequencyUnit = true;
                settings.add('Repayment Frequency Unit');
            }
                
            if (lp.CBO_Repayment_Frequency__c 
                || lp.Repayment_Frequency__c == null) {
                canBeOverriddenRepaymentFrequency = true;
                settings.add('Repayment Frequency');
            }
                
            if (lp.CBO_Setup_Fee_Charging_Method__c 
                || lp.Setup_Fee_Charging_Method__c == null
                || lp.Setup_Fee_Charging_Method__c == '') 
            {
                canBeOverriddenSetupFeeChargingMethod = true;
                settings.add('Setup Fee Charging Method');
            }
                
            if (lp.CBO_Setup_Fee__c 
                || lp.Setup_Fee__c == null
                || lp.Setup_Fee__c == '') 
            {
                canBeOverriddenSetupFee = true;
                settings.add('Setup Fee');
            }

            if (lp.CBO_Setup_Fee__c 
                || lp.Setup_Fee__c == null) 
            {
                canBeOverriddenSetupFeeCap = true;
                settings.add('Setup Fee Cap');
            }

            if (lp.CBO_Default_Variable_Interest_Spread__c 
                || lp.Default_Variable_Interest_Spread__c == null) 
            {
                canBeOverriddenVariableInterestSpread = true;
                settings.add('Variable Interest Spread');
            }

            String settingsAllowed = '';
            if (settings.isEmpty()){
                settingsAllowed = 'No settings can be overridden. Settings on Loan level can only be changed by admin or Loan owner.';
            } else {
                settingsAllowed = 'Only ' + String.join(settings, ', ') + ' can be overridden.';
            }
            
            for (Investment__c temp : loanProductIdToLoans.get(lp.Id)) {
                // check if user can change settings
                Boolean canBeChangedByUser = false;
                if (temp.OwnerId == UserInfo.getUserId() || Utility.currentUserIsAdmin) canBeChangedByUser = true;

                Integer numberOfChangedSetting = 0; 
                Boolean canBeOverridden = true;
                
                if (temp.Amount__c != oldInvestmentsMap.get(temp.Id).Amount__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenAmount) canBeOverridden = false;
                }
                
                if (temp.Day_Count_Convention__c != oldInvestmentsMap.get(temp.Id).Day_Count_Convention__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenDayCountConvention) canBeOverridden = false;
                }
                
                if (temp.Disbursement_Method__c != oldInvestmentsMap.get(temp.Id).Disbursement_Method__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenDisbursementMethod) canBeOverridden = false;
                }

                if (temp.Early_Payment_Method__c != oldInvestmentsMap.get(temp.Id).Early_Payment_Method__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenEarlyPaymentMethod) canBeOverridden = false;
                }
                
                if (temp.Flat_Amount__c != oldInvestmentsMap.get(temp.Id).Flat_Amount__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenFlatAmount) canBeOverridden = false;
                }

                if (temp.Interest_Rate__c != oldInvestmentsMap.get(temp.Id).Interest_Rate__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenInterestRate) canBeOverridden = false;
                } 
                
                if (temp.Late_Repayment_Calculation_Method__c != oldInvestmentsMap.get(temp.Id).Late_Repayment_Calculation_Method__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenLateRepaymentCalculationMethod) canBeOverridden = false;
                }

                if (temp.Late_Repayment_Interest_Rate__c != oldInvestmentsMap.get(temp.Id).Late_Repayment_Interest_Rate__c) { 
                    numberOfChangedSetting++;
                    if (!canBeOverriddenLateRepaymentInterestRate) canBeOverridden = false;
                }

                if (temp.Late_Repayment_Tolerance_Period__c != oldInvestmentsMap.get(temp.Id).Late_Repayment_Tolerance_Period__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenLateRepaymentTolerancePeriod) canBeOverridden = false;
                }

                if (temp.Monitoring_Fee_Percentage__c != oldInvestmentsMap.get(temp.Id).Monitoring_Fee_Percentage__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenMonitoringFeePercentage) canBeOverridden = false;
                }

                if (temp.Non_Working_Days_Rescheduling__c != oldInvestmentsMap.get(temp.Id).Non_Working_Days_Rescheduling__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenNonWorkingDaysRescheduling) canBeOverridden = false;
                }

                if (temp.Number_of_Instalments__c != oldInvestmentsMap.get(temp.Id).Number_of_Instalments__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenNumberOfInstalments) canBeOverridden = false;
                }

                if (temp.Open_Ended_Loan__c != oldInvestmentsMap.get(temp.Id).Open_Ended_Loan__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenOpenEndedLoan) canBeOverridden = false;
                }

                if (temp.Percent_Of_Disbursement_Amount__c != oldInvestmentsMap.get(temp.Id).Percent_Of_Disbursement_Amount__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenPercentOfDisbursementAmount) canBeOverridden = false;
                }

                if (temp.Repayment_Frequency__c != oldInvestmentsMap.get(temp.Id).Repayment_Frequency__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenRepaymentFrequency) canBeOverridden = false;
                }

                if (temp.Repayment_Frequency_Unit__c != oldInvestmentsMap.get(temp.Id).Repayment_Frequency_Unit__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenRepaymentFrequencyUnit) canBeOverridden = false;
                }

                if (temp.Setup_Fee__c != oldInvestmentsMap.get(temp.Id).Setup_Fee__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenSetupFee) canBeOverridden = false;
                }

                if (temp.Setup_Fee_Cap__c != oldInvestmentsMap.get(temp.Id).Setup_Fee_Cap__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenSetupFeeCap) canBeOverridden = false;
                }

                if (temp.Setup_Fee_Charging_Method__c != oldInvestmentsMap.get(temp.Id).Setup_Fee_Charging_Method__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenSetupFeeChargingMethod) canBeOverridden = false;
                }

                if (temp.Variable_Interest_Spread__c != oldInvestmentsMap.get(temp.Id).Variable_Interest_Spread__c) {
                    numberOfChangedSetting++;
                    if (!canBeOverriddenVariableInterestSpread) canBeOverridden = false;
                }
                // System.debug(numberOfChangedSetting);
                if (numberOfChangedSetting > 0 && !canBeOverridden) {
                    if (!canBeChangedByUser) temp.addError(settingsAllowed);
                }
            }
        } 
    }

    /**
     * @description         Populate fields of the Fund record associated with the current Investment.
     */  
    public void populateFundFields(Map<Id, Investment__c> newInvestmentsMap, Map<Id, Investment__c> oldInvestmentsMap){
        Set<Id> fundIds = new Set<Id>();
    
        // gather fund ids from investments where fund or expected amount has been changed 
        if (newInvestmentsMap == null) {
            newInvestmentsMap = oldInvestmentsMap;
            oldInvestmentsMap = null;
        }
        for (Investment__c inv : newInvestmentsMap.values()) {
            Boolean updateFund = false;
            if (oldInvestmentsMap == null) {
                updateFund = true;
            } else {
                if (inv.Loan_Fund__c != oldInvestmentsMap.get(inv.Id).Loan_Fund__c) {
                    updateFund = true;
                } else {
                    if (inv.Total_Expected__c != oldInvestmentsMap.get(inv.Id).Total_Expected__c
                        || inv.Total_Due__c != oldInvestmentsMap.get(inv.Id).Total_Due__c
                        || inv.Total_Paid__c != oldInvestmentsMap.get(inv.Id).Total_Paid__c
                        || inv.Total_Amount_Written_Off1__c != oldInvestmentsMap.get(inv.Id).Total_Amount_Written_Off1__c) 
                    {
                        updateFund = true;
                    }
                }
            }

            if (updateFund && !fundIds.contains(inv.Loan_Fund__c)) fundIds.add(inv.Loan_Fund__c);
            
        }

        // populate expected amounts
        if (!fundIds.isEmpty()) {
            List<Fund__c> fundsToUpdate = new List<Fund__c>();
            for (Fund__c fund : [SELECT Id, Fees_Due__c, Fees_Expected__c, Fees_Paid__c, Fees_Written_Off__c, Fees_Overdue__c, Fees_Remaining__c,
                Interest_Due__c, Interest_Expected__c, Interest_Paid__c, Interest_Written_Off__c, Interest_Overdue__c, Interest_Remaining__c,
                Late_Repayment_Fees_Due__c, Late_Repayment_Fees_Expected__c, Late_Repayment_Fees_Paid__c, Late_Repayment_Fees_Written_Off__c,
                Late_Repayment_Fees_Overdue__c, Late_Repayment_Fees_Remaining__c, Total_Expected__c, Setup_Fee_Expected__c, 
                Principal_Due__c, Principal_Expected__c, Principal_Paid__c, Principal_Written_Off__c, Principal_Overdue__c, Principal_Remaining__c,
                (SELECT Id, Fees_Due__c, Fees_Expected__c, Fees_Paid__c, Fees_Written_Off__c, Fees_Overdue__c, Fees_Remaining__c,
                Interest_Due__c, Interest_Expected0__c, Interest_Paid__c, Interest_Written_Off__c, Interest_Overdue__c, Interest_Remaining__c,
                Late_Repayment_Fees_Due__c, Late_Repayment_Fees_Expected0__c, Late_Repayment_Fees_Paid__c, Late_Repayment_Fees_Written_Off__c,
                Late_Repayment_Fees_Overdue__c, Late_Repayment_Fees_Remaining__c, Total_Expected__c, Setup_Fee_Expected__c,
                Principal_Due__c, Principal_Expected__c, Principal_Paid__c, Principal_Written_Off__c, Principal_Overdue__c, Principal_Remaining__c
                FROM Investments__r) FROM Fund__c WHERE Id IN :fundIds])
            {
                
                Decimal feesDue = 0;
                Decimal feesExpected = 0;
                Decimal feesPaid = 0;
                Decimal feesWrittenOff = 0;
                Decimal feesOverdue = 0;
                Decimal feesRemaining = 0;
                Decimal interestDue = 0;
                Decimal interestExpected = 0;
                Decimal interestPaid = 0;
                Decimal interestWrittenOff = 0;
                Decimal interestOverdue = 0;
                Decimal interestRemaining = 0;
                Decimal lateRepaymentFeesDue = 0;
                Decimal lateRepaymentFeesExpected = 0;
                Decimal lateRepaymentFeesPaid = 0;
                Decimal lateRepaymentFeesWrittenOff = 0;
                Decimal lateRepaymentFeesOverdue = 0;
                Decimal lateRepaymentFeesRemaining = 0;
                Decimal principalDue = 0;
                Decimal principalExpected = 0;
                Decimal principalPaid = 0;
                Decimal principalWrittenOff = 0;
                Decimal principalOverdue = 0;
                Decimal principalRemaining = 0;
                Decimal setupFeesExpected = 0;
                Decimal totalExpected = 0;

                for (Investment__c inv : fund.Investments__r) {
                    if (inv.Fees_Due__c != null) feesDue += inv.Fees_Due__c;
                    if (inv.Fees_Expected__c != null) feesExpected += inv.Fees_Expected__c;
                    if (inv.Fees_Paid__c != null) feesPaid += inv.Fees_Paid__c;
                    if (inv.Fees_Written_Off__c != null) feesWrittenOff += inv.Fees_Written_Off__c;
                    if (inv.Fees_Overdue__c != null) feesOverdue += inv.Fees_Overdue__c;
                    if (inv.Fees_Remaining__c != null) feesRemaining += inv.Fees_Remaining__c;
                    if (inv.Interest_Due__c != null) interestDue += inv.Interest_Due__c;
                    if (inv.Interest_Expected0__c != null) interestExpected += inv.Interest_Expected0__c;
                    if (inv.Interest_Paid__c != null) interestPaid += inv.Interest_Paid__c;
                    if (inv.Interest_Written_Off__c != null) interestWrittenOff += inv.Interest_Written_Off__c;
                    if (inv.Interest_Overdue__c != null) interestOverdue += inv.Interest_Overdue__c;
                    if (inv.Interest_Remaining__c != null) interestRemaining += inv.Interest_Remaining__c;
                    if (inv.Late_Repayment_Fees_Due__c != null) lateRepaymentFeesDue += inv.Late_Repayment_Fees_Due__c;
                    if (inv.Late_Repayment_Fees_Expected0__c != null) lateRepaymentFeesExpected += inv.Late_Repayment_Fees_Expected0__c;
                    if (inv.Late_Repayment_Fees_Paid__c != null) lateRepaymentFeesPaid += inv.Late_Repayment_Fees_Paid__c;
                    if (inv.Late_Repayment_Fees_Written_Off__c != null) lateRepaymentFeesWrittenOff += inv.Late_Repayment_Fees_Written_Off__c;
                    if (inv.Late_Repayment_Fees_Overdue__c != null) lateRepaymentFeesOverdue += inv.Late_Repayment_Fees_Overdue__c;
                    if (inv.Late_Repayment_Fees_Remaining__c != null) lateRepaymentFeesRemaining += inv.Late_Repayment_Fees_Remaining__c;
                    if (inv.Principal_Due__c != null) principalDue += inv.Principal_Due__c;
                    if (inv.Principal_Expected__c != null) principalExpected += inv.Principal_Expected__c;
                    if (inv.Principal_Paid__c != null) principalPaid += inv.Principal_Paid__c;
                    if (inv.Principal_Written_Off__c != null) principalWrittenOff += inv.Principal_Written_Off__c;
                    if (inv.Principal_Overdue__c != null) principalOverdue += inv.Principal_Overdue__c;
                    if (inv.Principal_Remaining__c != null) principalRemaining += inv.Principal_Remaining__c;
                    if (inv.Setup_Fee_Expected__c != null) setupFeesExpected += inv.Setup_Fee_Expected__c;
                    if (inv.Total_Expected__c != null) totalExpected += inv.Total_Expected__c;
                }

                fund.Fees_Due__c = feesDue;
                fund.Fees_Expected__c = feesExpected;
                fund.Fees_Paid__c = feesPaid;
                fund.Fees_Written_Off__c = feesWrittenOff;
                fund.Fees_Overdue__c = feesOverdue;
                fund.Fees_Remaining__c = feesRemaining;
                fund.Interest_Due__c = interestDue;
                fund.Interest_Expected__c = interestExpected;
                fund.Interest_Paid__c = interestPaid;
                fund.Interest_Written_Off__c = interestWrittenOff;
                fund.Interest_Overdue__c = interestOverdue;
                fund.Interest_Remaining__c = interestRemaining;
                fund.Late_Repayment_Fees_Due__c = lateRepaymentFeesDue;
                fund.Late_Repayment_Fees_Expected__c = lateRepaymentFeesExpected;
                fund.Late_Repayment_Fees_Paid__c = lateRepaymentFeesPaid;
                fund.Late_Repayment_Fees_Written_Off__c = lateRepaymentFeesWrittenOff;
                fund.Late_Repayment_Fees_Overdue__c = lateRepaymentFeesOverdue;
                fund.Late_Repayment_Fees_Remaining__c = lateRepaymentFeesRemaining;
                fund.Principal_Due__c = principalDue;
                fund.Principal_Expected__c = principalExpected;
                fund.Principal_Paid__c = principalPaid;
                fund.Principal_Written_Off__c = principalWrittenOff;
                fund.Principal_Overdue__c = principalOverdue;
                fund.Principal_Remaining__c = principalRemaining;
                fund.Setup_Fee_Expected__c = setupFeesExpected;
                fund.Total_Expected__c = totalExpected;

                fundsToUpdate.add(fund);
            }
            
            update fundsToUpdate;
            
        }
        
    }

    public void deleteChildRecords(Map<Id, Investment__c> oldInvestmentsMap){
        Utility.executeFromDeleteMethodOfInvestmentTrigger = true;
        delete [SELECT Id FROM Loan_Event__c WHERE Investment__c IN :oldInvestmentsMap.keySet()];
        delete [SELECT Id FROM Transaction__c WHERE (Investment_Reporting__c IN :oldInvestmentsMap.keySet() OR Investment__c IN :oldInvestmentsMap.keySet()) AND Loan_Event__c = null];
        Utility.executeFromDeleteMethodOfInvestmentTrigger = false;
        delete [SELECT Id FROM Progress_Report__c WHERE Investment__c IN :oldInvestmentsMap.keySet()];
    }

}