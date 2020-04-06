@isTest
private without sharing class TestReportTemplateController {
    @isTest static void test_ReportTemplateController() {
        Test.startTest();
        Report_Template__c testTemplate = new Report_Template__c(Name = 'Template1', Active__c = true);
        insert testTemplate;
        Map<String, RecordTypeInfo> recordTypesMap = Schema.SObjectType.sfims__Indicator_Catalogue__c.getRecordTypeInfosByName();
        Id recordTypeIdCatalogue;
        for (String key : recordTypesMap.keySet()) {
            if (recordTypesMap.get(key).getName() != 'Master' ) {
                recordTypeIdCatalogue = recordTypesMap.get(key).getRecordTypeId();
                break;
            }
        }
        List<Indicator_Catalogue__c> listIndicators = new List<Indicator_Catalogue__c>();
        for (Integer i = 0; i < 10; i++) {
            listIndicators.add(new Indicator_Catalogue__c(Active__c = true, Indicator_Name__c = 'Indicator_Name__' + i,
                    Indicator_Type__c = 'Number', Outcome_Area__c = 'Health', RecordTypeId = recordTypeIdCatalogue));
        }
        insert listIndicators;
        List<Report_Template_Indicator__c> junctionObject = new List<Report_Template_Indicator__c>();
        List<Id> newListIndicators = new List<Id>();
        List<Id> oldListIndicators = new List<Id>();
        for (Integer j = 0; j < 5; j++) {
            newListIndicators.add(listIndicators[j].Id);
            oldListIndicators.add(listIndicators[j + 3].Id);
            junctionObject.add(new Report_Template_Indicator__c(Indicator_Catalogue__c = listIndicators[j + 3].Id, Report_Template__c = testTemplate.Id));
        }
        insert junctionObject;
        System.assertEquals([SELECT Id, Name FROM Report_Template__c WHERE Id = :testTemplate.Id], ReportTemplateController.saveReportTemplateIndicators(newListIndicators, testTemplate.Id), 'Invalid return');
        try {
            ReportTemplateController.getLibraries();
            ReportTemplateController.getAllRecordTypes();
            ReportTemplateController.getLayoutFields('Custom Indicator Catalogue Layout', new List<String>());
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        Test.stopTest();
    }
}