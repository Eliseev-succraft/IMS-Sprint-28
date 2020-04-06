/** Action list functionality * @author Alexey Eliseev * @date 9/20/19 **/
@IsTest
private with sharing class TestTaskApprovalTrigger {
    @IsTest static void test_TaskApprovalTrigger() {
        Test.startTest();
        Id customRecordTypeId;
        Map<String, RecordTypeInfo> recordTypes = Schema.SObjectType.Task.getRecordTypeInfosByName();
        if (recordTypes.containsKey('Custom')) {
            customRecordTypeId = recordTypes.get('Custom').getRecordTypeId();
        }
        System.assertNotEquals(null, customRecordTypeId, 'There is a Custom record type has not been found on the Task object.');

        // insert custom tasks
        Task customTask1 = new Task(
                Status = 'Pending Approval',
                RecordTypeId = customRecordTypeId,
                Subject = 'Test custom task',
                ActivityDate = Date.today(),
                Priority = 'Low',
                Read_Only__c = true
        );
        Task customTask2 = new Task(
                Status = 'Pending Approval',
                RecordTypeId = customRecordTypeId,
                Subject = 'Test custom task',
                ActivityDate = Date.today(),
                Priority = 'Low',
                Read_Only__c = true
        );
        Task customTask3 = new Task(
                Status = 'Pending Approval',
                RecordTypeId = customRecordTypeId,
                Subject = 'Test custom task',
                ActivityDate = Date.today(),
                Priority = 'Low',
                Read_Only__c = true
        );
        insert new List<Task>{
                customTask1, customTask2, customTask3
        };
        System.assertEquals(3, [SELECT Id FROM Task WHERE RecordTypeId = :customRecordTypeId].size(), 'Tasks counts are not correct');

        // insert task Approvals
        Task_Approval__c customTaskApproval1 = new Task_Approval__c(
                Task_Id__c = customTask1.Id,
                Status__c = 'Pending'
        );
        Task_Approval__c customTaskApproval2 = new Task_Approval__c(
                Task_Id__c = customTask2.Id,
                Status__c = 'Pending'
        );
        Task_Approval__c customTaskApproval3 = new Task_Approval__c(
                Task_Id__c = customTask3.Id,
                Status__c = 'Pending'
        );
        insert new List<Task_Approval__c>{
                customTaskApproval1, customTaskApproval2, customTaskApproval3
        };

        try {
            customTaskApproval1.Status__c = 'Approved';
            update customTaskApproval1;
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        System.assertEquals(1, [SELECT Id FROM Task WHERE RecordTypeId = :customRecordTypeId AND Id = :customTask1.Id AND Status = 'Done'].size(), 'Tasks counts are not correct');

        try {
            customTaskApproval2.Status__c = 'Rejected';
            update customTaskApproval2;
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        System.assertEquals(1, [SELECT Id FROM Task WHERE RecordTypeId = :customRecordTypeId AND Id = :customTask2.Id AND Status = 'Rejected'].size(), 'Tasks counts are not correct');

        try {
            customTaskApproval3.Status__c = 'Recalled';
            update customTaskApproval3;
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        System.assertEquals(1, [SELECT Id FROM Task WHERE RecordTypeId = :customRecordTypeId AND Id = :customTask3.Id AND Status = 'Open'].size(), 'Tasks counts are not correct');

        Test.stopTest();
    }
}