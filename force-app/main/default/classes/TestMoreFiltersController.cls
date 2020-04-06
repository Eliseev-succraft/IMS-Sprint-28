@isTest
private without sharing class TestMoreFiltersController {
    @isTest static void test_MoreFiltersController() {
        Test.startTest();
        Map<String, RecordTypeInfo> recordTypesMap = Schema.SObjectType.sfims__Indicator_Catalogue__c.getRecordTypeInfosByName();
        Id recordTypeIdCatalogue;
        for (String key : recordTypesMap.keySet()) {
            if (recordTypesMap.get(key).getName() != 'Master') {
                recordTypeIdCatalogue = recordTypesMap.get(key).getRecordTypeId();
                break;
            }
        }
        try {
            String returnDataSelectedIndicatorsFilters = moreFiltersController.getSelectedIndicatorsFiltersPicklistData();
            Map<String, Object> parseSelectedIndicators = (Map<String, Object>) JSON.deserializeUntyped(returnDataSelectedIndicatorsFilters);
            System.assert(((List<Object>) parseSelectedIndicators.get('sfims__Indicator_Type__c')).size() > 0, 'Invalid return sfims__Indicator_Type__c options');
            System.assert(((List<Object>) parseSelectedIndicators.get('RecordTypeId')).size() > 0, 'Invalid return RecordTypeId options');
            System.assert(((List<Object>) parseSelectedIndicators.get('sfims__Standard_Custom__c')).size() > 0, 'Invalid return sfims__Standard_Custom__c options');
            System.assert(((List<Object>) parseSelectedIndicators.get('sfims__Outcome_Area__c')).size() > 0, 'Invalid return sfims__Outcome_Area__c options');
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        List<String> defaultFields = new List<String>{
                'sfims__Indicator_Name__c',
                'sfims__Indicator_Type__c',
                'sfims__Standard_Custom__c',
                'sfims__Definition__c',
                'sfims__Outcome_Area__c',
                'Name'
        };
        List<Indicator_Catalogue_Setting__c> testDataSettings = new List<Indicator_Catalogue_Setting__c>();
        for (Integer i = 0; i < 6; i++) {
            testDataSettings.add(
                    new Indicator_Catalogue_Setting__c(
                            Name = 'TestName' + i,
                            sfims__recordTypeId__c = (string) recordTypeIdCatalogue,
                            sfims__fieldName__c = defaultFields[i]
                    )
            );
        }
        insert testDataSettings;
        try {
            moreFiltersController.getIndicatorCatalogsFiltersPicklistData();
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        Test.stopTest();
    }
}