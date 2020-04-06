/* Report Template functionality * @author Alexey Eliseev * @date 2/11/19 *component IndicatorCatalogs */

public without sharing class IndicatorCatalogsController {
    public class CommonException extends Exception {
    }
    
    public class getIndicatorCatalogsDataClass {
        public List<Indicator_Catalogue__c> allIndicators;
        List<String> allFields;
        List<Map<String, String>> availableFields;
        public List<Map<String, String>> allRecordTypes;
    }

    @AuraEnabled
    public static String getIndicatorCatalogsData(List<String> selectedRecordTypes) {
        String response = '';
        try {
            getIndicatorCatalogsDataClass indicatorCatalogsData = new getIndicatorCatalogsDataClass();
            Map<String, configureColumnsController.settingsClass> savedSettings = configureColumnsController.getSavedSettings();
            indicatorCatalogsData.availableFields = configureColumnsController.getAllFields();
            List<String> defaultFields = new List<String>{
                    'sfims__Indicator_Name__c',
                    'sfims__Indicator_Type__c',
                    'RecordTypeId',
                    'RecordType.Name',
                    'sfims__Definition__c',
                    'sfims__Outcome_Area__c'
            };
            // fields
            List<String> fields = new List<String>();
            // expressions
            List<String> qWhere = new List<String>();
            // results
            List<Indicator_Catalogue__c> results = new List<Indicator_Catalogue__c>();
            if (selectedRecordTypes.size() > 0) {
                List<String> recordTypeIds = new List<String>();
                for (String key : selectedRecordTypes) {
                    if (key != '0') {
                        recordTypeIds.add(key);
                        if (savedSettings.containsKey(key)) {
                            fields.addAll(savedSettings.get(key).fields);
                        }
                    }
                }
                if (fields.size() > 0) {
                    List<String> newListFields = new List<String>();
                    for (String key : fields) {
                        if (!newListFields.contains(key)) {
                            newListFields.add(key);
                        }
                    }
                    fields = newListFields;
                } else {
                    fields = defaultFields;
                }
                if (recordTypeIds.size() > 0) {
                    qWhere.add('AND RecordTypeId IN :recordTypeIds');
                }
                if (!fields.contains('RecordTypeId')) {
                    fields.add('RecordTypeId');
                }
                if (!fields.contains('RecordType.Name')) {
                    fields.add('RecordType.Name');
                }
                String addFields = '';
                if (!fields.contains('sfims__Standard_Custom__c')) {
                    addFields = ', sfims__Standard_Custom__c';
                }
                results = (List<Indicator_Catalogue__c>) Database.query('SELECT ' + String.join(fields, ', ') + addFields + ' FROM Indicator_Catalogue__c WHERE Active__c = true ' + String.join(qWhere, ' AND ') + ' ORDER BY RecordTypeId, Name');
            } else { // do not show records
                fields = defaultFields;
            }
            indicatorCatalogsData.allFields = fields;
            indicatorCatalogsData.allIndicators = results;
            indicatorCatalogsData.allRecordTypes = ReportTemplateController.getAllRecordTypes();
            response = JSON.serialize(indicatorCatalogsData);
        } catch (Exception err) {
            throw new CommonException(err.getMessage());
        }
        return response;
    }
}