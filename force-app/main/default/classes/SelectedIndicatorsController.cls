/* Report Template functionality * @author Alexey Eliseev * @date 2/11/19 * component SelectedIndicators */

public without sharing class SelectedIndicatorsController {

    public class CommonException extends Exception {
    }

    @AuraEnabled
    public static String loadSelectedIndicators(Id templateId) {
        String response = '';
        try {
            IndicatorCatalogsController.getIndicatorCatalogsDataClass indicatorCatalogsData = new IndicatorCatalogsController.getIndicatorCatalogsDataClass();

            indicatorCatalogsData.allIndicators = new List<Indicator_Catalogue__c>();
            Set<Id> indicatorId = new Set<Id>();
            List<Report_Template_Indicator__c> junctionObject = [
                    SELECT Indicator_Catalogue__c
                    FROM Report_Template_Indicator__c
                    WHERE Report_Template__c = :templateId
                    ORDER BY Sequence_Number__c, Id
            ];
            for (Report_Template_Indicator__c i : junctionObject) {
                indicatorId.add(i.Indicator_Catalogue__c);
            }
            List<Indicator_Catalogue__c> results = [
                    SELECT Indicator_Name__c, Indicator_Type__c, RecordTypeId, RecordType.Name, Standard_Custom__c, Definition__c, Outcome_Area__c
                    FROM Indicator_Catalogue__c
                    WHERE Id IN :indicatorId
            ];
            Map<Id, Indicator_Catalogue__c> resultsMap = new Map<Id, Indicator_Catalogue__c>(results);
            for (Id i : indicatorId) {
                if (resultsMap.containsKey(i)) {
                    indicatorCatalogsData.allIndicators.add(resultsMap.get(i));
                }
            }

            /*
            indicatorCatalogsData.allIndicators = new List<Indicator_Catalogue__c>();
            List<sfims__Report_Template_Indicator__c> indicators = [
                    SELECT Id,
                            Indicator_Catalogue__r.Indicator_Name__c,
                            Indicator_Catalogue__r.Indicator_Type__c,
                            Indicator_Catalogue__r.RecordTypeId,
                          //  Indicator_Catalogue__r.RecordType.Name,
                            Indicator_Catalogue__r.Standard_Custom__c,
                            Indicator_Catalogue__r.Definition__c,
                            Indicator_Catalogue__r.Outcome_Area__c
                    FROM sfims__Report_Template_Indicator__c
                    WHERE Report_Template__c = :templateId
                    ORDER BY Id
            ];
            if (indicators.size() > 0) {
                List<Indicator_Catalogue__c> results = new List<Indicator_Catalogue__c>();
                for (sfims__Report_Template_Indicator__c r : indicators) {
                    results.add(new Indicator_Catalogue__c(
                            Id = r.Indicator_Catalogue__r.Id,
                            Indicator_Name__c = r.Indicator_Catalogue__r.Indicator_Name__c,
                            Indicator_Type__c = r.Indicator_Catalogue__r.Indicator_Type__c,
                            RecordTypeId = r.Indicator_Catalogue__r.RecordTypeId,
                        //    RecordType.Name = r.Indicator_Catalogue__r.RecordType.Name,
                            Standard_Custom__c = r.Indicator_Catalogue__r.Standard_Custom__c,
                            Definition__c = r.Indicator_Catalogue__r.Definition__c,
                            Outcome_Area__c = r.Indicator_Catalogue__r.Outcome_Area__c
                    ));
                }
                 indicatorCatalogsData.allIndicators = results;
            }
            */

            indicatorCatalogsData.allRecordTypes = ReportTemplateController.getAllRecordTypes();
            response = JSON.serialize(indicatorCatalogsData);
        } catch (Exception err) {
            throw new CommonException(err.getMessage());
        }
        return response;
    }
}