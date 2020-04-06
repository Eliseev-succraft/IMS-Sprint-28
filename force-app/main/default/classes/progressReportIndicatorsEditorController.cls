/*
 * @description         This is controller for component Progress Report Indicators Editor
 * @author              Alexey Eliseev
 * @component           progressReportIndicatorsEditor
 * @date                2/15/19
*/

public with sharing class progressReportIndicatorsEditorController {

    public class showException extends Exception {
    }

    public class progressReportIndicatorsEditorRowClass {
        public Id id;
        public String type;
        public String name;
        public List<Map<String, String>> cols;
    }

    @AuraEnabled
    public static String getProgressReportIndicators(Id progressReportId) {
        return JSON.serialize([
                SELECT Indicator_Catalogue__r.Indicator_Name__c,
                        Indicator_Catalogue__r.Indicator_Type__c,
                        Target_Value_Number__c, Target_Value_Currency__c, Target_Value_Text__c, Target_Value_Percentage__c, Target_Value_Text_Area_Long__c,
                        Actual_Value_Number__c, Actual_Value_Currency__c, Actual_Value_Text__c, Actual_Value_Percentage__c, Actual_Value_Text_Area_Long__c,
                        Variance_Value_Number__c, Variance_Value_Currency__c, Variance_Value_Text__c, Variance_Value_Percentage__c, Variance_Value_Text_Area_Long__c,
                        Comment__c
                FROM Progress_Report_Indicators__c
                WHERE Progress_Report__c = :progressReportId
                ORDER BY Sequence_Number__c, Id
        ]);
    }

    @AuraEnabled
    public static Boolean saveProgressReportIndicators(String progressReportIndicatorsJSON) {
        Boolean returnValue = false;

        if (String.isNotBlank(progressReportIndicatorsJSON)) {
            List<progressReportIndicatorsEditorRowClass> indicatorRows = (List<progressReportIndicatorsEditorRowClass>) JSON.deserialize(progressReportIndicatorsJSON, List<progressReportIndicatorsEditorRowClass>.class);
            List<Progress_Report_Indicators__c> updateListIndicators = new List<Progress_Report_Indicators__c>();

            Integer indicatorRowsSize = indicatorRows.size();
            if (indicatorRowsSize > 0) {
                for (Integer i = 0; i < indicatorRowsSize; i++) {
                    Progress_Report_Indicators__c updateItem = new Progress_Report_Indicators__c(Id = indicatorRows[i].id);

                    List<String> fieldValueMap = new List<String>();
                    Integer colSize = indicatorRows[i].cols.size();

                    List<String> ignor = new List<String> {
                            'sfims__Variance_Value_Currency__c',
                            'sfims__Variance_Value_Number__c',
                            'sfims__Variance_Value_Percentage__c'
                    };

                    if (colSize > 0) {
                        for (Map<String, String> j : indicatorRows[i].cols) {

                            if (ignor.indexOf(j.get('name')) != -1) {
                                continue;
                            }

                            if (j.get('name') == 'sfims__Comment__c') {
                                updateItem.put('Comment__c', j.get('value'));
                            } else {

                                switch on indicatorRows[i].type {
                                    when 'Number' {
                                        if (String.isBlank(j.get('value'))) {
                                            //continue;
                                            j.put('value', '0');
                                        }
                                        updateItem.put(j.get('name'), Decimal.valueOf(j.get('value')));
                                    }
                                    when 'Currency' {
                                        if (String.isBlank(j.get('value'))) {
                                            //continue;
                                            j.put('value', '0');
                                        }
                                        updateItem.put(j.get('name'), Decimal.valueOf(j.get('value')));
                                    }
                                    when 'Percentage'{
                                        if (String.isBlank(j.get('value'))) {
                                            //continue;
                                            j.put('value', '0');
                                        }
                                        updateItem.put(j.get('name'), Decimal.valueOf(j.get('value')));
                                    }
                                    when 'Text'{
                                        updateItem.put(j.get('name'), j.get('value'));
                                    }
                                    when 'Text Area (Long)'{
                                        updateItem.put(j.get('name'), j.get('value'));
                                    }
                                    when else {
                                        //updateItem.put(j.get('name'), j.get('value'));
                                    }
                                }
                            }
                        }

                        updateListIndicators.add(updateItem);
                        //system.debug(updateListIndicators);
                    }
                }
            }

            if (updateListIndicators.size() > 0) {
                try {
                    update updateListIndicators;
                    returnValue = true;
                } catch (Exception e) {
                    throw new showException(System.Label.sfims.error_message_6, e);
                }
            }
        }

        return returnValue;
    }
}