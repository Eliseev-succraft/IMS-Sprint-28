/*
 * @description         This is unit test for Progress Report Indicators Editor
 * @author              Alexey Eliseev
 * @component           progressReportIndicatorsEditor
 * @date                2/15/19
*/

@isTest
private with sharing class TestProgReportIndicatorsEditorController {
    @isTest static void test_ProgressReportIndicatorsEditorController() {
        Test.startTest();

        Map<String, RecordTypeInfo> recorsTypesMap = Schema.SObjectType.sfims__Indicator_Catalogue__c.getRecordTypeInfosByName();
        Id recordTypeIdCatalogue;
        for (String key : recorsTypesMap.keySet()) {
            if ((string)recorsTypesMap.get(key).getName() == 'IRIS') {
                recordTypeIdCatalogue = recorsTypesMap.get(key).getRecordTypeId();
                break;
            }
        }

        List<Indicator_Catalogue__c> listIndicators = new List<Indicator_Catalogue__c>();
        for (Integer i = 0; i < 10; i++) {
            listIndicators.add(new Indicator_Catalogue__c(Active__c = true, Indicator_Name__c = 'Indicator_Name__' + i,
                    Indicator_Type__c = 'Number', Outcome_Area__c = 'Agriculture', RecordTypeId = recordTypeIdCatalogue));
        }
        insert listIndicators;

        List<sfims__Progress_Report__c> listReports = new List<sfims__Progress_Report__c>();
        for (Integer i = 0; i < 3; i++) {
            listReports.add(new sfims__Progress_Report__c());
        }
        insert listReports;

        List<Progress_Report_Indicators__c> listProgressIndicators = new List<Progress_Report_Indicators__c>();
        for (Integer i = 0; i < 10; i++) {
            listProgressIndicators.add(new Progress_Report_Indicators__c(Progress_Report__c = listReports[0].Id, Indicator_Catalogue__c = listIndicators[i].Id));
        }

        insert listProgressIndicators;

        system.assertEquals('[]', progressReportIndicatorsEditorController.getProgressReportIndicators(null), 'Invalid results Progress Report Indicators');

        try {
            progressReportIndicatorsEditorController.getProgressReportIndicators('test');
        } catch (exception e) {
            system.assertEquals(string.valueOf(e), 'System.StringException: Invalid id: test');
        }

        system.assertEquals(JSON.serialize([
                SELECT Indicator_Catalogue__r.Indicator_Name__c,
                        Indicator_Catalogue__r.Indicator_Type__c,
                        Target_Value_Number__c, Target_Value_Currency__c, Target_Value_Text__c, Target_Value_Percentage__c, Target_Value_Text_Area_Long__c,
                        Actual_Value_Number__c, Actual_Value_Currency__c, Actual_Value_Text__c, Actual_Value_Percentage__c, Actual_Value_Text_Area_Long__c,
                        Variance_Value_Number__c, Variance_Value_Currency__c, Variance_Value_Text__c, Variance_Value_Percentage__c, Variance_Value_Text_Area_Long__c,
                        Comment__c
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :listReports[0].Id
        ]), progressReportIndicatorsEditorController.getProgressReportIndicators(listReports[0].Id), 'Invalid results Progress Report Indicators');

        system.assertEquals(false, progressReportIndicatorsEditorController.saveProgressReportIndicators(null), 'Invalid save results');

        List<progressReportIndicatorsEditorController.progressReportIndicatorsEditorRowClass> testClass = new List<progressReportIndicatorsEditorController.progressReportIndicatorsEditorRowClass>();


        List<String> types = new List<String>{
                'Number', 'Currency', 'Percentage', 'Text', 'Text Area (Long)'
        };
        List<String> names = new List<String>{
                'sfims__Actual_Value_Number__c', 'sfims__Target_Value_Number__c', 'sfims__Variance_Value_Number__c', 'sfims__Comment__c'
        };
        List<String> namesText = new List<String>{
                'sfims__Actual_Value_Text__c', 'sfims__Target_Value_Text__c', 'sfims__Variance_Value_Text__c', 'sfims__Comment__c'
        };

        Integer listProgressIndicatorsSize = listProgressIndicators.size();
        for (Integer i = 0; i < 5; i++) {

            List<Map<String, String>> testCols = new List<Map<String, String>>();

            for (Integer k = 0; k < 4; k++) {
                Map<String, String> itemMap;
                if ((types[i] == 'Text') || (types[i] == 'Text Area (Long)')) {
                    itemMap = new Map<String, String>{
                            'name' => namesText[k], 'value' => '', 'reset' => ''
                    };
                } else {
                    itemMap = new Map<String, String>{
                            'name' => names[k], 'value' => '', 'reset' => ''
                    };
                }
                testCols.add(itemMap);
            }

            progressReportIndicatorsEditorController.progressReportIndicatorsEditorRowClass testItemClass = new progressReportIndicatorsEditorController.progressReportIndicatorsEditorRowClass();
            testItemClass.id = listProgressIndicators[i].Id;
            testItemClass.type = types[i];
            testItemClass.name = 'TestName' + i;
            testItemClass.cols = testCols;

            testClass.add(testItemClass);
        }

        system.assertEquals(true, progressReportIndicatorsEditorController.saveProgressReportIndicators(JSON.serialize(testClass)), 'Invalid save results');

        delete [SELECT Id FROM Progress_Report_Indicators__c WHERE Id =: testClass[0].Id];
        for (progressReportIndicatorsEditorController.progressReportIndicatorsEditorRowClass p : testClass) {
            for (Integer k = 0; k < 4; k++) {
                p.cols[k].put('value', '1');
            }
        }

        try {
            progressReportIndicatorsEditorController.saveProgressReportIndicators(JSON.serialize(testClass));
        } catch (exception e) {
            system.assertEquals(string.valueOf(e), 'showException:[]: ' + System.Label.sfims.error_message_6);
        }

        Test.stopTest();
    }
}