/**
* @description         Application Assessment functionality
* @author              Alexey Eliseev
* @date                9/10/19
**/

@IsTest
private with sharing class TestAssessmentStageDefinitionTrigger {
    @IsTest static void test_AssessmentStageDefinitionTrigger() {
        Test.startTest();

        // Insert new AssessmentStageDefinition - exception
        try {
            insert new Assessment_Stage_Definition__c();
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_42), 'Invalid exception message');
        }
        System.assertEquals(0, [SELECT Id FROM Assessment_Stage_Definition__c].size(), 'Invalid size');

        // Insert new AssessmentStageDefinition - exception
        try {
            insert new Assessment_Stage_Definition__c(Application_Stage__c = null, Application_Assessment_Stage__c = null, Assessors__c = null, Fund__c = null);
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_42), 'Invalid exception message');
        }
        System.assertEquals(0, [SELECT Id FROM Assessment_Stage_Definition__c].size(), 'Invalid size');

        // Insert new AssessmentStageDefinition - exception
        try {
            insert new Assessment_Stage_Definition__c(Application_Stage__c = '', Application_Assessment_Stage__c = '', Assessors__c = 'Random fund assessor', Fund__c = null);
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_42), 'Invalid exception message');
        }
        System.assertEquals(0, [SELECT Id FROM Assessment_Stage_Definition__c].size(), 'Invalid size');

        // Insert new AssessmentStageDefinition - exception
        try {
            insert new Assessment_Stage_Definition__c(Application_Stage__c = 'Application_Stage_1', Application_Assessment_Stage__c = '', Fund__c = null);
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_42), 'Invalid exception message');
        }
        System.assertEquals(0, [SELECT Id FROM Assessment_Stage_Definition__c].size(), 'Invalid size');

        // Insert new AssessmentStageDefinition - true
        Fund__c fund1 = new Fund__c();
        try {
            insert fund1;
            insert new List<Fund_Assessor__c>{
                    new Fund_Assessor__c(Fund__c = fund1.Id), new Fund_Assessor__c(Fund__c = fund1.Id)
            };
            insert new Assessment_Stage_Definition__c(Application_Stage__c = 'Application_Stage_1', Application_Assessment_Stage__c = '', Assessors__c = 'Random fund assessor', Fund__c = fund1.Id, Number_of_Assessments__c = 2);
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        System.assertEquals(1, [SELECT Id FROM Assessment_Stage_Definition__c].size(), 'Invalid size');

        // Insert new AssessmentStageDefinition - exception
        try {
            insert new Assessment_Stage_Definition__c(Application_Stage__c = 'Application_Stage_1', Application_Assessment_Stage__c = '', Assessors__c = 'Random fund assessor', Fund__c = fund1.Id, Number_of_Assessments__c = 2);
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_40), 'Invalid exception message');
        }
        System.assertEquals(1, [SELECT Id FROM Assessment_Stage_Definition__c].size(), 'Invalid size');

        // Insert new AssessmentStageDefinition - true
        Assessment_Stage_Definition__c assessmentStageDefinition7 = new Assessment_Stage_Definition__c(Application_Stage__c = 'Application_Stage_1', Application_Assessment_Stage__c = 'ApplicationAssessmentStage_1', Assessors__c = 'Random fund assessor', Fund__c = fund1.Id, Number_of_Assessments__c = 2);
        try {
            insert assessmentStageDefinition7;
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        System.assertEquals(2, [SELECT Id FROM Assessment_Stage_Definition__c].size(), 'Invalid size');

        // Insert new AssessmentStageDefinition - exception
        try {
            insert new Assessment_Stage_Definition__c(Application_Stage__c = 'Application_Stage_1', Application_Assessment_Stage__c = 'ApplicationAssessmentStage_1', Assessors__c = 'Random fund assessor', Fund__c = fund1.Id, Number_of_Assessments__c = 2);
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_40), 'Invalid exception message');
        }
        System.assertEquals(2, [SELECT Id FROM Assessment_Stage_Definition__c].size(), 'Invalid size');

        // Insert new AssessmentStageDefinition - true
        Fund__c fund2 = new Fund__c();
        try {
            insert fund2;
            insert new List<Fund_Assessor__c>{
                    new Fund_Assessor__c(Fund__c = fund2.Id), new Fund_Assessor__c(Fund__c = fund2.Id)
            };
            insert new Assessment_Stage_Definition__c(Application_Stage__c = 'Application_Stage_1', Application_Assessment_Stage__c = 'ApplicationAssessmentStage_1', Assessors__c = 'Random fund assessor', Fund__c = fund2.Id, Number_of_Assessments__c = 1);
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        System.assertEquals(3, [SELECT Id FROM Assessment_Stage_Definition__c].size(), 'Invalid size');

        // Insert new AssessmentStageDefinition - exception
        try {
            insert new Assessment_Stage_Definition__c(Application_Stage__c = '', Application_Assessment_Stage__c = 'ApplicationAssessmentStage_1', Assessors__c = 'Random fund assessor', Number_of_Assessments__c = 2);
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_42), 'Invalid exception message');
        }
        System.assertEquals(3, [SELECT Id FROM Assessment_Stage_Definition__c].size(), 'Invalid size');

        // Update AssessmentStageDefinition - exception
        try {
            assessmentStageDefinition7.Assessors__c = null;
            update assessmentStageDefinition7;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_42), 'Invalid exception message');
        }

        // Update AssessmentStageDefinition - exception
        try {
            assessmentStageDefinition7.Assessors__c = 'Random fund assessor';
            assessmentStageDefinition7.Application_Assessment_Stage__c = '';
            update assessmentStageDefinition7;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_40), 'Invalid exception message');
        }

        // Update AssessmentStageDefinition - exception
        try {
            assessmentStageDefinition7.Application_Assessment_Stage__c = 'ApplicationAssessmentStage_1';
            assessmentStageDefinition7.Fund__c = fund2.Id;
            update assessmentStageDefinition7;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_40), 'Invalid exception message');
        }

        // Update AssessmentStageDefinition - exception
        try {
            assessmentStageDefinition7.Number_of_Assessments__c = 100;
            update assessmentStageDefinition7;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.part_of_error_message_12), 'Invalid exception message');
        }

        // Update AssessmentStageDefinition - exception
        try {
            assessmentStageDefinition7.Number_of_Assessments__c = null;
            update assessmentStageDefinition7;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_41), 'Invalid exception message');
        }

        // Update AssessmentStageDefinition - true
        try {
            assessmentStageDefinition7.Number_of_Assessments__c = 1;
            assessmentStageDefinition7.Application_Assessment_Stage__c = 'ApplicationAssessmentStage_2';
            update assessmentStageDefinition7;
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }

        // Update AssessmentStageDefinition - true
        try {
            update assessmentStageDefinition7;
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }

        Test.stopTest();
    }
}