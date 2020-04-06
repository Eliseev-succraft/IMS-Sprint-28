/** Action list functionality * @author Alexey Eliseev * @date 8/28/19 **/
@IsTest
private with sharing class TestTaskListTemplateTrigger {
    @IsTest static void test_TaskListTemplateTrigger() {
        Test.startTest();
        Boolean isException = false;
        try {
            insert new Task_List_Template__c(Object_Name__c = 'Account', Object_Status_Field__c = 'Name1');
        } catch (Exception err) {
            System.assert(err.getMessage().length() > 0, 'Invalid exception message');
            isException = true;
        }
        System.assertEquals(true, isException, 'Invalid exception message');

        isException = false;
        try {
            insert new Task_List_Template__c(Object_Name__c = 'Account1', Object_Status_Field__c = 'Name');
        } catch (Exception err) {
            isException = true;
            System.assert(err.getMessage().length() > 0, 'Invalid exception message');
        }
        System.assertEquals(true, isException, 'Invalid exception message');

        isException = false;
        try {
            insert new Task_List_Template__c(Object_Name__c = 'Account');
        } catch (Exception err) {
            isException = true;
            System.assert(err.getMessage().length() > 0, 'Invalid exception message');
        }
        System.assertEquals(true, isException, 'Invalid exception message');
        Test.stopTest();
    }
}