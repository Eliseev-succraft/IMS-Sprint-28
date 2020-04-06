/**
* @author              Alexey Eliseev
* @date                10/31/19
* @component           LoanCustomSettings
**/

public with sharing class LoanCustomSettingsController {

    @AuraEnabled
    public static Map<String, String> apexGetObjectFields(String objectName) {
        Map<String, String> response = new Map<String, String>();
        try {
            response = new Map<String, String>{
                    'getObjectFields' => JSON.serialize(getObjectFields(objectName)),
                    'getCustomSettings' => JSON.serialize(getCustomSettings()),
                    // 'getProfileInfo' => JSON.serialize(OverriddenLoanProductPageController.getProfileInfo()),
                    'hasPermission' => String.valueOf(FeatureManagement.checkPermission('Change_IMS_Settings'))
            };
        } catch (Exception err) {
            throw new AuraHandledException(err.getMessage());
        }
        return response;
    }

    public static Loan_Settings__c getCustomSettings() {
        Loan_Settings__c response = new Loan_Settings__c();
        try {
            response = Loan_Settings__c.getOrgDefaults();
        } catch (Exception err) {
            throw new AuraHandledException(err.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static Boolean apexSaveCustomSettings(Map<String, String> settingValues) {
        Boolean response = false;
        Map<String, FieldClass> loanSettingsFields = getObjectFields('sfims__Loan_Settings__c');
        try {
            sfims__Loan_Settings__c currSettings = sfims__Loan_Settings__c.getOrgDefaults();
            for (String key : settingValues.keySet()) {
                if (loanSettingsFields.containsKey(key)) {
                    if (loanSettingsFields.containsKey(key)) {
                        switch on loanSettingsFields.get(key).type {
                            when 'Boolean' {
                                Boolean value = String.isNotEmpty(settingValues.get(key)) ? Boolean.valueOf(settingValues.get(key)) : false;
                                currSettings.put(key, value);
                            }
                            when 'Number' {
                                Double value = String.isNotEmpty(settingValues.get(key)) ? Double.valueOf(settingValues.get(key)) : 0;
                                currSettings.put(key, value);
                            }
                            when else {
                                currSettings.put(key, settingValues.get(key));
                            }
                        }
                    }
                } else {
                    String msg = System.Label.sfims.part_of_error_message_1 + ' ' + key + ' ' + System.Label.sfims.part_of_error_message_2 + '.';
                    System.debug(msg);
                    AuraHandledException e = new AuraHandledException(msg);
                    e.setMessage(msg);
                    throw e;
                }
            }
            upsert currSettings;
            response = true;
        } catch (Exception err) {
            throw new AuraHandledException(err.getMessage());
        }
        return response;
    }

    public class FieldClass {
        String label;
        String value;
        String type;
        List<Map<String, String>> options;
    }

    public static Map<String, FieldClass> getObjectFields(String objectName) {
        Map<String, FieldClass> response = new Map<String, FieldClass>();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        Schema.SObjectType sObjectType = globalDescribe.get(objectName);
        if (sObjectType != null) {
            Map<String, Schema.SObjectField> schemaMapField = sObjectType.getDescribe().fields.getMap();
            for (String fieldName : schemaMapField.keySet()) {
                FieldClass field = new FieldClass();
                List<Map<String, String>> values = new List<Map<String, String>>();
                switch on schemaMapField.get(fieldName).getDescribe().getType() {
                    when INTEGER {
                        field.type = 'Integer';
                    }
                    when BOOLEAN {
                        field.type = 'Boolean';
                        values.add(new Map<String, String>{
                                'label' => 'True',
                                'value' => 'true'
                        });
                        values.add(new Map<String, String>{
                                'label' => 'False',
                                'value' => 'false'
                        });
                    }
                    when REFERENCE {
                        field.type = 'Lookup';
                        for (SObjectType key : schemaMapField.get(fieldName).getDescribe().referenceTo) {
                            values.add(new Map<String, String>{
                                    'object' => key.getDescribe().getName()
                            });
                        }
                    }
                    when PICKLIST {
                        field.type = 'Picklist';
                        values = getPicklistValues(schemaMapField.get(fieldName).getDescribe());
                    }
                    when DATE {
                        field.type = 'Date';
                    }
                    when DATETIME {
                        field.type = 'Datetime';
                    }
                    when DOUBLE, CURRENCY, PERCENT {
                        field.type = 'Number';
                    }
                    when else {
                        field.type = 'String';
                    }
                }
                field.label = schemaMapField.get(fieldName).getDescribe().getLabel() + ' (' + schemaMapField.get(fieldName).getDescribe().getName() + ')';
                field.value = schemaMapField.get(fieldName).getDescribe().getName();
                field.options = values;
                response.put(schemaMapField.get(fieldName).getDescribe().getName(), field);
            }
        }
        return response;
    }

    public static List<Map<String, String>> getPicklistValues(Schema.DescribeFieldResult fieldResult) {
        List<Map<String, String>> response = new List<Map<String, String>>();
        List<Schema.PicklistEntry> picklistEntry = fieldResult.getPicklistValues();
        if (picklistEntry.size() > 0) {
            for (Schema.PicklistEntry item : picklistEntry) {
                Map<String, String> element = new Map<String, String>();
                element.put('label', item.getLabel());
                element.put('value', item.getValue());
                response.add(element);
            }
        }
        return response;
    }
}