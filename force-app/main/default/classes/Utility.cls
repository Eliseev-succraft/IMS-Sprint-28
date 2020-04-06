public with sharing class Utility {
    public static Boolean currentUserIsAdmin {
        get {
            if (currentUserIsAdmin == null){
                List<Profile> adminProfiles = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
                if (!adminProfiles.isEmpty() && UserInfo.getProfileId() == adminProfiles[0].Id) currentUserIsAdmin = true;
                else currentUserIsAdmin = false;        
            }
            return currentUserIsAdmin;
        }
        set;
    }

    public static Id loanRecordTypeId {
        get {
            if (loanRecordTypeId == null){
                loanRecordTypeId = Schema.Sobjecttype.Investment__c.getRecordTypeInfosByName().get('Loan').getRecordTypeId();            
            }
            return loanRecordTypeId;
        }
        set;
    }

    // this variable is used for the deletion metods of the LoanEventTrigger
    public static List<Transaction__c> transactionsToDelete {
        get {
            if (transactionsToDelete == null){
                transactionsToDelete = new List<Transaction__c>();            
            }
            return transactionsToDelete;
        }
        set;
    }

    // this variable is used for the deletion metods of the LoanEventTrigger
    public static List<Investment__c> loansToRecalculate {
        get {
            if (loansToRecalculate == null){
                loansToRecalculate = new List<Investment__c>();            
            }
            return loansToRecalculate;
        }
        set;
    }

    public static Boolean bypassMilestoneHistoryTrigger {
        get {
            if (bypassMilestoneHistoryTrigger == null) bypassMilestoneHistoryTrigger = false;
            return bypassMilestoneHistoryTrigger;
        }
        set;
    }

    public static Boolean bypassLoanEventTrigger {
        get {
            if (bypassLoanEventTrigger == null) bypassLoanEventTrigger = false;
            return bypassLoanEventTrigger;
        }
        set;
    }

    public static Boolean executeFromDeleteMethodOfInvestmentTrigger {
        get {
            if (executeFromDeleteMethodOfInvestmentTrigger == null) executeFromDeleteMethodOfInvestmentTrigger = false;
            return executeFromDeleteMethodOfInvestmentTrigger;
        }
        set;
    }

    public static Id businessHoursId {
        get {
            if (businessHoursId == null) businessHoursId = [SELECT Id FROM BusinessHours WHERE IsDefault = true].Id;
            return businessHoursId;
        }
        set;        
    }

    public static Id guaranteeRecordTypeId {
        get {
            if (guaranteeRecordTypeId == null){
                guaranteeRecordTypeId = Schema.Sobjecttype.Security__c.getRecordTypeInfosByName().get('Guarantor').getRecordTypeId();            
            }
            return guaranteeRecordTypeId;
        }
        set;
    }

    public static Id collateralRecordTypeId {
        get {
            if (collateralRecordTypeId == null){
                collateralRecordTypeId = Schema.Sobjecttype.Security__c.getRecordTypeInfosByName().get('Collateral').getRecordTypeId();            
            }
            return collateralRecordTypeId;
        }
        set;
    }

    public static Decimal InstalmentAmount { get; set; }

    public class FieldSetWrapper {

        public String Label {get;set;}
        public List<String> Fields {get;set;}

        public FieldSetWrapper() {
        
        }
    }
}