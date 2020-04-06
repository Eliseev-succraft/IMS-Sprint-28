trigger ProgressReportTrigger on Progress_Report__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {

    if (Trigger.isBefore && Trigger.isInsert) {

		setDefaults(Trigger.new);
		updateStatus(Trigger.new);
    }
    
    
    if (Trigger.isBefore && Trigger.isUpdate) {
        updateStatus(Trigger.new);
    }


    if (Trigger.isAfter && Trigger.isInsert) {

		scheduleReports(Trigger.new);

    }

    // /*=================================================================================================================
    // * @description         Delete links from Progress Report Indicator
    // * @author              Alexey Eliseev
    // * @component           ScheduleReports
    // * @date                1/18/19
    // */
    if (Trigger.isDelete && Trigger.isBefore) {
        //deleteIndicatorLinks(Trigger.Old);
        deleteChildRecords(Trigger.oldMap);
    }

    /*=================================================================================================================*/
    
    private void setDefaults(List<Progress_Report__c> newList){
        //-----Automatically set default values for some fields on the transaction--------------------------------------
        // collect info
        Map<Id, Application__c> applicationIdToApplication = new Map<Id, Application__c>();
        for (Progress_Report__c tr : newList) {

            // gather application (for setting the correct account).
            if (tr.Application__c != null) applicationIdToApplication.put(tr.Application__c, null);
            
        }
        if (!applicationIdToApplication.isEmpty()) {
            for (Application__c appl : [SELECT Id, Organisation__c FROM Application__c WHERE Id IN :applicationIdToApplication.keySet()]) {
                applicationIdToApplication.put(appl.Id, appl);
            }
        }

        for (Progress_Report__c pr : newList) {
            // set organisation (copy from application)
            if (applicationIdToApplication.containsKey(pr.Application__c)) {
                pr.Organisation__c = applicationIdToApplication.get(pr.Application__c).Organisation__c;
            } 
        }        
    }
    
    private void updateStatus(List<Progress_Report__c> newList){
        // auto-set status if not submitted yet
        for (Progress_Report__c pr : newList) {
            if(pr.Status__c == '' || pr.Status__c == null || pr.Status__c == 'Due' || pr.Status__c == 'Not Due'){
            	if(pr.Report_Due_Date__c > System.today()) {
                	pr.Status__c = 'Not Due';
                } else {
                    pr.Status__c = 'Due';
                }
            }
        }        
    }
    
    /*=================================================================================================================
    * @description         Creating links from Report Template Indicators to Progress Report
    * @author              Alexey Eliseev
    * @component           ScheduleReports
    * @date                1/16/19
    */    
    private void scheduleReports(List<Progress_Report__c> newList){
        
        Set<Id> ReportTemplateIds = new Set<Id>();
        for (Progress_Report__c ProgressReportItem : newList) {
            if (String.isNotBlank(ProgressReportItem.Report_Template__c)) {
                ReportTemplateIds.add(ProgressReportItem.Report_Template__c);
            }
        }

        if (ReportTemplateIds.size() > 0) {

            List<Progress_Report_Indicators__c> newProgressReportIndicators = new List<Progress_Report_Indicators__c>();

            List<Report_Template_Indicator__c> ReportTemplateIndicatorItems = [
                    SELECT Indicator_Catalogue__c, Report_Template__c, Sequence_Number__c
                    FROM Report_Template_Indicator__c
                    WHERE Report_Template__c IN :ReportTemplateIds
            ];

            for (Progress_Report__c ProgressReportItem : newList) {
                for (Report_Template_Indicator__c ReportTemplateIndicatorItem : ReportTemplateIndicatorItems) {
                    if (ReportTemplateIndicatorItem.Report_Template__c == ProgressReportItem.Report_Template__c) {
                        newProgressReportIndicators.add(new Progress_Report_Indicators__c(
                                Indicator_Catalogue__c = ReportTemplateIndicatorItem.Indicator_Catalogue__c,
                                Progress_Report__c = ProgressReportItem.Id,
                                Sequence_Number__c = ReportTemplateIndicatorItem.Sequence_Number__c
                        ));
                    }
                }
            }

            if (newProgressReportIndicators.size() > 0) {
                insert newProgressReportIndicators;
            }
        }        
    }

    // /*=================================================================================================================
    // * @description         Delete links from Progress Report Indicator
    // * @author              Alexey Eliseev
    // * @component           ScheduleReports
    // * @date                1/18/19
    // */
    // private void deleteIndicatorLinks(List<Progress_Report__c> oldList){
    //     Set<Id> ProgressReportIds = new Set<Id>();
    //     for (Progress_Report__c ReportTemplateItem : oldList) {
    //         ProgressReportIds.add(ReportTemplateItem.Id);
    //     }
    //     if (ProgressReportIds.size() > 0) {
    //         delete [SELECT Name FROM Progress_Report_Indicators__c WHERE Progress_Report__c IN :ProgressReportIds];
    //     }
    // }
    
    private void deleteChildRecords(Map<Id, Progress_Report__c> oldProgressReportsMap){
        delete [SELECT Id FROM Progress_Report_Indicators__c WHERE Progress_Report__c IN :oldProgressReportsMap.keySet()];
    }    
}