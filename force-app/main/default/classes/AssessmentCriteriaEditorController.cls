public without sharing class AssessmentCriteriaEditorController {
    public class CustomException extends Exception {
    }

    @AuraEnabled
    public static List<Assessment_Criteria__c> getAssessmentCriteria(Id assessmentId) {
        try {
            return [SELECT Name, Type__c, Rating__c, Selected_Picklist_Value__c, Comment__c, Assessment_Criteria_Definition__r.Picklist_Values__c, Assessment_Criteria_Definition__r.Minimum_Rating__c, Assessment_Criteria_Definition__r.Maximum_Rating__c, Assessment_Criteria_Definition__r.sfims__Description__c FROM Assessment_Criteria__c WHERE Assessment__c = :assessmentId];
        } catch (Exception err) {
            throw new CustomException(err.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean setAssessmentCriteria(List<Assessment_Criteria__c> criteria) {
        try {
            update criteria;
            return true;
        } catch (Exception err) {
            throw new CustomException(err.getMessage());
        }
    }
}