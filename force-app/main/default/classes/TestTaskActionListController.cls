@IsTest
private with sharing class TestTaskActionListController {
    @IsTest static void test_TaskActionListController() {
        Test.startTest();
        Id customRecordTypeId;
        Map<String, RecordTypeInfo> recordTypes = Schema.SObjectType.Task.getRecordTypeInfosByName();
        if (recordTypes.containsKey('Custom')) {
            customRecordTypeId = recordTypes.get('Custom').getRecordTypeId();
        }
        System.assertNotEquals(null, customRecordTypeId, 'Custom record type has not been found on the Task object.');
        // insert testing related records
        Application__c app1 = TestUtils.createNewApplication();
        app1.Name = 'TestApp';
        insert app1;
        // insert custom tasks
        Task customTask1 = new Task(
                Status = 'Open',
                RecordTypeId = customRecordTypeId,
                Subject = 'Test custom task',
                ActivityDate = Date.today(),
                Priority = 'Low',
                Read_Only__c = true,
                WhatId = app1.Id
        );
        insert customTask1;
        Id recordId = app1.Id;
        String statusFilter = 'Open';
        String customTaskFields = 'Subject, WhatId, OwnerId, ActivityDate, Status, Start';
        String customObjectFields = 'Name, sfims__Stage__c';
        String showTasks = 'All tasks';
        Boolean isOnlyMyTasks = false;
        String searchValue = 'Test';
        Boolean isTaskField = true;
        String sortingField = '';
        Boolean isDescSorting = false;
        Boolean isDebugLog = true;
        try {
            String results = TaskActionListController.getTasks(recordId, statusFilter, customTaskFields, customObjectFields, showTasks, isOnlyMyTasks, searchValue, isTaskField, sortingField, isDescSorting, isDebugLog);
            System.assertNotEquals(null, results);
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        try {
            System.assertEquals(true, TaskActionListController.changeTaskStatus(customTask1.Id, 'Done'));
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        try {
            System.assertEquals(true, TaskActionListController.deleteTask(customTask1.Id));
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        Test.stopTest();
    }
}