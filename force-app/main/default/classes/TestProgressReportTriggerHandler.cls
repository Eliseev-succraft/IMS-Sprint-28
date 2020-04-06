@isTest
private class TestProgressReportTriggerHandler {
    
    @isTest static void test_progress_report_methods() {
        User platformUser = TestUtils.createPlatformUser();
        system.runAs(platformUser){        
            Account a = TestUtils.createAccount('Investee_Account','test',null);
            Application__c appl = TestUtils.createNewApplication(a.Id);

            Progress_Report__c pr = new Progress_Report__c();
            pr.Application__c = appl.Id;
            insert pr;

            System.assertEquals(a.Id,[Select Organisation__c from Progress_Report__c Where Application__c = :appl.Id].organisation__c);

            pr.From_period__c = system.today();
            update pr;
                
            delete pr;
        }    
        
    }

    @isTest static void test_delete_child_records() {
        Progress_Report__c pr = new Progress_Report__c();
        insert pr;
        Progress_Report_Indicators__c pri = new Progress_Report_Indicators__c(Progress_Report__c = pr.Id);
        insert pri;

        delete pr;
        
        List<Progress_Report_Indicators__c> progressReportIndicators = [
            SELECT Id 
            FROM Progress_Report_Indicators__c
            WHERE Progress_Report__c = :pr.Id
        ];
        
        System.assertEquals(0, progressReportIndicators.size());
    }
}