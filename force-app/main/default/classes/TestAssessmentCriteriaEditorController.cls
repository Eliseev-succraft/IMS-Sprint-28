@IsTest
private with sharing class TestAssessmentCriteriaEditorController {
    @IsTest static void test_AssessmentCriteriaEditorController() {
        Test.startTest();
        Assessment__c assessment = new Assessment__c(
            Name = 'Test',
            Status__c = 'Pending'
        );
        insert assessment;
        System.assertEquals(1, [SELECT Id FROM Assessment__c].size(), 'Invalid size');
        Assessment_Criteria__c criteria1 = new Assessment_Criteria__c(Assessment__c = assessment.Id, Type__c = 'Text');
        Assessment_Criteria__c criteria2 = new Assessment_Criteria__c(Assessment__c = assessment.Id, Type__c = 'Text');
        Assessment_Criteria__c criteria3 = new Assessment_Criteria__c(Assessment__c = assessment.Id, Type__c = 'Text');
        insert new List<Assessment_Criteria__c>{
                criteria1, criteria2, criteria3
        };
        System.assertEquals(3, [SELECT Id FROM Assessment_Criteria__c].size(), 'Invalid size');
        System.assertEquals(3, AssessmentCriteriaEditorController.getAssessmentCriteria(assessment.Id).size(), 'Invalid size');
        criteria1.Name = 'UpdateName';
        System.assertEquals(true, AssessmentCriteriaEditorController.setAssessmentCriteria(new List<Assessment_Criteria__c>{
                criteria1, criteria2, criteria3
        }), 'Invalid save');
        System.assertEquals(1, [SELECT Id FROM Assessment_Criteria__c WHERE Name = 'UpdateName'].size(), 'Invalid size');
        delete [SELECT Id FROM Assessment_Criteria__c WHERE Id =: criteria1.Id];
        try {
            AssessmentCriteriaEditorController.setAssessmentCriteria(new List<Assessment_Criteria__c>{
                criteria1, criteria2, criteria3
            });
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
           
        }
        Test.stopTest();
    }
}