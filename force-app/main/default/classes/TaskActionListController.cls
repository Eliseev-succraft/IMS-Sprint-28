public without sharing class TaskActionListController {

    public class CustomException extends Exception {
    }

    public class responseClass {
        List<SObject> results;
        Map<Id, SObject> resultsMap;
        Map<String, String> labels;
        List<String> columns;
    }

    public class responseTaskActionList {
        responseClass taskObject;
        responseClass someObject;
        Map<String, String> recordTypes;
    }

    @AuraEnabled
    public static Boolean changeTaskStatus(Id taskId, String status) {
        Boolean response = false;
        try {
            response = RunTaskFlowController.apexChangeStatusTask(taskId, status);
        } catch (Exception err) {
            throw new CustomException(err.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static Boolean deleteTask(Id taskId) {
        Boolean response = false;
        try {
            delete [SELECT Id FROM Task WHERE Id = :taskId];
            response = true;
        } catch (Exception err) {
            throw new CustomException(err.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static String getTasks(Id recordId, String statusFilter, String customTaskFields, String customObjectFields, String showTasks, Boolean isOnlyMyTasks, String searchValue, Boolean isTaskField, String sortingField, Boolean isDescSorting, Boolean isDebugLog) {
        String response;
        try {
            responseTaskActionList responseTaskActionList = new responseTaskActionList();
            responseTaskActionList.taskObject = new responseClass();
            responseTaskActionList.someObject = new responseClass();
            responseTaskActionList.recordTypes = new Map<String, String>();
            // set record types
            Map<String, RecordTypeInfo> recordTypes = Schema.SObjectType.Task.getRecordTypeInfosByName();
            if (!recordTypes.isEmpty()) {
                for (String key : recordTypes.keySet()) {
                    responseTaskActionList.recordTypes.put(key, recordTypes.get(key).getRecordTypeId());
                }
            }
            // END set record types
            String currentUser = UserInfo.getUserId();
            if (isDebugLog) {
                System.debug('recordId - ' + recordId);
                System.debug('statusFilter - ' + statusFilter);
                System.debug('customTaskFields - ' + customTaskFields);
                System.debug('customObjectFields - ' + customObjectFields);
                System.debug('isOnlyMyTasks - ' + isOnlyMyTasks);
                System.debug('searchValue - ' + searchValue);
                System.debug('isTaskField - ' + isTaskField);
                System.debug('sortingField - ' + sortingField);
                System.debug('isDescSorting - ' + isDescSorting);
                System.debug('showTasks - ' + showTasks);
            }
            // identified fields
            List<String> customTaskFieldsList = new List<String>();
            if (String.isNotBlank(customTaskFields)) {
                customTaskFieldsList = customTaskFields.split(',');
            }
            List<String> customObjectFieldsList = new List<String>();
            if (String.isNotBlank(customObjectFields)) {
                customObjectFieldsList = customObjectFields.split(',');
            }
            if (isDebugLog) {
                System.debug('customTaskFieldsList - ' + customTaskFieldsList);
                System.debug('customObjectFieldsList - ' + customObjectFieldsList);
            }
            // END identified fields
            if (customTaskFieldsList.size() > 0) {
                // get all fields and labels from the Task object
                Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
                Schema.SObjectType cType = schemaMap.get('Task');
                Map<String, String> allTaskFields = new Map<String, String>();
                if (cType != null) {
                    Map<String, Schema.SObjectField> schemaMapField = cType.getDescribe().fields.getMap();
                    for (String fieldName : schemaMapField.keySet()) {
                        allTaskFields.put(schemaMapField.get(fieldName).getDescribe().getName(), schemaMapField.get(fieldName).getDescribe().getLabel());
                    }
                }
                // END get all fields and labels from the Task object
                if (!allTaskFields.isEmpty()) {
                    Map<String, String> synTableLabels = new Map<String, String>{
                            'Activity ID' => 'Activity',
                            'Task Record Type ID' => 'Task Record Type',
                            'Name ID' => 'Name',
                            'Related To ID' => 'Related To',
                            'Due Date Only' => 'Due Date',
                            'Assigned To ID' => 'Assigned To',
                            'Account ID' => 'Account'
                    };
                    List<String> errFields = new List<String>();
                    Map<String, String> labels = new Map<String, String>();
                    List<String> columns = new List<String>();
                    for (String field : customTaskFieldsList) {
                        field = field.trim();
                        // if field is API name
                        if (allTaskFields.containsKey(field)) {
                            String curLabel = allTaskFields.get(field);
                            if (synTableLabels.containsKey(curLabel)) {
                                curLabel = synTableLabels.get(curLabel);
                            }
                            labels.put(field, curLabel);
                            columns.add(field);
                        } else {
                            if (field == 'Start') {
                                labels.put('Start', '');
                                columns.add('Start');
                            } else {
                                errFields.add(field);
                            }
                        }
                    }
                    if (isDebugLog) {
                        System.debug('allTaskFields - ' + allTaskFields);
                        System.debug('labels - ' + labels);
                        System.debug('columns - ' + columns);
                        System.debug('errFields - ' + errFields);
                    }
                    if (errFields.size() > 0) {
                        throw new CustomException(System.Label.sfims.part_of_error_message_21 + ': ' + String.join(errFields, ', ') + '.');
                    }
                    if (!labels.isEmpty()) {
                        List<String> selectFields = new List<String>(labels.keySet());
                        Integer indexStartBtn = selectFields.indexOf('Start');
                        if (indexStartBtn != -1) {
                            selectFields.remove(indexStartBtn);
                        }
                        // fields
                        if (selectFields.contains('WhatId')) {
                            selectFields.add('What.Name');
                        }
                        if (selectFields.contains('OwnerId')) {
                            selectFields.add('Owner.Name');
                        }
                        selectFields.addAll(new List<String>{
                                'RecordTypeId',
                                'sfims__Depends_On__c',
                                'sfims__Task_List_Template_Item__c',
                                'sfims__Task_List_Template_Item__r.sfims__Flow_Name__c'
                        });
                        // expressions
                        List<String> qWhere = new List<String>();
                        if (recordId != null) {
                            qWhere.add('WhatId = \'' + recordId + '\'');
                        }
                        if (statusFilter != 'All') {
                            if (statusFilter == 'Done') { // close
                                qWhere.add('(Status = \'Done\' OR Status = \'Completed\')');
                            } else {
                                qWhere.add('Status = \'' + statusFilter + '\'');
                            }
                        }
                        if (showTasks != 'All Users') {
                            qWhere.add('OwnerId = \'' + currentUser + '\'');
                        } else {
                            if (isOnlyMyTasks) {
                                qWhere.add('CreatedById = \'' + currentUser + '\'');
                            }
                        }
                        if (String.isNotBlank(searchValue)) {
                            searchValue = '%' + searchValue + '%';
                            qWhere.add('Subject LIKE \'' + searchValue + '\'');
                        }
                        // sorting
                        String qOrderBy = ' ORDER BY CreatedDate DESC'; // default
                        if (String.isNotBlank(sortingField) && isTaskField) {
                            qOrderBy = ' ORDER BY ' + sortingField + (isDescSorting ? ' DESC' : ' ASC');
                        }
                        if (isDebugLog) {
                            System.debug('selectFields - ' + selectFields);
                            System.debug('qWhere - ' + qWhere);
                            System.debug('qOrderBy - ' + qOrderBy);
                        }
                        List<Task> tasks = new List<Task>();
                        if (!qWhere.isEmpty()) {
                            tasks = Database.query('SELECT ' + String.join(selectFields, ' ,') + ' FROM Task WHERE ' + String.join(qWhere, ' AND ') + qOrderBy);
                        } else {
                            tasks = Database.query('SELECT ' + String.join(selectFields, ' ,') + ' FROM Task ' + qOrderBy);
                        }
                        if (isDebugLog) {
                            System.debug('tasks - ' + tasks);
                        }
                        responseTaskActionList.taskObject.labels = labels;
                        responseTaskActionList.taskObject.columns = columns;
                        responseTaskActionList.taskObject.results = tasks;
                        responseTaskActionList.taskObject.resultsMap = new Map<Id, SObject>(tasks);
                        // get results from related to object
                        if (customObjectFieldsList.size() > 0) {
                            if (tasks.size() > 0) {
                                List<Id> someObjectIds = new List<Id>();
                                for (Task item : tasks) {
                                    if (!someObjectIds.contains(item.WhatId) && item.WhatId != null) {
                                        someObjectIds.add(item.WhatId);
                                    }
                                }
                                Id relatedTo;
                                if (someObjectIds.size() > 0) {
                                    relatedTo = someObjectIds.get(0);
                                }
                                if (relatedTo != null) {
                                    Schema.SObjectType selectedSObjectType = relatedTo.getSobjectType();
                                    String selectedSObjectName = selectedSObjectType.getDescribe().getName();
                                    // get all fields and labels from the related object 
                                    schemaMap = Schema.getGlobalDescribe();
                                    cType = schemaMap.get(selectedSObjectName);
                                    Map<String, String> allObjectFields = new Map<String, String>();
                                    if (cType != null) {
                                        Map<String, Schema.SObjectField> schemaMapField = cType.getDescribe().fields.getMap();
                                        for (String fieldName : schemaMapField.keySet()) {
                                            allObjectFields.put(schemaMapField.get(fieldName).getDescribe().getName(), schemaMapField.get(fieldName).getDescribe().getLabel());
                                        }
                                    }
                                    if (isDebugLog) {
                                        System.debug('relatedTo - ' + relatedTo);
                                        System.debug('selectedSObjectName - ' + selectedSObjectName);
                                        System.debug('allObjectFields - ' + allObjectFields);
                                    }
                                    // END get all fields and labels from the related object 
                                    if (!allObjectFields.isEmpty()) {
                                        errFields = new List<String>();
                                        labels = new Map<String, String>();
                                        columns = new List<String>();
                                        for (String field : customObjectFieldsList) {
                                            field = field.trim();
                                            // if field is API name
                                            if (allObjectFields.containsKey(field)) {
                                                labels.put(field, allObjectFields.get(field));
                                                columns.add(field);
                                            } else {
                                                errFields.add(field);
                                            }
                                        }
                                        if (isDebugLog) {
                                            System.debug('labels - ' + labels);
                                            System.debug('columns - ' + columns);
                                            System.debug('errFields - ' + errFields);
                                        }
                                        if (errFields.size() > 0) {
                                            throw new CustomException(System.Label.sfims.part_of_error_message_24 + ' \'' + selectedSObjectName + '\' ' + System.Label.sfims.part_of_error_message_25 + ': ' + String.join(errFields, ', ') + '.');
                                        }
                                        if (!labels.isEmpty()) {
                                            selectFields = new List<String>(labels.keySet());
                                            // expressions
                                            if (isDebugLog) {
                                                System.debug('selectFields - ' + selectFields);
                                            }
                                            // sorting
                                            String qOrderByObject = ' ORDER BY CreatedDate DESC'; // default
                                            if (String.isNotBlank(sortingField) && !isTaskField) {
                                                qOrderByObject = ' ORDER BY ' + sortingField + (isDescSorting ? ' DESC' : ' ASC');
                                            }
                                            responseTaskActionList.someObject.labels = labels;
                                            responseTaskActionList.someObject.columns = columns;
                                            if (someObjectIds.size() > 0) {
                                                List<SObject> selectedSObjectResults = Database.query('SELECT ' + String.join(selectFields, ' ,') + ' FROM ' + selectedSObjectName + ' WHERE Id IN :someObjectIds' + qOrderByObject);
                                                responseTaskActionList.someObject.results = selectedSObjectResults;
                                                responseTaskActionList.someObject.resultsMap = new Map<Id, SObject>(selectedSObjectResults);
                                            }
                                        } else {
                                            throw new CustomException(System.Label.sfims.error_message_32);
                                        }
                                    }
                                }
                            }
                        }
                        response = JSON.serialize(responseTaskActionList);
                    } else {
                        throw new CustomException(System.Label.sfims.error_message_33);
                    }
                } else {
                    throw new CustomException(System.Label.sfims.error_message_53);
                }
            } else {
                throw new CustomException(System.Label.sfims.error_message_33);
            }
        } catch (Exception err) {
            throw new CustomException(err.getMessage());
        }
        return response;
    }
}