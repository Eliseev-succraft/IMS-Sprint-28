public with sharing class LoanUtils {

    public static Double calculatePMT(Integer instalmentCount, Integer periodCount, String periodUnit, Integer gracePeriodCount, String gracePeriodType, Decimal loanAmount, Decimal interestRate){
        
        // calculate PMT value
        Double PMT_value = 0;
        
        Decimal periodsPerYear = getPeriodsPerYear(periodCount,periodUnit);
        Decimal interestPerPeriod = 0;
        if(interestRate != null) interestPerPeriod = (interestRate/periodsPerYear)/100;
        
        // count number of principal payment schedules
        Integer numberOfPrincipalPayments = instalmentCount;
        if(gracePeriodType != 'None'){
            numberOfPrincipalPayments -= gracePeriodCount;
        }
        
        if(interestPerPeriod == 0 || interestPerPeriod == null){
            PMT_value = loanAmount/numberOfPrincipalPayments;
        } else {
            PMT_value = (interestPerPeriod/(1 - Math.pow(Double.valueOf(1+interestPerPeriod) , Double.valueOf(-1*numberOfPrincipalPayments)))) * loanAmount;
        }
        // round to 2 decimals
        PMT_value = Decimal.valueOf(PMT_value).setScale(2);
        return PMT_value;
    }  

    public static Decimal getPeriodsPerYear(Integer periodCount, String periodUnit){
        // system.debug(periodCount);
        // we need to take into account decimals because there might be an unwhole amount of periods per year, e.g. in case of a single 8-year period
        Decimal periodCountDecimal = Decimal.valueOf(periodCount);
    
        Decimal periodsPerYear = 1;
        if(periodUnit == 'Days' ) periodsPerYear = Decimal.valueOf(365).divide(periodCountDecimal,2);
        else if(periodUnit == 'Weeks') periodsPerYear = Decimal.valueOf(52).divide(periodCountDecimal,2);
        else if(periodUnit == 'Months') periodsPerYear = Decimal.valueOf(12).divide(periodCountDecimal,2);
        else if(periodUnit == 'Years') periodsPerYear = Decimal.valueOf(1).divide(periodCountDecimal,2);

        // system.debug(periodsPerYear);

        return periodsPerYear;      
    }  

    @AuraEnabled
    public static List<Repayment_Schedule__c> getLoanSchedule(String loanId){
        if (!Repayment_Schedule__c.SObjectType.getDescribe().isAccessible()) { 
            throw new AuraHandledException(System.Label.sfims.error_message_28);
        }          
        return [
            SELECT Id, Name, Status__c, Due_Date__c, Principal_Expected__c, Interest_Expected0__c, 
                Fees_Expected__c, Interest_Rate__c, Total_Expected__c
            FROM Repayment_Schedule__c WHERE Loan__c = :loanId 
        ];
    }

    @AuraEnabled
    public static List<RepaymentScheduleWrapper> getLoanScheduleWrappers(String loanId){
        if (!Repayment_Schedule__c.SObjectType.getDescribe().isAccessible()) { 
            throw new AuraHandledException(System.Label.sfims.error_message_28);
        }                  
        // system.debug(loanId);
        List<RepaymentScheduleWrapper> rswList = new List<RepaymentScheduleWrapper>();
        for(Repayment_Schedule__c rs : [
            SELECT Id, Name, Status__c, Due_Date__c, Principal_Expected__c, Interest_Expected0__c,
                Fees_Expected__c, Interest_Rate__c, Total_Expected__c
            FROM Repayment_Schedule__c WHERE Loan__c = :loanId
        ])
        {
            RepaymentScheduleWrapper rsw = new RepaymentScheduleWrapper(rs);
            rswList.add(rsw);
        }
        return rswList;
    }    


    @AuraEnabled
    public static Boolean updateLoanSchedule(List<Repayment_Schedule__c> editedLoanScheduleList){
        if (!Repayment_Schedule__c.SObjectType.getDescribe().isUpdateable()) { 
            throw new AuraHandledException(System.Label.sfims.error_message_29);
        }                  
        try{
            DMLManager.updateAsUser(editedLoanScheduleList);
            return true;
        } catch(Exception e){
            return false;
        }
    }

}