public with sharing class OverriddenLoanPageController {

    public class CommonException extends Exception {
    }

    @AuraEnabled
    public static Boolean checkDisableValidationRules() {
        try {
            Validation_Settings__c vs = Validation_Settings__c.getInstance();
            return vs.sfims__Disable_Validation_Rules_on_Investment__c;
        } catch (Exception err) {
            throw new CommonException(err.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, String> generateSchedule(String theLoanString, Boolean preview) {
        System.debug(theLoanString);
        Investment__c theLoan = (Investment__c)JSON.deserialize(theLoanString, Investment__c.class);
        Map<String, String> returnMap = new Map<String, String>();
        Savepoint sp = Database.setSavepoint();
        try {
            System.debug(theLoan.Interest_Rate__c);
            upsert theLoan;
            if (preview) {
                return OverriddenLoanPageController.generatePreview(sp, theLoan.Id);
            } else {
                return OverriddenLoanPageController.saveRepaymentSchedules(sp, theLoan.Id);
            }
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }

    public static Map<String, String> generatePreview(Savepoint sp, String loanId) {
        Map<String, String> returnMap = new Map<String, String>();
        try {
            returnMap.put('schedules', JSON.serialize(LoanScheduler.generateScheduleById(loanId)));
            Investment__c theLoan = [
                SELECT Loan_Product__c, Loan_Product__r.Interest_Rate_Source__c, Loan_Product__r.Interest_Reference_Rate__c
                FROM Investment__c 
                WHERE Id = :loanId
            ];
            if (theLoan.Loan_Product__c != null && theLoan.Loan_Product__r.Interest_Rate_Source__c == 'Variable Interest'
                && theLoan.Loan_Product__r.Interest_Reference_Rate__c != null) 
            {    
                returnMap.put('variableInterest', System.Label.sfims.warning_message_1);
            }
            Database.rollback(sp);
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(e.getTypeName());
            System.debug(e.getLineNumber());
            System.debug(e.getMessage());
            returnMap.put('error', System.Label.sfims.part_of_error_message_3 + ': ' + e.getMessage());
        }
        return returnMap;
    }

    public static Map<String, String> saveRepaymentSchedules(Savepoint sp, String loanId) {
        Map<String, String> returnMap = new Map<String, String>();
        try {
            delete [SELECT Id FROM Repayment_Schedule__c WHERE Loan__c = :loanId AND Migration__c = false];
            LoanScheduler.recalculateLoanSchedule(loanId);
            returnMap.put('success', loanId);
        } catch (DmlException e) {
            Database.rollback(sp);       
            returnMap.put('error', System.Label.sfims.part_of_error_message_4 + ': ' + e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(e.getTypeName());
            System.debug(e.getLineNumber());
            System.debug(e.getMessage());
            returnMap.put('error', System.Label.sfims.part_of_error_message_3 + ': ' + e.getMessage());
        }
        return returnMap;
    }

    // @AuraEnabled
    // public static Map<String, SObject> getUserProfileInfo() {
    //     try {
    //         Map<String, SObject> response = new Map<String, SObject>();
    //         response.put('user', OverriddenLoanProductPageController.getUserInfo());
    //         response.put('profile', OverriddenLoanProductPageController.getProfileInfo());
    //         return response;
    //     } catch (Exception e) {
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }

    @AuraEnabled
    public static String getFieldSets(String mode) {
        return JSON.serialize(OverriddenLoanProductPageController.formFieldMap(Schema.SObjectType.Investment__c.fieldSets.getMap(), 'loan', mode));
    }

    @AuraEnabled
    public static String getLoanProductSettings(String loanProductId, String loanId) {
        if (loanProductId == null) {
            Investment__c theLoan = [
                SELECT Loan_Product__c
                FROM Investment__c
                WHERE Id = :loanId
            ];
            loanProductId = theLoan.Loan_Product__c;
        }

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Loan_Product__c.fields.getMap();
        List<Loan_Product__c> lps = Database.query('SELECT ' + String.join(new List<String>(fieldMap.keySet()), ',') + ' FROM Loan_Product__c WHERE Id =: loanProductId');
        if (!lps.isEmpty()) {
            Loan_Product__c lp = lps[0];
            Map<String, Object> settingsMap = new Map<String, Object>();
            for (Schema.SObjectField fieldAPIName : fieldMap.values()) {
                System.debug(fieldAPIName);
                System.debug(lp.get(fieldAPIName));

                settingsMap.put(String.valueOf(fieldAPIName), lp.get(fieldAPIName));

            }
            for (String key : settingsMap.keySet()) {
                System.debug(key);
                System.debug(settingsMap.get(key));
            }
            return JSON.serialize(settingsMap);
        } else {
            throw new AuraHandledException(System.Label.sfims.error_message_65);
        }
    }

}