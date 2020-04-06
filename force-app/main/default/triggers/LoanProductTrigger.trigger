trigger LoanProductTrigger on Loan_Product__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {

    if (Trigger.isBefore && Trigger.isUpdate) {
        runValidations();
    }

    public void runValidations(){
        Validation_Settings__c vs = Validation_Settings__c.getInstance();
        if (!vs.Disable_Validation_Rules_on_Loan_Product__c) {
            Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get('sfims__Loan_Product__c').getDescribe().fields.getMap();
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
                'sfims__active__c'    
            };
            Set<String> fields = new Set<String>();
            for (String field : fieldsMap.keySet()) {
                if (!fieldsToIgnore.contains(field)) fields.add(String.valueOf(fieldsMap.get(field)));
            } 
            
            for (Loan_Product__c lp : [SELECT Id, (SELECT Id FROM Loans__r WHERE Status__c = 'Active' LIMIT 1) 
                FROM Loan_Product__c WHERE Id IN: Trigger.new]) 
            {
                if (!lp.Loans__r.isEmpty()) {
                    Boolean changed = false;
                    for (String field : fields) {
                        if (Trigger.newMap.get(lp.Id).get(field) != Trigger.oldMap.get(lp.Id).get(field)) {
                            changed = true;
                            break;
                        }
                    }
                    if (changed) Trigger.newMap.get(lp.Id).addError(System.Label.sfims.error_message_45);
                }
            }    
        }
        
        // check which settings can be overridden
        Loan_Settings__c ls = Loan_Settings__c.getInstance();
        System.debug(ls);
        List<String> settings = new List<String>();
        
        Boolean canBeOverriddenDayCountConvention = false;
        Boolean canBeOverriddenEarlyPaymentMethod = false;
        Boolean canBeOverriddenFlatAmount = false;
        Boolean canBeOverriddenLateRepaymentCalculationMethod = false;
        Boolean canBeOverriddenLateRepaymentInterestRate = false;
        Boolean canBeOverriddenLateRepaymentTolerancePeriod = false;
        Boolean canBeOverriddenMonitoringFeePercentage = false;
        Boolean canBeOverriddenNonWorkingDaysRescheduling = false;
        Boolean canBeOverriddenPercentOfDisbursementAmount = false;
        Boolean canBeOverriddenRepaymentAllocationOpder = false;
        Boolean canBeOverriddenRepaymentAllocationType = false;
        Boolean canBeOverriddenRepaymentFrequencyUnit = false;
        Boolean canBeOverriddenRepaymentFrequency = false;
        Boolean canBeOverriddenSetupFeeChargingMethod = false;
        Boolean canBeOverriddenSetupFee = false;
        
        if (ls.CBO_Day_Count_Convention__c 
            || ls.Day_Count_Convention__c == null
            || ls.Day_Count_Convention__c == '') 
        {
            canBeOverriddenDayCountConvention = true;
            settings.add('Day Count Convention');
        }
            
        if (ls.CBO_Early_Payment_Method__c 
            || ls.Early_Payment_Method__c == null
            || ls.Early_Payment_Method__c == '') 
        {
            canBeOverriddenEarlyPaymentMethod = true;
            settings.add('Early Payment Method');
        }
            
        if (ls.CBO_Flat_Amount__c || ls.Flat_Amount__c == null) {
            canBeOverriddenFlatAmount = true;
            settings.add('Flat Amount');
        }
            
        if (ls.CBO_Late_Repayment_Calculation_Method__c 
            || ls.Late_Repayment_Calculation_Method__c == null
            || ls.Late_Repayment_Calculation_Method__c == '') 
        {
            canBeOverriddenLateRepaymentCalculationMethod = true;
            settings.add('Late Repayment Calculation Method');
        }
            
        if (ls.CBO_Late_Repayment_Interest_Rate__c 
            || ls.Late_Repayment_Interest_Rate__c == null) {
            canBeOverriddenLateRepaymentInterestRate = true;
            settings.add('Late Repayment Interest Rate');
        }
            
        if (ls.CBO_Late_Repayment_Tolerance_Period__c 
            || ls.Late_Repayment_Tolerance_Period__c == null) {
            canBeOverriddenLateRepaymentTolerancePeriod = true;
            settings.add('Late Repayment Tolerance Period');
        }

        if (ls.CBO_Monitoring_Fee_Percentage__c 
            || ls.Monitoring_Fee_Percentage__c == null) 
        {
            canBeOverriddenMonitoringFeePercentage = true;
            settings.add('Default Monitoring Fee Percentage');
        }

        if (ls.CBO_Non_Working_Days_Rescheduling__c 
            || ls.Non_Working_Days_Rescheduling__c == null
            || ls.Non_Working_Days_Rescheduling__c == '') 
        {
            canBeOverriddenNonWorkingDaysRescheduling = true;
            settings.add('Non-Working Days Rescheduling');
        }
            
        if (ls.CBO_Percent_Of_Disbursement_Amount__c
            || ls.Percent_Of_Disbursement_Amount__c == null) {
            canBeOverriddenPercentOfDisbursementAmount = true;
            settings.add('% of Disbursement Amount');
        }

        if (ls.CBO_Repayment_Allocation_Order__c 
            || ls.Repayment_Allocation_Order__c == null
            || ls.Repayment_Allocation_Order__c == '') 
        {
            canBeOverriddenRepaymentAllocationOpder = true;
            settings.add('Repayment Allocation Order');
        }

        if (ls.CBO_Repayment_Allocation_Type__c 
            || ls.Repayment_Allocation_Type__c == null
            || ls.Repayment_Allocation_Type__c == '') 
        {
            canBeOverriddenRepaymentAllocationType = true;
            settings.add('Repayment Allocation Type');
        }
            
        if (ls.CBO_Repayment_Frequency_Unit__c 
            || ls.Repayment_Frequency_Unit__c == null
            || ls.Repayment_Frequency_Unit__c == '') 
        {
            canBeOverriddenRepaymentFrequencyUnit = true;
            settings.add('Repayment Frequency Unit');
        }
            
        if (ls.CBO_Repayment_Frequency__c 
            || ls.Repayment_Frequency__c == null) {
            canBeOverriddenRepaymentFrequency = true;
            settings.add('Repayment Frequency');
        }
            
        if (ls.CBO_Setup_Fee_Charging_Method__c 
            || ls.Setup_Fee_Charging_Method__c == null
            || ls.Setup_Fee_Charging_Method__c == '') 
        {
            canBeOverriddenSetupFeeChargingMethod = true;
            settings.add('Setup Fee Charging Method');
        }
            
        if (ls.CBO_Setup_Fee__c 
            || ls.Setup_Fee__c == null
            || ls.Setup_Fee__c == '') 
        {
            canBeOverriddenSetupFee = true;
            settings.add('Setup Fee');
        }

        String settingsAllowed = '';
        if (settings.isEmpty()){
            settingsAllowed = 'No settings can be overridden. Settings on Loan Product level can only be changed by admin or Loan Product owner.';
        } else {
            settingsAllowed = 'Only ' + String.join(settings, ', ') + ' can be overridden.';
        }

        for (Loan_Product__c temp : Trigger.new) {
            // check if user can change settings
            Boolean canBeChangedByUser = false;
            if (temp.OwnerId == UserInfo.getUserId() || Utility.currentUserIsAdmin) canBeChangedByUser = true;

            Integer numberOfChangedSetting = 0; 
            Boolean canBeOverridden = true;
            if (temp.Day_Count_Convention__c != Trigger.oldMap.get(temp.Id).Day_Count_Convention__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenDayCountConvention) canBeOverridden = false;
            }
            
            if (temp.Early_Payment_Method__c != Trigger.oldMap.get(temp.Id).Early_Payment_Method__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenEarlyPaymentMethod) canBeOverridden = false;
            }
            
            if (temp.Flat_Amount__c != Trigger.oldMap.get(temp.Id).Flat_Amount__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenFlatAmount) canBeOverridden = false;
            } 
            
            if (temp.Late_Repayment_Calculation_Method__c != Trigger.oldMap.get(temp.Id).Late_Repayment_Calculation_Method__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenLateRepaymentCalculationMethod) canBeOverridden = false;
            }

            if (temp.Late_Repayment_Interest_Rate__c != Trigger.oldMap.get(temp.Id).Late_Repayment_Interest_Rate__c) { 
                numberOfChangedSetting++;
                if (!canBeOverriddenLateRepaymentInterestRate) canBeOverridden = false;
            }

            if (temp.Default_Arrears_Tolerance_Period_days__c != Trigger.oldMap.get(temp.Id).Default_Arrears_Tolerance_Period_days__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenLateRepaymentTolerancePeriod) canBeOverridden = false;
            }

            if (temp.Default_Monitoring_Fee_Percentage__c != Trigger.oldMap.get(temp.Id).Default_Monitoring_Fee_Percentage__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenMonitoringFeePercentage) canBeOverridden = false;
            }

            if (temp.Non_Working_Days_Rescheduling__c != Trigger.oldMap.get(temp.Id).Non_Working_Days_Rescheduling__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenNonWorkingDaysRescheduling) canBeOverridden = false;
            }

            if (temp.Percent_Of_Disbursement_Amount__c != Trigger.oldMap.get(temp.Id).Percent_Of_Disbursement_Amount__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenPercentOfDisbursementAmount) canBeOverridden = false;
            }

            if (temp.Repayment_Allocation_Order__c != Trigger.oldMap.get(temp.Id).Repayment_Allocation_Order__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenRepaymentAllocationOpder) canBeOverridden = false;
            }

            if (temp.Repayment_Allocation_Type__c != Trigger.oldMap.get(temp.Id).Repayment_Allocation_Type__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenRepaymentAllocationType) canBeOverridden = false;
            }

            if (temp.Repayment_Frequency__c != Trigger.oldMap.get(temp.Id).Repayment_Frequency__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenRepaymentFrequency) canBeOverridden = false;
            }

            if (temp.Repayment_Frequency_Unit__c != Trigger.oldMap.get(temp.Id).Repayment_Frequency_Unit__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenRepaymentFrequencyUnit) canBeOverridden = false;
            }

            if (temp.Setup_Fee__c != Trigger.oldMap.get(temp.Id).Setup_Fee__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenSetupFee) canBeOverridden = false;
            }

            if (temp.Setup_Fee_Charging_Method__c != Trigger.oldMap.get(temp.Id).Setup_Fee_Charging_Method__c) {
                numberOfChangedSetting++;
                if (!canBeOverriddenSetupFeeChargingMethod) canBeOverridden = false;
            }

            if (numberOfChangedSetting > 0 && !canBeOverridden) {
                if (!canBeChangedByUser) temp.addError(settingsAllowed);
            }

        }
    }
    
}