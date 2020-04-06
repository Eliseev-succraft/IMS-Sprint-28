@isTest
private class TestProgressReportIndicatorTrigger {
    @isTest static void test_set_default_fields() {
        Indicator_Catalogue__c ic = new Indicator_Catalogue__c(
            Active__c = true,
            RecordTypeId = Schema.SObjectType.sfims__Indicator_Catalogue__c.getRecordTypeInfosByName().get('Custom').getRecordTypeId(),
            Indicator_Name__c ='Indicator Custom - 00001',
            Indicator_Type__c = 'Text',
            Outcome_Area__c = 'Education',
            Standard_Custom__c = 'Custom'
        );

        Progress_Report__c pr = new Progress_Report__c();
        insert new List<SObject>{ ic, pr };

        Progress_Report_Indicators__c pri = new Progress_Report_Indicators__c(
            Progress_Report__c = pr.Id,
            Indicator_Catalogue__c = ic.Id
        );
        insert pri;

        Progress_Report_Indicators__c result = [
            SELECT Indicator_Type__c
            FROM Progress_Report_Indicators__c
            WHERE Id = :pri.Id
        ];

        System.assertEquals(result.Indicator_Type__c, ic.Indicator_Type__c);
    }
}