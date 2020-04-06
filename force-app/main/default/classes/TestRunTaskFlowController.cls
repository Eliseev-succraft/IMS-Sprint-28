/**
* @description         Quick action component for running flow
* @author              Alexey Eliseev
* @date                8/28/19
* @component           RunTaskFlow
**/

@IsTest
private with sharing class TestRunTaskFlowController {
    @IsTest static void test_RunTaskFlowController() {
        Test.startTest();
        Id customRecordTypeId;
        Map<String, RecordTypeInfo> recordTypes = Schema.SObjectType.Task.getRecordTypeInfosByName();
        if (recordTypes.containsKey('Custom')) {
            customRecordTypeId = recordTypes.get('Custom').getRecordTypeId();
        }
        System.assertNotEquals(null, customRecordTypeId, 'There is a Custom record type has not been found on the Task object.');

        Id standardRecordTypeId;
        if (recordTypes.containsKey('Standard')) {
            standardRecordTypeId = recordTypes.get('Standard').getRecordTypeId();
        }
        System.assertNotEquals(null, customRecordTypeId, 'There is a Standard record type has not been found on the Task object.');

        Task_List_Template__c taskListTemplate1 = new Task_List_Template__c(Object_Name__c = 'Account', Object_Status_Field__c = 'Name');
        insert taskListTemplate1;
        System.assertEquals(1, [SELECT Id FROM Task_List_Template__c].size(), 'Task List Template counts are not correct');

        Task_List_Template_Item__c taskListTemplateItem1 = new Task_List_Template_Item__c(
                Flow_Name__c = 'Test_Flow',
                Task_Type__c = 'Custom',
                Subject__c = 'Fill in form',
                Priority__c = 'Low',
                Task_List_Template__c = taskListTemplate1.Id
        );
        insert taskListTemplateItem1;
        System.assertEquals(1, [SELECT Id FROM Task_List_Template_Item__c].size(), 'Task List Template Item counts are not correct');

        Task standardTask1 = new Task(
                Status = 'Open',
                RecordTypeId = standardRecordTypeId,
                Subject = 'Test standard task',
                ActivityDate = Date.today(),
                Priority = 'Low'
        );
        insert standardTask1;
        System.assertEquals(1, [SELECT Id FROM Task WHERE RecordTypeId = :standardRecordTypeId].size(), 'Tasks counts are not correct');

        Task customTask1 = new Task(
                Status = 'Open',
                RecordTypeId = customRecordTypeId,
                Subject = 'Test custom task',
                ActivityDate = Date.today(),
                Priority = 'Low',
                Read_Only__c = true,
                Task_List_Template_Item__c = taskListTemplateItem1.Id
        );
        insert customTask1;
        System.assertEquals(1, [SELECT Id FROM Task WHERE RecordTypeId = :customRecordTypeId].size(), 'Tasks counts are not correct');

        String json = RunTaskFlowController.apexGetFlowName(customTask1.Id);
        System.assertNotEquals(null, json, 'The Flow name is empty.');

        try {
            System.assertEquals(true, RunTaskFlowController.apexChangeStatusTask(customTask1.Id, 'Done'), 'Invalid exception message');
        } catch (Exception err) {
            System.assertEquals(0, err.getMessage().length(), 'Invalid exception message');
        }

        Boolean isException = false;
        try {
            RunTaskFlowController.apexChangeStatusTask(customTask1.Id, null);
        } catch (Exception err) {
            System.assert(err.getMessage().length() > 0, 'Invalid exception message');
            isException = true;
        }
        System.assertEquals(true, isException, 'Invalid exception message');
        Test.stopTest();
    }
}