public with sharing class RepaymentScheduleWrapper {

    @AuraEnabled public String Name {get;set;}
    @AuraEnabled public Date Due_Date {get;set;}
    @AuraEnabled public String Status {get;set;}
    @AuraEnabled public Decimal Total_Expected {get;set;}
    @AuraEnabled public Decimal Interest_Rate {get;set;}
    @AuraEnabled public Decimal Interest_Expected {get;set;}
    @AuraEnabled public Decimal Principal_Expected {get;set;}

    public RepaymentScheduleWrapper(Repayment_Schedule__c rs) {
        Name = rs.Name;
        Due_Date = rs.Due_Date__c;
        Status = rs.Status__c;
        Total_Expected = rs.Total_Expected__c;
        Interest_Rate = rs.Interest_Rate__c;
        Interest_Expected = rs.Interest_Expected0__c;
        Principal_Expected = rs.Principal_Expected__c;
    }
}