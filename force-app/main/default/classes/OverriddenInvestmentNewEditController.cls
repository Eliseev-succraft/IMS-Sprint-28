public class OverriddenInvestmentNewEditController {

    @AuraEnabled
    public static Map<Id, String> apexGetRecordTypeInfo(String objectName) {
        Map<Id, String> response = new Map<Id, String>();
        try {
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            Schema.SObjectType sObjectType = globalDescribe.get(objectName);
            if (sObjectType != null) {
                for (String key : sObjectType.getDescribe().getRecordTypeInfosByName().keySet()) {
                    Schema.RecordTypeInfo rti = sObjectType.getDescribe().getRecordTypeInfosByName().get(key);
                    if (rti.isActive() && rti.isAvailable() && !rti.isMaster()) {
                        response.put(rti.getRecordTypeId(), key);
                    }
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return response;
    }
}