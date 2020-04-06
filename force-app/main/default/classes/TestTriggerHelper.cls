/** Action list functionality * @author Alexey Eliseev * @date 8/28/19 **/
@IsTest
private with sharing class TestTriggerHelper {
    @IsTest static void test_TriggerHelper() {
        Test.startTest();

        /** Insert **/
        Task_List_Template__c taskListTemplate1 = new Task_List_Template__c(Object_Name__c = 'Case', Object_Status_Field__c = 'Type', Trigger_Status__c = 'Other');
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

        Task_List_Template_Item__c taskListTemplateItem2 = new Task_List_Template_Item__c(
                Flow_Name__c = 'Test_Flow',
                Task_Type__c = 'Custom',
                Subject__c = 'Fill in form',
                Priority__c = 'Low',
                Task_List_Template__c = taskListTemplate1.Id,
                Depends_On__c = taskListTemplateItem1.Id
        );
        insert taskListTemplateItem2;
        System.assertEquals(2, [SELECT Id FROM Task_List_Template_Item__c].size(), 'Task List Template Item counts are not correct');

        Case case1 = new Case(Type = 'Other');
        insert case1;

        List<Case> cases = new List<Case>{
                case1
        };
 
        try {
            TriggerHelper.createCustomTask(new Map<Id, Case>(cases), null, false);
        } catch (Exception err) {
            System.assertEquals(0, err.getMessage().length(), 'Invalid exception message');
        }
        System.assertEquals(2, [SELECT Id FROM Task].size(), 'Task counts are not correct');
        System.assertEquals(1, [SELECT Id FROM Task WHERE Status = 'Open'].size(), 'Task counts are not correct');

        /** Update **/

        List<Case> oldCases = new List<Case>(cases);
        for (Case itemCase : oldCases) {
            itemCase.Type = 'Mechanical';
        }
        cases = [SELECT Type, OwnerId FROM Case];

        try {
            TriggerHelper.createCustomTask(new Map<Id, Case>(cases), new Map<Id, Case>(oldCases), true);
        } catch (Exception err) {
            System.assertEquals(0, err.getMessage().length(), 'Invalid exception message');
        }
        Test.stopTest();
    }
}