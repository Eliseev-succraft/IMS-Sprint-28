@isTest
public without sharing class TestConfigureColumnsController {
    @isTest static void test_ConfigureColumnsController() {
        Test.startTest();
        Map<String, RecordTypeInfo> recordTypesMap = Schema.SObjectType.sfims__Indicator_Catalogue__c.getRecordTypeInfosByName();
        Id recordTypeIdCatalogue;
        for (String key : recordTypesMap.keySet()) {
            if (recordTypesMap.get(key).getName() != 'Master') {
                recordTypeIdCatalogue = recordTypesMap.get(key).getRecordTypeId();
                break;
            }
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
                            sfims__recordTypeId__c = '0',
                            sfims__fieldName__c = defaultFields[i],
                            sfims__Active__c = true
                    )
            );
        }
        for (Integer i = 0; i < 6; i++) {
            testDataSettings.add(
                    new Indicator_Catalogue_Setting__c(
                            Name = 'TestName2' + i,
                            sfims__recordTypeId__c = recordTypeIdCatalogue,
                            sfims__fieldName__c = defaultFields[i],
                            sfims__Active__c = true
                    )
            );
        }
        try {
            insert testDataSettings;
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        try {
            System.assert(configureColumnsController.getSettingsData().length() > 0, 'Invalid return settings');
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        String JSON_prm = '{"123": {  "selectedFields": [ "sfims__Indicator_Name__c", "sfims__Indicator_Type__c", "RecordTypeId", "sfims__Definition__c", "sfims__Outcome_Area__c", "sfims__Sector__c"],' +
                '"requiredFields": ["sfims__Indicator_Name__c", "sfims__Indicator_Type__c", "RecordTypeId", "sfims__Definition__c", "sfims__Outcome_Area__c" ],' +
                '"active": false}}';
        try {
            System.assertEquals(true, configureColumnsController.saveAllConfigures(JSON_prm), 'Invalid save settings');
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        Test.stopTest();
    }
}