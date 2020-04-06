trigger TaskListTemplateItemTrigger on Task_List_Template_Item__c (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            // create a map with object name and list of fields
            Set<Id> taskTemplateIds = new Set<Id>();
            for (Task_List_Template_Item__c t : Trigger.new) {
                taskTemplateIds.add(t.Task_List_Template__c);
            }
            // Set<String> objects = new Set<String>();
            Map<Id, Task_List_Template__c> objects;
            Map<String, List<String>> objectFields = new Map<String, List<String>>();
            if (taskTemplateIds.size() > 0) {
                objects = new Map<Id, Task_List_Template__c>([SELECT Object_Name__c FROM Task_List_Template__c WHERE Id IN :taskTemplateIds]);
                if (objects.size() > 0) {
                    Map<String, Schema.SObjectType> schema = Schema.getGlobalDescribe();
                    for (Id i : objects.keySet()) {
                        if (schema.containsKey(objects.get(i).Object_Name__c) && !objectFields.containsKey(objects.get(i).Object_Name__c)) {
                            Schema.SObjectType cType = schema.get(objects.get(i).Object_Name__c);
                            if (cType != null) {
                                Map<String, Schema.SObjectField> schemaField = cType.getDescribe().fields.getMap();
                                List<String> fields = new List<String>();
                                for (String fieldName : schemaField.keySet()) {
                                    fields.add(fieldName);
                                }
                                objectFields.put(objects.get(i).Object_Name__c, fields);
                            }
                        }
                    }
                }
            }
            // validation required fields
            Map<String, String> reqFields = new Map<String, String>{
                    'Subject__c' => 'Subject',
                    'Task_List_Template__c' => 'Task List Template',
                    'Priority__c' => 'Priority',
                    'Task_Type__c' => 'Task Type',
                    'Assignee_Type__c' => 'Assignee Type'
            };
            for (Task_List_Template_Item__c t : Trigger.new) {
                List<String> emptyFields = new List<String>();
                for (String key : reqFields.keySet()) {
                    if (t.get(key) == null) {
                        emptyFields.add(reqFields.get(key));
                    }
                }
                Boolean isFieldErr = false;
                switch on t.Assignee_Type__c {
                    when 'User' {
                        if (String.isBlank(t.Assignee_User__c)) {
                            emptyFields.add('Assignee User');
                        }
                    }
                    when 'Related Field' {
                        if (String.isBlank(t.Assignee_Field__c)) {
                            emptyFields.add('Assignee Field');
                        } else {
                            if (String.isNotBlank(t.Assignee_Field__c)) {
                                if (objects.containsKey(t.Task_List_Template__c)) {
                                    String obj = objects.get(t.Task_List_Template__c).Object_Name__c;
                                    if (objectFields.containsKey(obj)) {
                                        if (!objectFields.get(obj).contains(t.Assignee_Field__c.toLowerCase())) {
                                            isFieldErr = true;
                                        }
                                    } else {
                                        isFieldErr = true;
                                    }
                                } else {
                                    isFieldErr = true;
                                }
                            }
                        }
                    }
                    when else {
                    }
                }
                Boolean isApprovalErr = false;
                if (t.Approval_Required__c && String.isBlank(t.Flow_Name__c)) {
                    isApprovalErr = true;
                    emptyFields.add('Flow Name');
                }
                String errMsg = '';
                if (emptyFields.size() > 0) {
                    errMsg += System.Label.sfims.part_of_error_message_26 + ': ' + String.join(emptyFields, ', ') + '. ';
                }
                if (isApprovalErr) {
                    errMsg += System.Label.sfims.part_of_error_message_27 + ' ';
                }
                if (isFieldErr) {
                    errMsg += System.Label.sfims.part_of_error_message_1 + ' "' + t.Assignee_Field__c + '" ' + 
                        System.Label.sfims.part_of_error_message_28 + ' ' + System.Label.sfims.part_of_error_message_20 + ' ' + 
                        (objects.containsKey(t.Task_List_Template__c) ? '"' + objects.get(t.Task_List_Template__c).Object_Name__c + '" ' : '') + 
                        System.Label.sfims.part_of_error_message_25 + '.';
                }
                if (String.isNotEmpty(errMsg)) {
                    t.addError(errMsg);
                }
            }
        }
    }
}