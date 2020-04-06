/* Report Template functionality * @author Alexey Eliseev * @date 2/11/19 * component indicatorCatalogsFilters */

public without sharing class moreFiltersController {

    public class CommonException extends Exception {
    }

    public class pickListsClass {
        String accordionSection;
        String fieldName;
        String fieldValue;
        List<Map<String, String>> checkboxGroup;
    }

    @AuraEnabled
    public static String getSelectedIndicatorsFiltersPicklistData() {
        String response = '';
        try {
            Map<String, List<Map<String, String>>> structure = new Map<String, List<Map<String, String>>>();
            structure.put('sfims__Indicator_Type__c', getPicklistDescribe(Indicator_Catalogue__c.sfims__Indicator_Type__c.getDescribe()));
            structure.put('RecordTypeId', getRecordTypes());
            structure.put('sfims__Standard_Custom__c', getPicklistDescribe(Indicator_Catalogue__c.sfims__Standard_Custom__c.getDescribe()));
            structure.put('sfims__Outcome_Area__c', getPicklistDescribe(Indicator_Catalogue__c.sfims__Outcome_Area__c.getDescribe()));
            if (structure.size() > 0) {
                response = JSON.serialize(structure);
            }
        } catch (Exception err) {
            throw new CommonException(err.getMessage());
        }
        return response;
    }

    public static List<Map<String, String>> getPicklistDescribe(Schema.DescribeFieldResult fieldResult) {
        List<Map<String, String>> pickListValuesList = new List<Map<String, String>>();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry pickListVal : ple) {
            Map<String, String> newData = new Map<String, String>();
            newData.put('label', pickListVal.getLabel());
            newData.put('value', pickListVal.getLabel());
            pickListValuesList.add(newData);
        }
        return pickListValuesList;
    }

    @AuraEnabled
    public static List<Map<String, String>> getRecordTypes() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Map<String, RecordTypeInfo> recordTypesMap = Schema.SObjectType.sfims__Indicator_Catalogue__c.getRecordTypeInfosByName();
        for (String key : recordTypesMap.keySet()) {
            if (recordTypesMap.get(key).getName() != 'Master') {
                options.add(new Map<String, String>{
                        'label' => recordTypesMap.get(key).getName(),
                        'value' => recordTypesMap.get(key).getName()
                });
            }
        }
        return options;
    }

    @AuraEnabled
    public static String getIndicatorCatalogsFiltersPicklistData() {
        String response = '';
        try {
            Map<Id, List<pickListsClass>> pickListsFieldsClassMap = new Map<Id, List<pickListsClass>>();
            Map<String, Schema.SObjectField> model_Indicator_Catalogue = Schema.SObjectType.Indicator_Catalogue__c.fields.getMap();
            List<sfims__Indicator_Catalogue_Setting__c> settings = [
                    SELECT sfims__recordTypeId__c, sfims__fieldName__c
                    FROM sfims__Indicator_Catalogue_Setting__c
                    ORDER BY Id
            ];
            Map<Id, List<sfims__Indicator_Catalogue_Setting__c>> settingsByRecordType = new Map<Id, List<sfims__Indicator_Catalogue_Setting__c>>();
            for (sfims__Indicator_Catalogue_Setting__c item : settings) {
                if (!settingsByRecordType.containsKey(item.sfims__recordTypeId__c)) {
                    settingsByRecordType.put(item.sfims__recordTypeId__c, new List<sfims__Indicator_Catalogue_Setting__c>());
                }
                settingsByRecordType.get(item.sfims__recordTypeId__c).add(item);
            }
            for (Id key : settingsByRecordType.keySet()) {
                Integer size = settingsByRecordType.get(key).size();
                List<pickListsClass> pickListsFieldsClass = new List<pickListsClass>();
                if (size > 5) {
                    for (sfims__Indicator_Catalogue_Setting__c s : settingsByRecordType.get(key)) {
                        Schema.SObjectField field = model_Indicator_Catalogue.get(s.sfims__fieldName__c);
                        Schema.DisplayType FldType = field.getDescribe().getType();
                        if (FldType == Schema.DisplayType.PICKLIST) {
                            pickListsClass pClass = new pickListsClass();
                            pClass.accordionSection = field.getDescribe().getLabel();
                            pClass.fieldName = field.getDescribe().getName();
                            pClass.fieldValue = '';
                            pClass.checkboxGroup = getPicklistDescribe(field.getDescribe());
                            pickListsFieldsClass.add(pClass);
                        }
                    }
                    pickListsFieldsClassMap.put(key, pickListsFieldsClass);
                }
            }
            Map<String, RecordTypeInfo> recordTypesMap = Schema.SObjectType.sfims__Indicator_Catalogue__c.getRecordTypeInfosByName();
            for (String key : recordTypesMap.keySet()) {
                if (recordTypesMap.get(key).getName() != 'Master') {
                    if (!pickListsFieldsClassMap.containsKey(recordTypesMap.get(key).getRecordTypeId())) {
                        List<pickListsClass> pickListsFieldsClass = new List<pickListsClass>();
                        List<String> defaultFields = new List<String>{
                                'sfims__Indicator_Name__c',
                                'sfims__Indicator_Type__c',
                                'sfims__Definition__c',
                                'sfims__Outcome_Area__c'
                        };
                        Integer sizeDefaultFields = defaultFields.size();
                        for (Integer i = 0; i < sizeDefaultFields; i++) {
                            Schema.SObjectField field = model_Indicator_Catalogue.get(defaultFields[i]);
                            Schema.DisplayType FldType = field.getDescribe().getType();
                            if (FldType == Schema.DisplayType.PICKLIST) {
                                pickListsClass newPickListItem = new pickListsClass();
                                newPickListItem.accordionSection = field.getDescribe().getLabel();
                                newPickListItem.fieldName = field.getDescribe().getName();
                                newPickListItem.fieldValue = '';
                                newPickListItem.checkboxGroup = getPicklistDescribe(field.getDescribe());
                                pickListsFieldsClass.add(newPickListItem);
                            }
                        }
                        pickListsFieldsClassMap.put(recordTypesMap.get(key).getRecordTypeId(), pickListsFieldsClass);
                    }
                }
            }
            response = JSON.serialize(pickListsFieldsClassMap);
        } catch (Exception err) {
            throw new CommonException(err.getMessage());
        }
        return response;
    }
}