/** Action list functionality * @author Alexey Eliseev * @date 8/28/19 **/
@IsTest
private with sharing class TestTaskListTemplateItemTrigger {
    @IsTest static void test_TaskListTemplateItemTrigger() {
        Test.startTest();
        try {
            insert new Task_List_Template_Item__c();
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.part_of_error_message_26 + ': Subject, Task List Template.'), 'Invalid exception message');
        }
        Task_List_Template__c taskListTemplate1 = new Task_List_Template__c(Object_Name__c = 'sfims__Application__c', Object_Status_Field__c = 'Name');
        insert taskListTemplate1;
        try {
            insert new Task_List_Template_Item__c(Subject__c = 'Subject', Task_List_Template__c = taskListTemplate1.Id);
        } catch (Exception err) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        // Related Field is empty
        try {
            insert new Task_List_Template_Item__c(Subject__c = 'Subject', Assignee_Type__c = 'Related Field', Task_List_Template__c = taskListTemplate1.Id);
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.part_of_error_message_26 + ': Assignee Field.'), 'Invalid exception message');
        }
        // Not exists related field
        try {
            insert new Task_List_Template_Item__c(Subject__c = 'Subject', Assignee_Type__c = 'Related Field', Assignee_Field__c = 'Test', Task_List_Template__c = taskListTemplate1.Id);
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.part_of_error_message_1 + ' "Test" ' + System.Label.sfims.part_of_error_message_28 + ' ' + System.Label.sfims.part_of_error_message_20 + ' "sfims__Application__c" ' + System.Label.sfims.part_of_error_message_25 + '.'), 'Invalid exception message');
        }
        // Approval_Required__c = true
        try {
            insert new Task_List_Template_Item__c(Subject__c = 'Subject', Assignee_Type__c = 'Related Field', Task_List_Template__c = taskListTemplate1.Id, Approval_Required__c = true);
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.part_of_error_message_26 + ': Assignee Field, Flow Name. ' + System.Label.sfims.part_of_error_message_27), 'Invalid exception message');
        }
        // Assignee_Type__c = User
        try {
            insert new Task_List_Template_Item__c(Subject__c = 'Subject', Assignee_Type__c = 'User', Task_List_Template__c = taskListTemplate1.Id);
            System.assertEquals(false, true, 'Invalid exception');
        } catch (Exception err) {
            System.assert(err.getMessage().contains(System.Label.sfims.part_of_error_message_26 + ': Assignee User.'), 'Invalid exception message');
        }

        Test.stopTest();
    }
}