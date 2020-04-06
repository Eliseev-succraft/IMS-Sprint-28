/*=================================================================================================================
* @description         Delete links from Report Template Indicators
* @author              Alexey Eliseev
* @component           ScheduleReports
* @date                1/18/19
*/

trigger ReportTemplateTrigger on Report_Template__c (before delete) {
    if (Trigger.isDelete) {
    	delete [SELECT Name FROM Report_Template_Indicator__c WHERE Report_Template__c IN :Trigger.oldMap.keySet()];
    }
}