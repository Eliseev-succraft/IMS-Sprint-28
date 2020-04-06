@isTest
private class TestReportTemplateTrigger {
    @isTest static void test_delete() {
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
        for (Integer i = 0; i < 3; i++) {
            listIndicators.add(new Indicator_Catalogue__c(Active__c = true, Indicator_Name__c = 'Indicator_Name__' + i,
                    Indicator_Type__c = 'Number', Outcome_Area__c = 'Health', RecordTypeId = recordTypeIdCatalogue));
        }
        insert listIndicators;
        List<Report_Template_Indicator__c> junctionObjects = new List<Report_Template_Indicator__c>();
        for (Integer j = 0; j < 3; j++) {
            junctionObjects.add(new Report_Template_Indicator__c(Indicator_Catalogue__c = listIndicators[j].Id, Report_Template__c = testTemplate.Id));
        }
        insert junctionObjects;
        System.assertEquals([SELECT Id FROM Report_Template_Indicator__c WHERE Report_Template__c = :testTemplate.Id].size(), 3);
        
        delete testTemplate;
        System.assert([SELECT Id FROM Report_Template_Indicator__c].isEmpty());
        Test.stopTest();
    }
}