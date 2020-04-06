/** Action list functionality * @author Alexey Eliseev * @date 8/28/19 **/
@IsTest
private class TestTaskTrigger {
    @IsTest static void test_TaskTrigger() {
        Test.startTest();

        // get Record Types
        Id customRecordTypeId;
        Map<String, RecordTypeInfo> recordTypes = Schema.SObjectType.Task.getRecordTypeInfosByName();
        if (recordTypes.containsKey('Custom')) {
            customRecordTypeId = recordTypes.get('Custom').getRecordTypeId();
        }
        System.assertNotEquals(null, customRecordTypeId, System.Label.sfims.error_message_36);

        Id standardRecordTypeId;
        if (recordTypes.containsKey('Standard')) {
            standardRecordTypeId = recordTypes.get('Standard').getRecordTypeId();
        }
        System.assertNotEquals(null, customRecordTypeId, 'There is a Standard record type has not been found on the Task object.');

        // Insert Task List Template
        Task_List_Template__c taskListTemplate1 = new Task_List_Template__c(Object_Name__c = 'Account', Object_Status_Field__c = 'Name', Trigger_Status__c = 'Test');
        insert taskListTemplate1;
        System.assertEquals(1, [SELECT Id FROM Task_List_Template__c].size(), 'Task List Template counts are not correct');

        // insert Task List Template Items
        Task_List_Template_Item__c taskListTemplateItem1 = new Task_List_Template_Item__c(
                Flow_Name__c = 'Test_Flow',
                Task_Type__c = 'Custom',
                Subject__c = 'Fill in form',
                Priority__c = 'Low',
                Approval_Required__c = true,
                Task_List_Template__c = taskListTemplate1.Id
        );
        insert taskListTemplateItem1;
        System.assertEquals(1, [SELECT Id FROM Task_List_Template_Item__c].size(), 'Task List Template Item counts are not correct');

        Task_List_Template_Item__c taskListTemplateItem2 = new Task_List_Template_Item__c(
                Task_Type__c = 'Custom',
                Subject__c = 'Call',
                Priority__c = 'Low',
                Task_List_Template__c = taskListTemplate1.Id,
                Depends_On__c = taskListTemplateItem1.Id
        );
        insert taskListTemplateItem2;
        System.assertEquals(2, [SELECT Id FROM Task_List_Template_Item__c].size(), 'Task List Template Item counts are not correct');

        // insert standard task
        Task standardTask1 = new Task(
                Status = 'Open',
                RecordTypeId = standardRecordTypeId,
                Subject = 'Test standard task',
                ActivityDate = Date.today(),
                Priority = 'Low'
        );
        insert standardTask1;
        System.assertEquals(1, [SELECT Id FROM Task WHERE RecordTypeId = :standardRecordTypeId].size(), 'Tasks counts are not correct');

        // update standard task
        standardTask1.Status = 'Done';
        standardTask1.Description = 'Test';
        try {
            update standardTask1;
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }

        // insert custom tasks
        Task customTask1 = new Task(
                Status = 'Open',
                RecordTypeId = customRecordTypeId,
                Subject = 'Test custom task1',
                ActivityDate = Date.today(),
                Priority = 'Low',
                Read_Only__c = true,
                Task_List_Template_Item__c = taskListTemplateItem1.Id
        );
        insert customTask1;
        Task customTask1_1 = new Task(
                Status = 'Open',
                RecordTypeId = customRecordTypeId,
                Subject = 'Test custom task1',
                ActivityDate = Date.today(),
                Priority = 'Low',
                Read_Only__c = true,
                Task_List_Template_Item__c = taskListTemplateItem1.Id
        );
        insert customTask1_1;
        Task customTask2 = new Task(
                Status = 'Pending',
                RecordTypeId = customRecordTypeId,
                Subject = 'Test custom task2',
                ActivityDate = Date.today(),
                Priority = 'Low',
                Read_Only__c = true,
                Depends_On__c = customTask1.Id,
                Task_List_Template_Item__c = taskListTemplateItem2.Id
        );
        Task customTask2_1 = new Task(
                Status = 'Pending',
                RecordTypeId = customRecordTypeId,
                Subject = 'Test custom task2',
                ActivityDate = Date.today(),
                Priority = 'Low',
                Read_Only__c = true,
                Depends_On__c = customTask1_1.Id,
                Task_List_Template_Item__c = taskListTemplateItem2.Id
        );
        Task customTask3 = new Task(
                Status = 'Open',
                RecordTypeId = customRecordTypeId,
                Subject = 'Test custom task3',
                ActivityDate = Date.today(),
                Priority = 'Low',
                Read_Only__c = true,
                Task_List_Template_Item__c = taskListTemplateItem2.Id
        );
        Task customTask4 = new Task(
                Status = 'Rejected',
                RecordTypeId = customRecordTypeId,
                Subject = 'Test custom task4',
                ActivityDate = Date.today(),
                Priority = 'Low',
                Read_Only__c = true,
                Task_List_Template_Item__c = taskListTemplateItem1.Id
        );
        Task customTask5 = new Task(
                Status = 'Pending Approval',
                RecordTypeId = customRecordTypeId,
                Subject = 'Test custom task4',
                ActivityDate = Date.today(),
                Priority = 'Low',
                Read_Only__c = true,
                Task_List_Template_Item__c = taskListTemplateItem1.Id
        );
        Task customTask6 = new Task(
                Status = 'Open',
                RecordTypeId = customRecordTypeId,
                Subject = 'Test custom task4',
                ActivityDate = Date.today(),
                Priority = 'Low',
                Read_Only__c = false,
                Task_List_Template_Item__c = taskListTemplateItem1.Id
        );
        insert new List<Task>{
                customTask2, customTask2_1, customTask3, customTask4, customTask5, customTask6
        };
        System.assertEquals(8, [SELECT Id FROM Task WHERE RecordTypeId = :customRecordTypeId].size(), 'Tasks counts are not correct');


        // delete as a user
        /*
        profiles = [SELECT Name FROM Profile WHERE Name != 'System Administrator'];
        TestUtils.autoCommit = false;
        User someUser = TestUtils.createPlatformUser();
        someUser.FirstName = 'Test1';
        someUser.LastName = 'User1';
        someUser.Alias = 'Test1';
        someUser.Email = 'testUser1@singlify.com';
        someUser.Username = 'testdealer1@singlify.com';
        someUser.CommunityNickname = 'TestUser1';
        someUser.ProfileId = profiles.get(0).Id;
        insert someUser;

        System.runAs(someUser) {
            try {
                delete customTask3;
                System.assertEquals(false, true, 'Invalid exception');
            } catch (Exception err) {
                System.assert(err.getMessage().length() > 0, 'Invalid exception message');
            }
        }
        */

        // delete as a system administrator
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        TestUtils.autoCommit = false;
        User administratorUser = TestUtils.createPlatformUser();
        administratorUser.ProfileId = profiles.get(0).Id;
        insert administratorUser;
        System.runAs(administratorUser) {
            try {
                delete customTask3;
            } catch (Exception err) {
                System.assertEquals(false, true, 'Invalid exception');
            }
        }

        customTask1.Description = 'Test';
        try {
            update customTask1;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_56), 'Invalid exception message');
        }

        customTask1.Description = null;
        customTask1.Status = 'Done';
        try {
            update customTask1;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_57), 'Invalid exception message');
        }

        customTask1.Status = 'Pending Approval';
        try {
            update customTask1;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_55), 'Invalid exception message');
        }

        customTask1.Status = 'Pending';
        try {
            update customTask1;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_55), 'Invalid exception message');
        }

        customTask1.Status = 'Pending Approval'; // -> Done i.e. not approval process
        customTask1.Read_Only__c = false; // -> Done i.e. not approval process
        try {
            update customTask1;
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }

        /* ----------------------------------- */

        customTask2_1.Status = 'Open';
        try {
            update customTask2_1;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_55), 'Invalid exception message');
        }

        customTask2_1.Status = 'Done';
        try {
            update customTask2_1;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.part_of_error_message_30), 'Invalid exception message');
        }

        customTask2_1.Status = 'Rejected';
        try {
            update customTask2_1;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_55), 'Invalid exception message');
        }

        /* ----------------------------------- */

        customTask5.Status = 'Done';
        try {
            update customTask5;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_58), 'Invalid exception message');
        }

        customTask5.Status = 'Rejected';
        try {
            update customTask5;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_58), 'Invalid exception message');
        }

        customTask5.Status = 'Open';
        try {
            update customTask5;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_58), 'Invalid exception message');
        }

        customTask5.Status = 'Pending';
        try {
            update customTask5;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_55), 'Invalid exception message');
        }

        /* ----------------------------------- */

        customTask4.Status = 'Done';
        try {
            update customTask4;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_57), 'Invalid exception message');
        }

        customTask4.Status = 'Pending';
        try {
            update customTask4;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_55), 'Invalid exception message');
        }

        customTask4.Status = 'Pending Approval';
        try {
            update customTask4;
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.error_message_55), 'Invalid exception message');
        }

        /* ----------------------------------- */

        customTask6.Status = 'Pending Approval';
        try {
            update customTask6;
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }

        Test.stopTest();
    }
}