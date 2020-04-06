/** Application Assessment functionality * @author Alexey Eliseev * @date 8/29/19 * @component RunTaskFlow **/

trigger TaskTrigger on Task (before update, before delete, after update) {
    // if access set Read-Only - block update and delete
    if (Trigger.isBefore) {
        // get all fields for Task object
        List<String> taskFields = TriggerHelper.getObjectFieldList('Task');
        // get Id custom record type
        Id customRecordTypeId;
        Map<String, RecordTypeInfo> recordTypes = Schema.SObjectType.Task.getRecordTypeInfosByName();
        if (recordTypes.containsKey('Custom')) {
            customRecordTypeId = recordTypes.get('Custom').getRecordTypeId();
        } else {
            throw new TriggerHelper.CustomException(System.Label.sfims.error_message_36);
        }
        if (Trigger.isDelete) {
            List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
            if (profiles.size() > 0) {
                for (Task taskItem : Trigger.old) {
                    if (taskItem.RecordTypeId == customRecordTypeId) {
                        if (UserInfo.getProfileId() != profiles.get(0).Id) {
                            taskItem.addError(System.Label.sfims.error_message_55);
                        }
                    }
                }
            }
        }
        if (Trigger.isUpdate) {
            // get all list Task_List_Template_Item__c for will get flow names
            Set<Id> taskListTemplateItemIds = new Set<Id>();
            for (Task taskItem : [SELECT Task_List_Template_Item__c FROM Task WHERE Id IN:Trigger.oldMap.keySet()]) {
                if (taskItem.Task_List_Template_Item__c != null) {
                    taskListTemplateItemIds.add(taskItem.Task_List_Template_Item__c);
                }
            }
            // get all flow names, make map
            Map<Id, String> flows = new Map<Id, String>();
            if (taskListTemplateItemIds.size() > 0) {
                for (Task_List_Template_Item__c taskItem : [SELECT Flow_Name__c, Depends_On__c FROM Task_List_Template_Item__c WHERE Id IN:taskListTemplateItemIds]) {
                    if (String.isNotEmpty(taskItem.Flow_Name__c)) {
                        flows.put(taskItem.Id, taskItem.Flow_Name__c);
                    }
                }
            }
            Set<Id> dependsOnIds = new Set<Id>();
            for (Task taskItem : Trigger.new) {
                if (taskItem.Depends_On__c != null) {
                    dependsOnIds.add(taskItem.Depends_On__c);
                }
            }
            Map<Id, Task> dependsOnMap = new Map<Id, Task>();
            if (dependsOnIds.size() > 0) {
                for (Task t : [SELECT Subject FROM Task WHERE Id IN:dependsOnIds]) {
                    dependsOnMap.put(t.Id, t);
                }
            }
            List<Id> taskApproverIds = new List<Id>();

            List<String> disabledEditFields = new List<String>{
                    'ActivityDate', 'Subject', 'OwnerId', 'Priority', 'WhatId', 'RecordTypeId', 'Description',
                    'sfims__Depends_On__c', 'sfims__Task_List_Template_Item__c'
            };
            List<String> editedFields = new List<String>();
            // for each Task
            for (Task taskItem : Trigger.new) {
                // only Custom record Type
                if (taskItem.RecordTypeId == customRecordTypeId) {
                    // check edited fields
                    for (String taskField : taskFields) {
                        if (Trigger.oldMap.containsKey(taskItem.Id) && Trigger.newMap.containsKey(taskItem.Id)) {
                            if (Trigger.oldMap.get(taskItem.Id).get(taskField) != Trigger.newMap.get(taskItem.Id).get(taskField)) {
                                editedFields.add(taskField);
                                if (disabledEditFields.contains(taskField)) {
                                    taskItem.addError(System.Label.sfims.error_message_56);
                                }
                            }
                        }
                    }
                    if ((Trigger.oldMap.get(taskItem.Id).Status != Trigger.newMap.get(taskItem.Id).Status)) {
                        // status control
                        switch on Trigger.oldMap.get(taskItem.Id).Status {
                            when 'Open' {
                                switch on taskItem.Status {
                                    when 'Done' {
                                        if (flows.containsKey(taskItem.Task_List_Template_Item__c)) {
                                            if (taskItem.Read_Only__c) {
                                                taskItem.addError(System.Label.sfims.error_message_57);
                                            }
                                        }
                                    }
                                    when 'Pending Approval' {
                                        if (taskItem.Read_Only__c) {
                                            taskItem.addError(System.Label.sfims.error_message_55);
                                        } else {
                                            taskApproverIds.add(taskItem.Id);
                                        }
                                    }
                                    when else {
                                        taskItem.addError(System.Label.sfims.error_message_55);
                                    }
                                }
                            }
                            when 'Pending' {
                                switch on taskItem.Status {
                                    when 'Open' {
                                        if (taskItem.Read_Only__c) {
                                            taskItem.addError(System.Label.sfims.error_message_55);
                                        }
                                    }
                                    when 'Done' {
                                        taskItem.addError(System.Label.sfims.part_of_error_message_30 + ' \'' + dependsOnMap.get(taskItem.Depends_On__c).Subject + '\' ' + System.Label.sfims.part_of_error_message_31 + '.');
                                    }
                                    when else {
                                        taskItem.addError(System.Label.sfims.error_message_55);
                                    }
                                }
                            }
                            when 'Pending Approval' {
                                switch on taskItem.Status {
                                    when 'Done' {
                                        if (taskItem.Read_Only__c) {
                                            taskItem.addError(System.Label.sfims.error_message_58);
                                        }
                                    }
                                    when 'Rejected' {
                                        if (taskItem.Read_Only__c) {
                                            taskItem.addError(System.Label.sfims.error_message_58);
                                        }
                                    }
                                    when 'Open' {
                                        if (taskItem.Read_Only__c) {
                                            taskItem.addError(System.Label.sfims.error_message_58);
                                        }
                                    }
                                    when else {
                                        taskItem.addError(System.Label.sfims.error_message_55);
                                    }
                                }
                            }
                            when 'Rejected' {
                                switch on taskItem.Status {
                                    when 'Done' {
                                        if (flows.containsKey(taskItem.Task_List_Template_Item__c)) {
                                            if (taskItem.Read_Only__c) {
                                                taskItem.addError(System.Label.sfims.error_message_57);
                                            }
                                        }
                                    }
                                    when 'Pending Approval' {
                                        if (taskItem.Read_Only__c) {
                                            taskItem.addError(System.Label.sfims.error_message_55);
                                        } else {
                                            taskApproverIds.add(taskItem.Id);
                                        }

                                    }
                                    when else {
                                        taskItem.addError(System.Label.sfims.error_message_55);
                                    }
                                }
                            }
                            when else {
                                taskItem.addError(System.Label.sfims.error_message_55);
                            }
                        }
                    }
                }
                taskItem.Read_Only__c = true;
            }
            // create approvals
            if (taskApproverIds.size() > 0) {
                List<Id> taskApprovalsReqIds = new List<Id>();
                List<Id> taskApprovalsNotReqIds = new List<Id>();
                for (Task task : [SELECT Task_List_Template_Item__r.Approval_Required__c FROM Task WHERE Id IN :taskApproverIds AND Task_List_Template_Item__r.Approval_Required__c = TRUE]) {
                    taskApprovalsReqIds.add(task.Id);
                }
                List<Task_Approval__c> taskApprovals = new List<Task_Approval__c>();
                for (Id task : taskApproverIds) {
                    if (taskApprovalsReqIds.contains(task)) {
                        taskApprovals.add(new Task_Approval__c(
                                Task_Id__c = task,
                                Status__c = 'Pending'
                        ));
                    } else {
                        taskApprovalsNotReqIds.add(task);
                    }
                }
                if (taskApprovalsNotReqIds.size() > 0) {
                    for (Id task : taskApprovalsNotReqIds) {
                        Trigger.newMap.get(task).Status = 'Done';
                    }
                }
                if (taskApprovals.size() > 0) {
                    try {
                        insert taskApprovals;
                        List<Task_Approval__c> taskNotFoundProcess = new List<Task_Approval__c>();
                        for (Task_Approval__c taskApproval : taskApprovals) {
                            Approval.ProcessSubmitRequest request = new Approval.ProcessSubmitRequest();
                            request.setObjectId(taskApproval.Id);
                            request.setSubmitterId(UserInfo.getUserId());
                            // request.setSkipEntryCriteria(true);
                            // request.setComments('Submitting request for approval.');
                            try {
                                Approval.ProcessResult result = Approval.process(request);
                                if (result.isSuccess()) {
                                }

                            } catch (System.DmlException err) {
                                if (err.getMessage().contains(System.Label.sfims.error_message_59)) {
                                    taskApproval.Status__c = 'Approved';
                                    taskNotFoundProcess.add(taskApproval);
                                } else {
                                    Trigger.newMap.get(taskApproval.Task_Id__c).addError(err.getMessage());
                                }
                            }
                        }
                        if (taskNotFoundProcess.size() > 0) {
                            for (Task_Approval__c t : taskNotFoundProcess) {
                                Trigger.newMap.get(t.Task_Id__c).Status = 'Done';
                            }
                            // update taskNotContainsProcess;
                        }
                    } catch (System.DmlException err) {
                        throw new TriggerHelper.CustomException(err.getDmlMessage(0));
                    }
                }
            }
        }
    }
    // if click to the completed button
    if (Trigger.isAfter) {
        if (Trigger.isUpdate) {
            // get Id custom record type
            Id customRecordTypeId;
            Map<String, RecordTypeInfo> recordTypes = Schema.SObjectType.Task.getRecordTypeInfosByName();
            if (recordTypes.containsKey('Custom')) {
                customRecordTypeId = recordTypes.get('Custom').getRecordTypeId();
            } else {
                throw new TriggerHelper.CustomException(System.Label.sfims.error_message_36);
            }
            // get completed list ids
            Set<Id> taskIDs = new Set<Id>();
            for (Task taskItem : Trigger.new) {
                if (taskItem.RecordTypeId == customRecordTypeId) {
                    if (taskItem.Status == 'Done' && Trigger.oldMap.get(taskItem.Id).Status != 'Done') {
                        taskIDs.add(taskItem.Id);
                    }
                }
            }
            if (taskIDs.size() > 0) {
                // get dependency tasks and update status
                List<Task> tasks = [SELECT Status, Read_Only__c FROM Task WHERE Depends_On__c IN :taskIDs];
                if (tasks.size() > 0) {
                    for (Task taskItem : tasks) {
                        taskItem.Status = 'Open';
                        taskItem.Read_Only__c = false;
                    }
                    update tasks;
                }
            }
        }
    }
}