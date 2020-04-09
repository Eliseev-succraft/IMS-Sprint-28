public without sharing class CustomLookupController {

    public class CommonException extends Exception {
    }

    @AuraEnabled(Cacheable = true)
    public static List<SObject> fetchRecords(String objectName, String fields, String filterField, String searchString, String additionalWhere, String recordCount) {
        try {
            return Database.query('SELECT Id, ' + fields +
                    ' FROM ' + objectName +
                    ' WHERE ' + filterField + ' LIKE ' + '\'%' + String.escapeSingleQuotes(searchString.trim()) + '%\'' + additionalWhere +
                    ' ORDER BY Id DESC LIMIT ' + recordCount);
        } catch (Exception err) {
            throw new CommonException(err.getMessage());
        }
    }
}