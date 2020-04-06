@IsTest
private with sharing class TestAssessmentTrigger {
    @IsTest static void test_generate_assessment_name() {
        Test.startTest();

        // insert Fund
        Fund__c fund1 = TestUtils.createFund('fund1');
        insert fund1;

        // insert Fund Assessors
        Fund_Assessor__c fundAssessor1 = TestUtils.createFundAssessor(fund1);
        insert fundAssessor1;

        // insert Assessment Stage Definitions
        Assessment_Stage_Definition__c stage1 = TestUtils.createAssessmentStageDefinition(fund1, 'Application', null, 'Manual selection', 3);
        insert stage1;

        // insert Assessment Criteria Definition__c
        Assessment_Criteria_Definition__c criteria1 = TestUtils.createAssessmentCriteriaDefinition(stage1, 'Rating');
        Assessment_Criteria_Definition__c criteria2 = TestUtils.createAssessmentCriteriaDefinition(stage1, 'Text');
        insert new List<Assessment_Criteria_Definition__c>{
                criteria1, criteria2
        };

        // Insert new Applications - true
        Application__c application1 = TestUtils.createNewApplication();
        application1.Name = 'Name-12345678910';
        application1.Fund__c = fund1.Id;
        application1.Stage__c = 'Application';
        insert application1;
        System.assertEquals(1, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(3, [SELECT Name FROM Assessment__c WHERE Name = 'Application-Name-12345678910'].size(), 'Invalid Assessment__c name');
        
        Test.stopTest();
    }

    @IsTest static void test_populate_stage_assessment_fields() {
        // create a new stage assessment
        Stage_Assessment__c stageAssessment = new Stage_Assessment__c(Stage__c = 'Application');
        insert stageAssessment;

        // create a new assessment
        Assessment__c assessment1 = new Assessment__c(Stage_Assessment_Lookup__c = stageAssessment.Id, Outcome__c = 'Accepted', Status__c = 'Completed');
        Assessment__c assessment2 = new Assessment__c(Stage_Assessment_Lookup__c = stageAssessment.Id, Outcome__c = 'Rejected', Status__c = 'Completed');
        insert new List<Assessment__c>{assessment1, assessment2};
        
        // check the result
        Stage_Assessment__c result = [
            SELECT Number_of_Assessments__c, Number_of_Assessments_Accepted__c, Number_of_Assessments_Rejected__c
            FROM Stage_Assessment__c
            WHERE Id = :stageAssessment.Id 
        ];

        System.assertEquals(2, result.Number_of_Assessments__c);
        System.assertEquals(1, result.Number_of_Assessments_Accepted__c);
        System.assertEquals(1, result.Number_of_Assessments_Rejected__c);

        // update an assessment
        assessment1.Outcome__c = 'Rejected';
        update assessment1;

        // check the result
        Stage_Assessment__c result2 = [
            SELECT Number_of_Assessments__c, Number_of_Assessments_Accepted__c, Number_of_Assessments_Rejected__c
            FROM Stage_Assessment__c
            WHERE Id = :stageAssessment.Id 
        ];

        System.assertEquals(2, result2.Number_of_Assessments__c);
        System.assertEquals(0, result2.Number_of_Assessments_Accepted__c);
        System.assertEquals(2, result2.Number_of_Assessments_Rejected__c);
        
        // delete an assessment
        delete assessment1;

        // check the result
        Stage_Assessment__c result3 = [
            SELECT Number_of_Assessments__c, Number_of_Assessments_Accepted__c, Number_of_Assessments_Rejected__c
            FROM Stage_Assessment__c
            WHERE Id = :stageAssessment.Id 
        ];

        System.assertEquals(1, result3.Number_of_Assessments__c);
        System.assertEquals(0, result3.Number_of_Assessments_Accepted__c);
        System.assertEquals(1, result3.Number_of_Assessments_Rejected__c);
    }
}