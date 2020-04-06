/* Report Template functionality * @author Alexey Eliseev * @date 2/4/19 *component indicatorCatalogsFilters */

public without sharing class configureColumnsController {

    public class showException extends Exception {
    }

    public class returnSettingsClass {
        List<Map<String, String>> availableFields;
        List<Map<String, String>> allRecordTypes;
        Map<String, settingsClass> savedSettings;
    }

    @AuraEnabled
    public static String getSettingsData() {
        returnSettingsClass returnSettingsData = new returnSettingsClass();
        returnSettingsData.availableFields = getAllFields();
        returnSettingsData.allRecordTypes = getRecordTypes();
        returnSettingsData.savedSettings = getSavedSettings();
        return JSON.serialize(returnSettingsData);
    }

    public class settingsClass {
        public List<String> fields;
        public Boolean active;
    }

    @AuraEnabled
    public static Boolean saveAllConfigures(String objRecordType) {
        Boolean response = false;
        try {
            if (String.isNotBlank(objRecordType)) {
                List<sfims__Indicator_Catalogue_Setting__c> settings = new List<sfims__Indicator_Catalogue_Setting__c>();
                List<String> delSettingItems = new List<String>();
                Map<String, Object> objGlobalType = (Map<String, Object>) JSON.deserializeUntyped(objRecordType);
                for (String key : objGlobalType.keySet()) {
                    delSettingItems.add(key);
                    if (key != '0') {
                        Map<String, Object> objGlobalFields = (Map<String, Object>) objGlobalType.get(key);
                        List<Object> fields = (List<Object>) objGlobalFields.get('selectedFields');
                        Boolean flag = (Boolean) objGlobalFields.get('active');
                        Integer fieldsSize = fields.size();
                        for (Integer i = 0; i < fieldsSize; i++) {
                            settings.add(new sfims__Indicator_Catalogue_Setting__c(
                                    sfims__fieldName__c = (String) fields[i],
                                    sfims__recordTypeId__c = key,
                                    sfims__Active__c = flag,
                                    Name = 'field-' + i + '-' + key
                            ));
                        }
                    }
                }
                if (settings.size() > 0) {
                    if (delSettingItems.size() > 0) {
                        delete [SELECT Id FROM Indicator_Catalogue_Setting__c];
                    }
                    insert settings;
                }
                response = true;
            }
        } catch (Exception err) {
            throw new AuraHandledException(err.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static Map<String, settingsClass> getSavedSettings() {
        Map<String, settingsClass> response = new Map<String, settingsClass>();
        try {
            List<sfims__Indicator_Catalogue_Setting__c> settings = [
                    SELECT sfims__recordTypeId__c, sfims__fieldName__c, sfims__Active__c
                    FROM sfims__Indicator_Catalogue_Setting__c
                    ORDER BY Id
            ];
            Integer settingsSize = settings.size();
            if (settingsSize > 0) {
                for (sfims__Indicator_Catalogue_Setting__c s : settings) {
                    if (!response.containsKey(s.sfims__recordTypeId__c)) {
                        List<String> listFieldsName = new List<String>();
                        for (sfims__Indicator_Catalogue_Setting__c v : settings) {
                            if (v.sfims__recordTypeId__c == s.sfims__recordTypeId__c) {
                                listFieldsName.add(v.sfims__fieldName__c);
                            } else {
                                continue;
                            }
                        }
                        settingsClass putData = new settingsClass();
                        putData.active = s.sfims__Active__c;
                        putData.fields = listFieldsName;
                        response.put(s.sfims__recordTypeId__c, putData);
                    } else {
                        continue;
                    }
                }
            } else {

            }
        } catch (Exception err) {
            throw new AuraHandledException(err.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static List<Map<String, String>> getRecordTypes() {
        List<Map<String, String>> response = new List<Map<String, String>>();
        try {
            Map<String, RecordTypeInfo> recordTypesMap = Schema.SObjectType.sfims__Indicator_Catalogue__c.getRecordTypeInfosByName();
            for (String key : recordTypesMap.keySet()) {
                if (recordTypesMap.get(key).getName() != 'Master') {
                    response.add(new Map<String, String>{
                            'label' => recordTypesMap.get(key).getName(),
                            'value' => recordTypesMap.get(key).getRecordTypeId()
                    });
                }
            }
        } catch (Exception err) {
            throw new AuraHandledException(err.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static List<Map<String, String>> getAllFields() {
        List<Map<String, String>> response = new List<Map<String, String>>();
        try {
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            Schema.SObjectType cType = gd.get('sfims__Indicator_Catalogue__c');
            Map<String, Schema.SObjectField> fMap = cType.getDescribe().fields.getMap();
            List<String> fieldsIgnore = new List<String>{
                    'id',
                    'isdeleted',
                    'recordtypeid',
                    'createddate',
                    'active__c',
                    'ownerid',
                    'createdbyid',
                    'lastmodifiedbyid',
                    'systemmodstamp',
                    'lastmodifieddate',
                    'lastvieweddate',
                    'lastreferenceddate'
            };
            for (String fieldName : fMap.keySet()) {
                String field = fieldName.replace('sfims__', '');
                if (!fieldsIgnore.contains(field)) {
                    response.add(new Map<String, String>{
                            'label' => fMap.get(fieldName).getDescribe().getLabel(),
                            'value' => fMap.get(fieldName).getDescribe().getName()
                    });
                }
            }
            response.add(new Map<String, String>{
                    'label' => 'Library',
                    'value' => 'RecordTypeId'
            });
        } catch (Exception err) {
            throw new AuraHandledException(err.getMessage());
        }
        return response;
    }
}