public without sharing class LoanScheduleEditorController {
    public class CustomException extends Exception {
    }

    @AuraEnabled
    public static Map<String, Map<String, Boolean>> getButtonAccess(Id loanId, Boolean isDebugLog) {
        return new Map<String, Map<String, Boolean>>{
            'customPermissions' => new Map<String, Boolean>{
                'Disburse' => FeatureManagement.checkPermission('Disburse_Loans'),
                'EditSchedule' => FeatureManagement.checkPermission('Edit_Repayment_Schedule'),
                'Reschedule' => FeatureManagement.checkPermission('Reschedule_Loans'),
                'EarlyRepayment' => FeatureManagement.checkPermission('Pay_Off_Loans'),
                'WriteOff' => FeatureManagement.checkPermission('Write_Off_Loans')
            },
            'visible' => new Map<String, Boolean>{
                'EditSchedule' => (getSchedules(loanId, isDebugLog).size() > 0)
            }
        };
    }

    @AuraEnabled
    public static List<Repayment_Schedule__c> getSchedules(Id loanId, Boolean isDebugLog) {
        try {
            return [
                SELECT Name, Due_Date__c, Status__c, Total_Expected__c, Principal_Expected__c, sfims__Interest_Expected_Standard_Loan__c, Interest_Rate__c, Fees_Expected__c
                FROM Repayment_Schedule__c
                WHERE sfims__Loan__c = :loanId
                ORDER BY Name
            ];
        } catch (Exception err) {
            throw new CustomException(err.getMessage());
        }
    }
}