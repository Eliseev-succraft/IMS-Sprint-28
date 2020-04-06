/* Report Template functionality * @author Alexey Eliseev * @date 2/11/19 * component ReportTemplate */

public without sharing class ReportTemplateController {

    public class CommonException extends Exception {
    }

    @AuraEnabled
    public static String getLibraries() {
        String response = '';
        try {
            response = configureColumnsController.getSettingsData();
        } catch (Exception err) {
            throw new CommonException(err.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static List<Map<String, String>> getAllRecordTypes() {
        List<Map<String, String>> response = new List<Map<String, String>>();
        try {
            Map<String, RecordTypeInfo> recordTypesMap = Schema.SObjectType.sfims__Indicator_Catalogue__c.getRecordTypeInfosByName();
            for (String key : recordTypesMap.keySet()) {
                if (recordTypesMap.get(key).getName() != 'Master') {
                    response.add(new Map<String, String>{
                            'label' => recordTypesMap.get(key).getName(), 'value' => recordTypesMap.get(key).getRecordTypeId()
                    });
                }
            }
        } catch (Exception err) {
            throw new CommonException(err.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static Report_Template__c saveReportTemplateIndicators(List<Id> newListIDs, Id templateId) {
        Report_Template__c response = new Report_Template__c();
        try {
            // delete [SELECT Id FROM Report_Template_Indicator__c WHERE Report_Template__c = :templateId];
            system.debug(newListIDs);
            List<Id> oldListIDs = new List<Id>();
            Map<String, Id> oldListRTIiDs = new Map<String, Id>();
            for (Report_Template_Indicator__c tmp : [
                    SELECT Indicator_Catalogue__c
                    FROM Report_Template_Indicator__c
                    WHERE Report_Template__c = :templateId
            ]) {
                oldListIDs.add(tmp.Indicator_Catalogue__c);
                oldListRTIiDs.put((String) tmp.Indicator_Catalogue__c + (String) templateId, tmp.Id);
            }
       
            Integer oldListIDsSize = oldListIDs.size();
            Integer newListIDsSize = newListIDs.size();
            List<Id> delOldListIDs = new List<Id>();
            if (oldListIDsSize > 0) {
                for (Integer i = 0; i < oldListIDsSize; i++) {
                    system.debug(newListIDs + ' ' + oldListIDs[i] + ' '+ newListIDs.contains(oldListIDs[i]));
                    if (!newListIDs.contains(oldListIDs[i])) {
                        delOldListIDs.add(oldListIDs[i]);
                    }
                }
            }
            system.debug(newListIDs);
            system.debug(oldListIDs);
            system.debug(delOldListIDs);
            if (delOldListIDs.size() > 0) {
                delete [
                        SELECT Id
                        FROM Report_Template_Indicator__c
                        WHERE Indicator_Catalogue__c IN :delOldListIDs AND Report_Template__c = :templateId
                ];
            }
            // find added indicators in template
            List<Report_Template_Indicator__c> junctionObject = new List<Report_Template_Indicator__c>();
            for (Integer i = 0; i < newListIDsSize; i++) {
                //  if (!oldListIDs.contains(newListIDs[i])) {
                if (oldListRTIiDs.containsKey((String) newListIDs[i] + (String) templateId)) {
                    junctionObject.add(new Report_Template_Indicator__c(
                            Id = oldListRTIiDs.get((String) newListIDs[i] + (String) templateId),
                            Indicator_Catalogue__c = newListIDs[i],
                            Report_Template__c = templateId,
                            Sequence_Number__c = i
                    ));
                } else {
                    junctionObject.add(new Report_Template_Indicator__c(
                            Indicator_Catalogue__c = newListIDs[i],
                            Report_Template__c = templateId,
                            Sequence_Number__c = i
                    ));
                }
                //  }
            }
            if (junctionObject.size() > 0) {
                // insert junctionObject;
                upsert junctionObject;
            }
            response = [SELECT Id, Name FROM Report_Template__c WHERE Id = :templateId];
        } catch (Exception err) {
            throw new CommonException(err.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static List<String> getLayoutFields(String pageLayoutName, List<String> requiredFields) {
        List<String> response = new List<String>();
        try {
            if (String.isNotBlank(pageLayoutName)) {
                List<Metadata.Metadata> layoutMetadata = Metadata.Operations.retrieve(Metadata.MetadataType.Layout, new List<String>{
                        'sfims__Indicator_Catalogue__c-sfims__' + pageLayoutName
                });
                if (layoutMetadata.size() > 0) {
                    Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
                    Schema.SObjectType cType = gd.get('sfims__Indicator_Catalogue__c');
                    Map<String, Schema.SObjectField> fMap = cType.getDescribe().fields.getMap();
                    Map<String, String> fieldsInfo = new Map<String, String>();
                    for (String fieldName : fMap.keySet()) {
                        fieldsInfo.put(fieldName.replace('sfims__', ''), fMap.get(fieldName).getDescribe().getLabel());
                    }
                    Metadata.Layout customLayout = (Metadata.Layout) layoutMetadata.get(0);
                    List<String> fieldsIgnore = new List<String>{
                            'OwnerId',
                            'CreatedById',
                            'LastModifiedById'
                    };
                    for (Metadata.LayoutSection m : customLayout.layoutSections) {
                        if (m.layoutColumns != null) {
                            for (Metadata.LayoutColumn c : m.layoutColumns) {
                                if (c.layoutItems != null) {
                                    for (Metadata.LayoutItem i : c.layoutItems) {
                                        if (i != null) {
                                            if (String.isNotBlank(i.field) && (!fieldsIgnore.contains(i.field)) && (!requiredFields.contains(i.field))) {
                                                response.add('sfims__' + i.field);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    throw new CommonException(System.Label.sfims.part_of_error_message_22 + ': ' + pageLayoutName + ' ' + System.Label.sfims.part_of_js_error_message_2 + '.');
                }
            }
        } catch (Exception err) {
            throw new CommonException(err.getMessage());
        }
        return response;
    }
}