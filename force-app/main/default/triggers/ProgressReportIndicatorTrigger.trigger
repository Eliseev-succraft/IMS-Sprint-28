trigger ProgressReportIndicatorTrigger on Progress_Report_Indicators__c (before insert) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        setDefaultFields();
    }

    public void setDefaultFields(){
        Map<Id, Indicator_Catalogue__c> indicatorCatalogueIdToIndicatorCatalogue = new Map<Id, Indicator_Catalogue__c>();
        for (Progress_Report_Indicators__c temp : Trigger.new) {
            if (temp.Indicator_Catalogue__c != null && temp.Indicator_Type__c == null) 
                indicatorCatalogueIdToIndicatorCatalogue.put(temp.Indicator_Catalogue__c, null);
        }

        if (!indicatorCatalogueIdToIndicatorCatalogue.isEmpty()) {
            for (Indicator_Catalogue__c ic : [SELECT Indicator_Type__c FROM Indicator_Catalogue__c 
                WHERE Id IN :indicatorCatalogueIdToIndicatorCatalogue.keySet()]) 
            {
                indicatorCatalogueIdToIndicatorCatalogue.put(ic.Id, ic);
            }

            for (Progress_Report_Indicators__c temp : Trigger.new) {
                if (temp.Indicator_Catalogue__c != null && temp.Indicator_Type__c == null) 
                    temp.Indicator_Type__c = indicatorCatalogueIdToIndicatorCatalogue.get(temp.Indicator_Catalogue__c).Indicator_Type__c;    
            }
        }
    }
}