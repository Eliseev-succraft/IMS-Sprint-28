/** Application Assessment functionality * @author Alexey Eliseev * @date 10/8/19 **/

@IsTest
public with sharing class TestStageAssessmentTrigger {
    @IsTest static void test_StageAssessmentTrigger() {
        Test.startTest();

        // insert Fund and Account
        Fund__c fund1 = TestUtils.createFund('fund1');
        Account acc = TestUtils.createAccount('Investee_Account');
        insert new List<SObject>{ fund1, acc };

        // insert Fund Assessors
        Fund_Assessor__c fundAssessor1 = TestUtils.createFundAssessor(fund1);
        insert fundAssessor1;

        // insert Assessment Stage Definitions
        Assessment_Stage_Definition__c stage1 = TestUtils.createAssessmentStageDefinition(fund1, 'Application', null, 'Manual selection', 3);
        Assessment_Stage_Definition__c stage2 = TestUtils.createAssessmentStageDefinition(fund1, 'Application', 'Tier 1', 'Manual selection', 5);
        insert new List<Assessment_Stage_Definition__c>{
                stage1, stage2
        };

        // insert Assessment Criteria Definition__c
        Assessment_Criteria_Definition__c criteria1 = TestUtils.createAssessmentCriteriaDefinition(stage1, 'Rating');
        Assessment_Criteria_Definition__c criteria2 = TestUtils.createAssessmentCriteriaDefinition(stage1, 'Text');
        insert new List<Assessment_Criteria_Definition__c>{
                criteria1, criteria2
        };

        // Insert new Applications - true
        Application__c application1 = TestUtils.createNewApplication(acc.Id);
        application1.Name = 'Name-12345678910';
        application1.Fund__c = fund1.Id;
        application1.Stage__c = 'Application';
        insert application1;
        System.assertEquals(1, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(1, [SELECT Id FROM Stage_Assessment__c WHERE Assessment_Stage__c = NULL].size(), 'Invalid size Stage_Assessment__c');
        System.assertEquals(3, [SELECT Id FROM Assessment__c].size(), 'Invalid size Assessment__c');
        System.assertEquals(6, [SELECT Id FROM Assessment_Criteria__c].size(), 'Invalid size Assessment_Criteria__c');
        System.assertEquals('Application-Name-12345678910', [SELECT Name FROM Stage_Assessment__c WHERE Assessment_Stage__c = NULL].Name, 'Invalid Stage_Assessment__c name');

        // Insert new Application - true
        Application__c application2 = TestUtils.createNewApplication(acc.Id);
        application2.Name = 'Name-123456789101112131415161718192021222324252627282930313233343536373839404142';
        application2.Fund__c = fund1.Id;
        application2.Stage__c = 'Application';
        application2.Assessment_Stage__c = 'Tier 1';
        insert application2;
        System.assertEquals(2, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(1, [SELECT Id FROM Stage_Assessment__c WHERE Assessment_Stage__c = 'Tier 1'].size(), 'Invalid size Stage_Assessment__c');
        System.assertEquals(8, [SELECT Id FROM Assessment__c].size(), 'Invalid size Assessment__c');
        System.assertEquals(6, [SELECT Id FROM Assessment_Criteria__c].size(), 'Invalid size Assessment_Criteria__c');
        System.assertEquals('Application-Tier 1-Name-12345678910111213141516171819202122232425262728293031323', [SELECT Name FROM Stage_Assessment__c WHERE Assessment_Stage__c = 'Tier 1'].Name, 'Invalid Stage_Assessment__c name');

        Test.stopTest();
    }
}