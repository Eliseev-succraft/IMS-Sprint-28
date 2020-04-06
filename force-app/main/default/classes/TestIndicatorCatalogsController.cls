@isTest
private without sharing class TestIndicatorCatalogsController {
    @isTest static void test_IndicatorCatalogsController() {
        Test.startTest();
        Map<String, RecordTypeInfo> recordTypesMap = Schema.SObjectType.sfims__Indicator_Catalogue__c.getRecordTypeInfosByName();
        List<Id> recordTypeIdCatalogueIds = new List<Id>();
        for (String key : recordTypesMap.keySet()) {
            if (recordTypesMap.get(key).getName() != 'Master') {
                recordTypeIdCatalogueIds.add(recordTypesMap.get(key).getRecordTypeId());
                break;
            }
        }
        List<String> defaultFields = new List<String>{
                'sfims__Indicator_Name__c',
                'sfims__Indicator_Type__c',
                'sfims__Definition__c',
                'sfims__Outcome_Area__c'
        };
        List<Indicator_Catalogue_Setting__c> testDataSettings = new List<Indicator_Catalogue_Setting__c>();
        for (Integer i = 0; i < 4; i++) {
            testDataSettings.add(
                    new Indicator_Catalogue_Setting__c(
                            Name = 'TestName' + i,
                            sfims__recordTypeId__c = recordTypeIdCatalogueIds[0],
                            sfims__fieldName__c = defaultFields[i],
                            sfims__Active__c = true
                    )
            );
        }
        try {
            System.assert(IndicatorCatalogsController.getIndicatorCatalogsData(recordTypeIdCatalogueIds).length() > 0, 'Invalid return settings');
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        try {
            insert testDataSettings;
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        try {
            System.assert(IndicatorCatalogsController.getIndicatorCatalogsData(recordTypeIdCatalogueIds).length() > 0, 'Invalid return settings');
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        try {
            System.assert(IndicatorCatalogsController.getIndicatorCatalogsData(new List<Id>()).length() != 0, 'Invalid return settings');
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        Test.stopTest();
    }
}