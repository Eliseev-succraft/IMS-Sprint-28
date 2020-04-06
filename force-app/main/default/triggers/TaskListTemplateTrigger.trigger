trigger TaskListTemplateTrigger on Task_List_Template__c (before insert, before update) {
    // object and field validation
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
            // create a map with object name and list of fields
            Map<String, List<String>> objects = new Map<String, List<String>>();
            for (Task_List_Template__c taskListTemplate : Trigger.new) {
                if (String.isNotBlank(taskListTemplate.Object_Name__c) && String.isNotBlank(taskListTemplate.Object_Status_Field__c)) {
                    if (!objects.containsKey(taskListTemplate.Object_Name__c)) {
                        if (schemaMap.containsKey(taskListTemplate.Object_Name__c)) {
                            Schema.SObjectType cType = schemaMap.get(taskListTemplate.Object_Name__c);
                            if (cType != null) {
                                Map<String, Schema.SObjectField> schemaMapField = cType.getDescribe().fields.getMap();
                                List<String> fields = new List<String>();
                                for (String fieldName : schemaMapField.keySet()) {
                                    fields.add(fieldName);
                                }
                                objects.put(taskListTemplate.Object_Name__c, fields);
                            }
                        } else {
                            taskListTemplate.addError(System.Label.sfims.part_of_error_message_29 + ' "' + taskListTemplate.Object_Name__c + '" ' + System.Label.sfims.part_of_error_message_28 + '.');
                        }
                    }
                } else {
                    taskListTemplate.addError(System.Label.sfims.error_message_54);
                }
            }
            // check field existence
            for (Task_List_Template__c taskListTemplate : Trigger.new) {
                if (objects.containsKey(taskListTemplate.Object_Name__c)) {
                    if (objects.get(taskListTemplate.Object_Name__c).indexOf(taskListTemplate.Object_Status_Field__c.toLowerCase()) == -1) {
                        taskListTemplate.addError(System.Label.sfims.part_of_error_message_1 + ' "' + taskListTemplate.Object_Status_Field__c +
                         '" '+ System.Label.sfims.part_of_error_message_28 + ' ' + System.Label.sfims.part_of_error_message_20 + ' ' +
                         System.Label.sfims.part_of_error_message_25 + ' "' + taskListTemplate.Object_Name__c + '".');
                    }
                }
            }
        }
    }
}