/**
* @description         Application Assessment functionality
* @author              Alexey Eliseev
* @date                9/10/19
**/

trigger AssessmentStageDefinitionTrigger on Assessment_Stage_Definition__c (before insert, before update) {
    // check uniqueness
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            // ignore current edit iDs
            Set<Id> ignoreIds = new Set<Id>();
            if (Trigger.isUpdate) {
                ignoreIds = Trigger.oldMap.keySet();
            }
            // get all Application Stages and Application Assessment Stages and Fund for the list of Assessment_Stage_Definition__c
            Set<String> allApplicationStages = new Set<String>();
            Set<String> allApplicationAssessmentStages = new Set<String>();
            Set<Id> allFunds = new Set<Id>();
            for (Assessment_Stage_Definition__c stage : Trigger.new) {
                allApplicationStages.add(stage.Application_Stage__c);
                allApplicationAssessmentStages.add(stage.Application_Assessment_Stage__c);
                allFunds.add(stage.Fund__c);
            }
            // get all Assessors for each for fund
            Map<Id, List<Fund_Assessor__c>> funds = new Map<Id, List<Fund_Assessor__c>>();
            for (Fund__c fund : [SELECT (SELECT Id FROM Fund_Assessors__r) FROM Fund__c WHERE Id IN :allFunds]) {
                funds.put(fund.Id, fund.Fund_Assessors__r);
            }
            // get all Assessment_Stage_Definition__c and add used keys
            List<String> whereList = new List<String>();
            if (allApplicationStages.size() > 0) {
                whereList.add('Application_Stage__c IN :allApplicationStages');
            }
            if (allApplicationAssessmentStages.size() > 0) {
                whereList.add('Application_Assessment_Stage__c IN :allApplicationAssessmentStages');
            }
            if (allFunds.size() > 0) {
                whereList.add('Fund__c IN :allFunds');
            }
            if (ignoreIds.size() > 0) {
                whereList.add('Id NOT IN :ignoreIds');
            }
            Set<String> keys = new Set<String>();
            if (whereList.size() > 0) {
                for (Assessment_Stage_Definition__c stage : Database.query('SELECT Application_Stage__c, Application_Assessment_Stage__c, Fund__c FROM Assessment_Stage_Definition__c WHERE ' + String.join(whereList, ' AND '))) {
                    if (String.isNotBlank(stage.Application_Stage__c)) {
                        String applicationAssessmentStage = String.isNotBlank(stage.Application_Assessment_Stage__c) ? stage.Application_Assessment_Stage__c : '';
                        String fund = stage.Fund__c != null ? String.valueOf(stage.Fund__c) : '';
                        keys.add(stage.Application_Stage__c + applicationAssessmentStage + fund);
                    }
                }
            }
            // check required field and unique keys
            for (Assessment_Stage_Definition__c stage : Trigger.new) {
                if (String.isNotBlank(stage.Application_Stage__c) && String.isNotBlank(stage.Assessors__c) && String.isNotBlank(stage.Fund__c)) {
                    String key = stage.Application_Stage__c;
                    if (String.isNotBlank(stage.Application_Assessment_Stage__c)) {
                        key += stage.Application_Assessment_Stage__c;
                    }
                    if (String.isNotBlank(stage.Fund__c)) {
                        key += stage.Fund__c;
                    }
                    if (keys.contains(key)) {
                        stage.addError(System.Label.sfims.error_message_40);
                    }
                    if (stage.Assessors__c == 'Random fund assessor' || stage.Assessors__c == 'Manual selection') {
                        if (stage.Number_of_Assessments__c != null) {
                            if (stage.Assessors__c == 'Random fund assessor') {
                                if (stage.Number_of_Assessments__c > funds.get(stage.Fund__c).size()) {
                                    stage.addError(System.Label.sfims.part_of_error_message_12 + ' ' + funds.get(stage.Fund__c).size() + ' (' + System.Label.sfims.part_of_error_message_12 + ').');
                                }
                            }
                        } else {
                            stage.addError(System.Label.sfims.error_message_41);
                        }
                    }
                } else {
                    stage.addError(System.Label.sfims.error_message_42);
                }
            }
        }
    }
}