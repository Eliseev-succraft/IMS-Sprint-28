/*
 * @description         This is unit test for SheduleReports
 * @author              Alexey Eliseev
 * @component           SheduleReports
 * @date                2/4/19
*/

@isTest
private with sharing class TestScheduleReportsController {
    @isTest static void test_ScheduleReportsController() {
        Test.startTest();
        Application__c testApplication = TestUtils.createNewApplication();
        insert testApplication;

        Report_Template__c testTemplate = new Report_Template__c(Name = 'Template1', Active__c = true);
        insert testTemplate;

        Map<String, RecordTypeInfo> recorsTypesMap = Schema.SObjectType.sfims__Indicator_Catalogue__c.getRecordTypeInfosByName();
        Id recordTypeIdCatalogue;
        for (String key : recorsTypesMap.keySet()) {
            if (recorsTypesMap.get(key).getName() != 'Master' ) {
                recordTypeIdCatalogue = recorsTypesMap.get(key).getRecordTypeId();
                break;
            }
        }

        List<Indicator_Catalogue__c> listIndicators = new List<Indicator_Catalogue__c>();
        for (Integer i = 0; i < 10; i++) {
            listIndicators.add(new Indicator_Catalogue__c(Active__c = true, Indicator_Name__c = 'Indicator_Name__' + i,
                    Indicator_Type__c = 'Number', Outcome_Area__c = 'Housing and local facilities', RecordTypeId = recordTypeIdCatalogue));
        }
        insert listIndicators;

        list<Report_Template_Indicator__c> junctionObject = new list<Report_Template_Indicator__c>();
        List<Id> indicatorIds = new List<Id>();
        for (Integer j = 0; j < 5; j++) {
            junctionObject.add(new Report_Template_Indicator__c(Indicator_Catalogue__c = listIndicators[j].Id, Report_Template__c = testTemplate.Id));
            indicatorIds.add(listIndicators[j].Id);
        }
        insert junctionObject;

        Progress_Report__c returnDataTest0 = new Progress_Report__c();
        insert returnDataTest0;

        system.assertEquals(0, [
                SELECT count()
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :returnDataTest0.Id
        ], 'Invalid count of Progress Report Indicators - Test 0');

        List<Progress_Report__c> returnDataTest1 = ScheduleReportsController.generatedProgressReport(testApplication.Id, testTemplate.Id, '2019-01-16', 'Monthly', 2);
        List<Progress_Report__c> returnDataTest2 = ScheduleReportsController.generatedProgressReport(testApplication.Id, testTemplate.Id, '2025-02-10', 'Quarterly', 3);
        List<Progress_Report__c> returnDataTest3 = ScheduleReportsController.generatedProgressReport(testApplication.Id, testTemplate.Id, '2030-03-05', 'Yearly', 4);

        system.assertEquals(10, [
                SELECT count()
                FROM Progress_Report__c
        ], 'Invalid count of Progress Report');
        system.assertEquals(2, [
                SELECT count()
                FROM Progress_Report__c
                WHERE Report_Template__c = :testTemplate.Id AND Report_Due_Date__c IN (2019-01-16, 2019-02-16)
        ], 'Invalid count of Progress Report - Monthly');
        system.assertEquals(3, [
                SELECT count()
                FROM Progress_Report__c
                WHERE Report_Template__c = :testTemplate.Id AND Report_Due_Date__c IN (2025-02-10, 2025-05-10, 2025-08-10)
        ], 'Invalid count of Progress Report - Quarterly');
        system.assertEquals(4, [
                SELECT count()
                FROM Progress_Report__c
                WHERE Report_Template__c = :testTemplate.Id AND Report_Due_Date__c IN (2030-03-05, 2031-03-05, 2032-03-05, 2033-03-05)
        ], 'Invalid count of Progress Report - Yearly');

        /*----------------------------- Test 1 Monthly ------------------------- */

        system.assertEquals(5, [
                SELECT count()
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :returnDataTest1[0].Id AND Indicator_Catalogue__c IN :indicatorIds
        ], 'Invalid count of Progress Report Indicators - Test 1');
        system.assertEquals(5, [
                SELECT count()
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :returnDataTest1[1].Id AND Indicator_Catalogue__c IN :indicatorIds
        ], 'Invalid count of Progress Report Indicators - Test 1');

        /*----------------------------- Test 2 Quarterly ------------------------- */

        system.assertEquals(5, [
                SELECT count()
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :returnDataTest2[0].Id AND Indicator_Catalogue__c IN :indicatorIds
        ], 'Invalid count of Progress Report Indicators - Test 2');
        system.assertEquals(5, [
                SELECT count()
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :returnDataTest2[1].Id AND Indicator_Catalogue__c IN :indicatorIds
        ], 'Invalid count of Progress Report Indicators - Test 2');
        system.assertEquals(5, [
                SELECT count()
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :returnDataTest2[2].Id AND Indicator_Catalogue__c IN :indicatorIds
        ], 'Invalid count of Progress Report Indicators - Test 2');

        /*----------------------------- Test 3 Yearly ------------------------- */

        system.assertEquals(5, [
                SELECT count()
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :returnDataTest3[0].Id AND Indicator_Catalogue__c IN :indicatorIds
        ], 'Invalid count of Progress Report Indicators - Test 3');
        system.assertEquals(5, [
                SELECT count()
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :returnDataTest3[1].Id AND Indicator_Catalogue__c IN :indicatorIds
        ], 'Invalid count of Progress Report Indicators - Test 3');
        system.assertEquals(5, [
                SELECT count()
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :returnDataTest3[2].Id AND Indicator_Catalogue__c IN :indicatorIds
        ], 'Invalid count of Progress Report Indicators - Test 3');
        system.assertEquals(5, [
                SELECT count()
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :returnDataTest3[3].Id AND Indicator_Catalogue__c IN :indicatorIds
        ], 'Invalid count of Progress Report Indicators - Test 3');

        /*----------------------------- Progress Report Trigger Test (delete) ------------------------- */

        system.assertEquals(5, [
                SELECT count()
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :returnDataTest1[0].Id
        ], 'Invalid count of Progress Report Indicators - Progress Report Trigger Test');

        system.assertEquals(1, [
                SELECT count()
                FROM Progress_Report__c
                WHERE Id = :returnDataTest1[0].Id
        ], 'Invalid count of Progress Report - Progress Report Trigger Test');

        delete returnDataTest1[0];

        system.assertEquals(0, [
                SELECT count()
                FROM Progress_Report__c
                WHERE Id = :returnDataTest1[0].Id
        ], 'Invalid count of Progress Report - Progress Report Trigger Test');

        system.assertEquals(0, [
                SELECT count()
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :returnDataTest1[0].Id
        ], 'Invalid count of Progress Report Indicators - Progress Report Trigger Test');

        Test.stopTest();
    }
}