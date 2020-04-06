public without sharing class RunTaskFlowController {

    public class TaskClass {
        Task standardTask;
        Task_List_Template_Item__c taskListTemplateItem;
        String status;
        String resumeFlowId;
    }

    @AuraEnabled
    public static String apexGetFlowName(Id taskId) {
        String response;
        try {
            List<Task> tasks = [
                    SELECT Task_List_Template_Item__c, WhatId, Status
                    FROM Task
                    WHERE Id = :taskId
            ]; 
            if (tasks.size() > 0) {
                Task currentTask = tasks.get(0);
                if (String.isNotBlank(currentTask.Status)) {
                    TaskClass responseToJSON = new TaskClass();
                    /* Resume a Flow Interview from an Aura Component */
                    String currentUser = UserInfo.getUserId();
                    List<FlowInterview> interviews = [
                            SELECT Id
                            FROM FlowInterview
                            WHERE CreatedById = :currentUser AND InterviewLabel = :taskId
                            ORDER BY CreatedDate DESC
                    ];
                    if (interviews != null && !interviews.isEmpty()) {
                        responseToJSON.resumeFlowId = interviews.get(0).Id;
                    }
                    /* END Resume a Flow Interview from an Aura Component */
                    responseToJSON.status = currentTask.Status;
                    if (currentTask.Status == 'Open' || currentTask.Status == 'Rejected') {
                        List<Task_List_Template_Item__c> taskListTemplateItems = [
                                SELECT Flow_Name__c, Approval_Required__c
                                FROM Task_List_Template_Item__c
                                WHERE Id = :currentTask.Task_List_Template_Item__c
                        ];
                        if (taskListTemplateItems.size() > 0) {
                            responseToJSON.standardTask = currentTask;
                            responseToJSON.taskListTemplateItem = taskListTemplateItems.get(0);
                        }
                    }
                    response = JSON.serialize(responseToJSON);
                }
            }
        } catch (Exception err) {
            throw new AuraHandledException(err.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static Boolean apexChangeStatusTask(Id taskId, String status) {
        Boolean response = false;
        try {
            List<Task> tasks = [SELECT Status FROM Task WHERE Id = :taskId];
            if (tasks.size() > 0) {
                Task taskUpdate = tasks.get(0);
                taskUpdate.Read_Only__c = false;
                taskUpdate.Status = status;
                update taskUpdate;
                response = true;
            }
        } catch (Exception err) {
            throw new AuraHandledException(err.getMessage());
        }
        return response;
    }

}