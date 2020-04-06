@IsTest
private class TestApplicationTriggerHandler {

    @IsTest static void test_application_stage_edited_as_platform_user() {
        User platformUser = TestUtils.createPlatformUser();

        Milestone_Configuration__c mc1 = TestUtils.createNewMilestoneConfiguration('Application', 'Enquiry', 'Expression of Interest', 1);
        Milestone_Configuration__c mc2 = TestUtils.createNewMilestoneConfiguration('Application', 'Application', 'Application', 2);

        Application__c app = TestUtils.createNewApplication();
        app.Stage__c = 'Enquiry';

        // admin creates the setup
        System.runAs(new User(ID = UserInfo.getUserId())) {
            insert new List<SObject>{
                    mc1, mc2, app
            };

            List<Milestone_History__c> mhList = [
                    SELECT Milestone__c, Milestone_Date__c, Days_in_Milestone__c, Application__c, Sequence__c
                    FROM Milestone_History__c
                    ORDER BY Sequence__c DESC
            ];

            System.assertEquals(1, mhList.size());
            System.assertEquals(app.Id, mhList[0].Application__c);
            System.assertEquals('Expression of Interest', mhList[0].Milestone__c);
        }
        // platform user triggers the logic
        System.runAs(platformUser) {

            app.Stage__c = 'Application';
            update app;

            List<Milestone_History__c> mhList2 = [
                    SELECT Milestone__c, Milestone_Date__c, Days_in_Milestone__c, Application__c, Sequence__c
                    FROM Milestone_History__c
                    ORDER BY Sequence__c DESC
            ];

            System.assertEquals(2, mhList2.size());
            System.assertEquals(app.Id, mhList2[0].Application__c);
            System.assertEquals(null, mhList2[1].Days_in_Milestone__c);
        }
    }

    @IsTest static void test_generate_attachment() {
        Application__c app = TestUtils.createNewApplication();
        app.FormAssembly_EOI_content__c = 'EOI content';
        app.FormAssembly_Full_Application_content__c = 'Full content';
        insert app;

        Application__c application = [SELECT Id, FormAssembly_EOI_Attachment_Name__c, FormAssembly_Application_Attach_Name__c FROM Application__c WHERE Id = :app.Id];
        List<Attachment> attachments = [SELECT Id, ParentId, Name FROM Attachment WHERE ParentId = :app.Id ORDER BY Name ASC];
        System.assertEquals(2, attachments.size());
        System.assertEquals(application.FormAssembly_EOI_Attachment_Name__c, attachments[0].Name);
        System.assertEquals(application.FormAssembly_Application_Attach_Name__c, attachments[1].Name);

        app.FormAssembly_EOI_content__c = 'EOI content updated';
        app.FormAssembly_Full_Application_content__c = 'Full content updated';
        update app;

        List<Attachment> newAttachments = [SELECT Id, ParentId, Name FROM Attachment WHERE ParentId = :app.Id ORDER BY Name ASC];
        System.assertEquals(2, newAttachments.size());
        System.assertEquals(application.FormAssembly_EOI_Attachment_Name__c, newAttachments[0].Name);
        System.assertEquals(application.FormAssembly_Application_Attach_Name__c, newAttachments[1].Name);
        System.assertNotEquals(attachments[0].Id, newAttachments[0].Id);
        System.assertNotEquals(attachments[1].Id, newAttachments[1].Id);
    }

    @IsTest static void test_delete_child_records() {
        Application__c app = TestUtils.createNewApplication();
        insert app;
        Progress_Report__c pr = new Progress_Report__c(Application__c = app.Id);
        insert pr;

        delete app;

        List<Progress_Report__c> progressReports = [
                SELECT Id
                FROM Progress_Report__c
                WHERE Application__c = :app.Id
        ];

        System.assertEquals(0, progressReports.size());
    }

    @IsTest static void test_create_assessments() {
        // insert account
        Account acc = TestUtils.createAccount('Investee_Account');
        // insert Fund
        Fund__c fund1 = TestUtils.createFund('fund1');
        Fund__c fund2 = TestUtils.createFund('fund2');
        insert new List<SObject>{ acc, fund1, fund2 };

        // insert Fund Assessors
        Fund_Assessor__c fundAssessor1 = TestUtils.createFundAssessor(fund2);
        Fund_Assessor__c fundAssessor2 = TestUtils.createFundAssessor(fund2);
        Fund_Assessor__c fundAssessor3 = TestUtils.createFundAssessor(fund1);
        Fund_Assessor__c fundAssessor4 = TestUtils.createFundAssessor(fund1);
        insert new List<Fund_Assessor__c>{
                fundAssessor1, fundAssessor2, fundAssessor3, fundAssessor4
        };

        // insert Assessment Stage Definitions
        Assessment_Stage_Definition__c stage1 = TestUtils.createAssessmentStageDefinition(fund1, 'Application', null, 'Random fund assessor', 2);
        Assessment_Stage_Definition__c stage2 = TestUtils.createAssessmentStageDefinition(fund1, 'Application', 'Tier 1', 'Manual selection', 5);
        Assessment_Stage_Definition__c stage3 = TestUtils.createAssessmentStageDefinition(fund2, 'Application', null, 'All fund assessors');
        Assessment_Stage_Definition__c stage4 = TestUtils.createAssessmentStageDefinition(fund2, 'Application', 'Tier 1', 'Random fund assessor', 1);
        insert new List<Assessment_Stage_Definition__c>{
                stage1, stage2, stage3, stage4
        };

        // insert Assessment Criteria Definition__c
        Assessment_Criteria_Definition__c criteria1 = TestUtils.createAssessmentCriteriaDefinition(stage1, 'Rating');
        Assessment_Criteria_Definition__c criteria2 = TestUtils.createAssessmentCriteriaDefinition(stage2, 'Text');
        insert new List<Assessment_Criteria_Definition__c>{
                criteria1, criteria2
        };

        // Insert new Application - true
        Application__c application1 = TestUtils.createNewApplication(acc.Id);
        insert application1;
        System.assertEquals(1, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(0, [SELECT Id FROM Stage_Assessment__c].size(), 'Invalid size Stage_Assessment__c');
        System.assertEquals(0, [SELECT Id FROM Assessment__c].size(), 'Invalid size Assessment__c');
        System.assertEquals(0, [SELECT Id FROM Assessment_Criteria__c].size(), 'Invalid size Assessment_Criteria__c');

        // Insert new Application - true
        Application__c application2 = TestUtils.createNewApplication(acc.Id);
        application2.Fund__c = fund1.Id;
        insert application2;
        System.assertEquals(2, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(0, [SELECT Id FROM Stage_Assessment__c].size(), 'Invalid size Stage_Assessment__c');
        System.assertEquals(0, [SELECT Id FROM Assessment__c].size(), 'Invalid size Assessment__c');
        System.assertEquals(0, [SELECT Id FROM Assessment_Criteria__c].size(), 'Invalid size Assessment_Criteria__c');

        // Update Application - true
        application2.Assessment_Stage__c = 'Tier 1';
        update application2;
        System.assertEquals(2, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(0, [SELECT Id FROM Stage_Assessment__c].size(), 'Invalid size Stage_Assessment__c');
        System.assertEquals(0, [SELECT Id FROM Assessment__c].size(), 'Invalid size Assessment__c');
        System.assertEquals(0, [SELECT Id FROM Assessment_Criteria__c].size(), 'Invalid size Assessment_Criteria__c');

        // Update Application - true
        application2.Stage__c = 'Application';
        application2.Assessment_Stage__c = 'Tier 1';
        update application2;
        System.assertEquals(2, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(1, [SELECT Id FROM Stage_Assessment__c].size(), 'Invalid size Stage_Assessment__c');
        System.assertEquals(5, [SELECT Id FROM Assessment__c].size(), 'Invalid size Assessment__c');
        System.assertEquals(5, [SELECT Id FROM Assessment_Criteria__c WHERE Type__c = 'Text'].size(), 'Invalid size Assessment_Criteria__c');

        // Update Application - true
        application2.Stage__c = 'Enquiry';
        application2.Assessment_Stage__c = 'Tier 1';
        update application2;
        Map<Id, Assessment__c> delMap = new Map<Id, Assessment__c>([SELECT Id FROM Assessment__c LIMIT 2]);
        delete [SELECT Id FROM Assessment__c WHERE Id IN :delMap.keySet()];
        System.assertEquals(2, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(1, [SELECT Id FROM Stage_Assessment__c].size(), 'Invalid size Stage_Assessment__c');
        System.assertEquals(3, [SELECT Id FROM Assessment__c].size(), 'Invalid size Assessment__c');
        System.assertEquals(3, [SELECT Id FROM Assessment_Criteria__c WHERE Type__c = 'Text'].size(), 'Invalid size Assessment_Criteria__c');

        // Update Application - true
        application2.Stage__c = 'Application';
        application2.Assessment_Stage__c = 'Tier 1';
        update application2;
        System.assertEquals(2, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(1, [SELECT Id FROM Stage_Assessment__c].size(), 'Invalid size Stage_Assessment__c');
        System.assertEquals(3, [SELECT Id FROM Assessment__c].size(), 'Invalid size Assessment__c');
        System.assertEquals(3, [SELECT Id FROM Assessment_Criteria__c WHERE Type__c = 'Text'].size(), 'Invalid size Assessment_Criteria__c');

        Test.startTest();

        // Update Application - true
        delete [SELECT Id FROM Assessment__c];
        application2.Stage__c = 'Enquiry';
        application2.Assessment_Stage__c = 'Tier 1';
        update application2;
        System.assertEquals(2, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(1, [SELECT Id FROM Stage_Assessment__c].size(), 'Invalid size Stage_Assessment__c');
        System.assertEquals(0, [SELECT Id FROM Assessment__c].size(), 'Invalid size Assessment__c');
        System.assertEquals(0, [SELECT Id FROM Assessment_Criteria__c WHERE Type__c = 'Text'].size(), 'Invalid size Assessment_Criteria__c');

        // Update Application - true
        delete [SELECT Id FROM Assessment__c];
        application2.Stage__c = 'Application';
        application2.Assessment_Stage__c = 'Tier 1';
        update application2;
        System.assertEquals(2, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(1, [SELECT Id FROM Stage_Assessment__c].size(), 'Invalid size Stage_Assessment__c');
        System.assertEquals(5, [SELECT Id FROM Assessment__c].size(), 'Invalid size Assessment__c');
        System.assertEquals(5, [SELECT Id FROM Assessment_Criteria__c WHERE Type__c = 'Text'].size(), 'Invalid size Assessment_Criteria__c');
        application2.Name = 'New';
        update application2;

        // Insert new Application - true
        Application__c application3 = TestUtils.createNewApplication(acc.Id);
        application3.Fund__c = fund2.Id;
        application3.Assessment_Stage__c = 'Tier 1';
        application3.Stage__c = 'Application';
        insert application3;
        System.assertEquals(3, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(2, [SELECT Id FROM Stage_Assessment__c].size(), 'Invalid size Stage_Assessment__c');
        System.assertEquals(6, [SELECT Id FROM Assessment__c].size(), 'Invalid size Assessment__c');
        System.assertEquals(5, [SELECT Id FROM Assessment_Criteria__c WHERE Type__c = 'Text'].size(), 'Invalid size Assessment_Criteria__c');

        // Insert new Application - true
        Application__c application4 = TestUtils.createNewApplication(acc.Id);
        application4.Fund__c = fund1.Id; 
        application4.Stage__c = 'Application';
        insert application4;
        System.assertEquals(4, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(3, [SELECT Id FROM Stage_Assessment__c].size(), 'Invalid size Stage_Assessment__c');
        System.assertEquals(8, [SELECT Id FROM Assessment__c].size(), 'Invalid size Assessment__c');
        System.assertEquals(7, [SELECT Id FROM Assessment_Criteria__c].size(), 'Invalid size Assessment_Criteria__c');

        // Insert new Application - true
        Application__c application5 = TestUtils.createNewApplication(acc.Id);
        application5.Fund__c = fund2.Id;
        application5.Stage__c = 'Application';
        application5.Assessment_Stage__c = 'Tier 2';
        insert application5;
        System.assertEquals(5, [SELECT Id FROM Application__c].size(), 'Invalid size Application__c');
        System.assertEquals(4, [SELECT Id FROM Stage_Assessment__c].size(), 'Invalid size Stage_Assessment__c');
        System.assertEquals(10, [SELECT Id FROM Assessment__c].size(), 'Invalid size Assessment__c');
        System.assertEquals(7, [SELECT Id FROM Assessment_Criteria__c].size(), 'Invalid size Assessment_Criteria__c');

        Test.stopTest();
    }
}