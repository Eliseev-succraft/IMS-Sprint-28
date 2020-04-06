/*
 * @description         This is controller for the component SheduleReports
 * @author              Alexey Eliseev
 * @component           SheduleReports
 * @date                1/16/19
*/

public with sharing class ScheduleReportsController {
    @AuraEnabled
    public static list<Progress_Report__c> generatedProgressReport(Id application, Id reportTemplate, String prDate, String prFrequency, Integer prNumber) {
        Date newDate = Date.valueOf(prDate);
        // calculate startdate for first period
        Date periodStartDate;
        switch on prFrequency {
            when 'Monthly' {
                periodStartDate = newDate.addmonths(-1).addDays(1);
            }
            when 'Quarterly' {
                periodStartDate = newDate.addmonths(-3).addDays(1);
            }
            when 'Yearly' {
                periodStartDate = newDate.addyears(-1).addDays(1);
            }
        }        

        list<Progress_Report__c> addProgressReport = new list<Progress_Report__c>();
        
        for (Integer i = 0; i < prNumber; i++) {
            
            addProgressReport.add(
                new Progress_Report__c(
                    Application__c = application, 
                    Report_Due_Date__c = newDate, 
                    Report_Template__c = reportTemplate,
                    From_Period__c = periodStartDate,
                    To_Period__c = newDate
                )
            );
            // set startdate of new period
            periodStartDate = newDate.addDays(1);
            // determin enddate of new period
            switch on prFrequency {
                when 'Monthly' {
                    newDate = newDate.addmonths(1);
                }
                when 'Quarterly' {
                    newDate = newDate.addmonths(3);
                }
                when 'Yearly' {
                    newDate = newDate.addyears(1);
                }
            }
            
        }

        if (addProgressReport.size() > 0) {
            insert addProgressReport;
        }

        return addProgressReport;
    }
}