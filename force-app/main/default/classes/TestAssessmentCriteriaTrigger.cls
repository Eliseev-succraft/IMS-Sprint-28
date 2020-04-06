@IsTest
private with sharing class TestAssessmentCriteriaTrigger {
    @IsTest static void test_run_validations() {
        // insert Fund
        Fund__c fund = TestUtils.createFund('Test Fund');
        insert fund;

        // insert Fund Assessors
        insert TestUtils.createFundAssessor(fund);

        // insert Assessment Stage Definitions
        Assessment_Stage_Definition__c asd = TestUtils.createAssessmentStageDefinition(fund, 'Application', null, 'Manual selection', 2);
        insert asd;

        // insert Assessment Criteria Definition__c
        Assessment_Criteria_Definition__c acd1 = TestUtils.createAssessmentCriteriaDefinition(asd, 'Rating');
        acd1.Name = 'AssessmentCriteria1';
        acd1.Minimum_Rating__c = 2;
        acd1.Maximum_Rating__c = 8;
        Assessment_Criteria_Definition__c acd2 = TestUtils.createAssessmentCriteriaDefinition(asd, 'Picklist');
        acd2.Name = 'AssessmentCriteria2';
        acd2.Picklist_Values__c = 'Value 1; Value 2; Value 3';
        insert new List<Assessment_Criteria_Definition__c>{acd1, acd2};

        // insert new Applications - true
        Application__c application = TestUtils.createNewApplication();
        application.Name = 'Name-12345678910';
        application.Fund__c = fund.Id;
        application.Stage__c = 'Application';
        insert application;
        
        // check results
        List<Assessment_Criteria__c> acList1 = [
            SELECT Rating__c, Assessment__c 
            FROM Assessment_Criteria__c 
            WHERE Name = 'AssessmentCriteria1' AND Type__c = 'Rating'
        ];

        List<Assessment_Criteria__c> acList2 = [
            SELECT Selected_Picklist_Value__c, Assessment__c
            FROM Assessment_Criteria__c 
            WHERE Name = 'AssessmentCriteria2' AND Type__c = 'Picklist'
        ];
        
        System.assertEquals(2, acList1.size(), 'Invalid Assessment_Criteria__c name');
        System.assertEquals(2, acList2.size(), 'Invalid Assessment_Criteria__c name');

        // update Rating
        acList1[0].Rating__c = 1;
        acList1[1].Rating__c = 9;

        // Perform test
        List<Database.SaveResult> resultList = Database.update(acList1, false);
        // Verify 
        // In this case the update should have been stopped by the trigger,
        // so verify that we got back an error.
        
        for (Database.SaveResult result : resultList) {
            System.assert(!result.isSuccess());
            System.assert(result.getErrors().size() > 0);
            System.assertEquals('Out of allowed range (Minimum Rating: ' + acd1.Minimum_Rating__c.intValue() + 
                ', Maximum Rating: ' + acd1.Maximum_Rating__c.intValue() + ')', result.getErrors()[0].getMessage());

        }

        // update Selected Picklist Value
        acList2[0].Selected_Picklist_Value__c = 'Value 4';

        // Perform test
        Database.SaveResult result1 = Database.update(acList2[0], false);
        // Verify 
        // In this case the update should have been stopped by the trigger,
        // so verify that we got back an error.
        
        System.assert(!result1.isSuccess());
        System.assert(result1.getErrors().size() > 0);
        System.assertEquals(System.Label.sfims.part_of_error_message_10 + ' "' + acList2[0].Selected_Picklist_Value__c + 
            '" '  + System.Label.sfims.part_of_error_message_11 + '.', result1.getErrors()[0].getMessage());

        // Block editing Assessment Criteria if Assessment Status is 'Approved' or 'Completed'.
        List<Assessment__c> assessments = [
            SELECT Status__c
            FROM Assessment__c
            WHERE Stage_Assessment_Lookup__r.Application__c = :application.Id
        ];
        System.assertEquals(2, assessments.size());

        // change the status
        assessments[0].Status__c = 'Approved';
        assessments[1].Status__c = 'Completed';
        update assessments;
        
        // try to edit assessment criteria
        acList1[0].Rating__c = 5;
        acList2[0].Selected_Picklist_Value__c = 'Value 2';
        
        // Perform test
        List<Database.SaveResult> resultList2 = Database.update(new List<Assessment_Criteria__c>{acList1[0], acList2[0]}, false);
        // Verify 
        // In this case the update should have been stopped by the trigger,
        // so verify that we got back an error.
        
        for (Database.SaveResult result : resultList2) {
            System.assert(!result.isSuccess());
            System.assert(result.getErrors().size() > 0);
            System.assertEquals(System.Label.sfims.error_message_39, result.getErrors()[0].getMessage());

        }
    }
}