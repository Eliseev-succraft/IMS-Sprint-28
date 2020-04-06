trigger ApplicationTrigger on Application__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {

    // Auto-assigned tasks
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            TriggerHelper.createCustomTask(Trigger.newMap, Trigger.oldMap, Trigger.isUpdate);
        }
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        createMilestoneHistory(Trigger.newMap, null);
        generatePDF(Trigger.new, null);
        createAssessments(Trigger.newMap, Trigger.oldMap, Trigger.isUpdate);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        createMilestoneHistory(Trigger.newMap, Trigger.oldMap);
        generatePDF(Trigger.new, Trigger.oldMap);
        createAssessments(Trigger.newMap, Trigger.oldMap, Trigger.isUpdate);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        deleteChildRecords(Trigger.oldMap);
    }

    /** Application Assessment functionality * @author Alexey Eliseev * @date 9/10/19 **/
    public static void createAssessments(Map<Id, Application__c> TriggerNewMap, Map<Id, Application__c> TriggerOldMap, Boolean TriggerIsUpdate) {
        // get existing Stage Assessment for current Applications, if contains Assessments - not create new
        Map<Id, Id> existAssessmentsMap = new Map<Id, Id>();
        Map<String, Stage_Assessment__c> existStageAssessmentsMap = new Map<String, Stage_Assessment__c>();
        for (Stage_Assessment__c s : [SELECT Stage__c, Assessment_Stage__c, Application__c, (SELECT Id FROM Assessments1__r) FROM Stage_Assessment__c WHERE Application__c IN:Trigger.newMap.keySet()]) {
            String key = s.Application__c + s.Stage__c + s.Assessment_Stage__c;
            existStageAssessmentsMap.put(key, s);
            if (s.Assessments1__r.size() > 0) {
                existAssessmentsMap.put(s.Id, s.Id);
            }
        }
        // get all stages and funds for the list of Application__c, where stage changed
        Set<String> allStages = new Set<String>();
        Set<String> AllAssessmentStage = new Set<String>{
                null
        };
        Set<Id> allFunds = new Set<Id>();
        for (Id appId : TriggerNewMap.keySet()) {
            // check stage change
            Boolean isTrue = true;
            if (TriggerIsUpdate) {
                if ((TriggerNewMap.get(appId).Stage__c == TriggerOldMap.get(appId).Stage__c) && (TriggerNewMap.get(appId).Assessment_Stage__c == TriggerOldMap.get(appId).Assessment_Stage__c)) {
                    isTrue = false;
                }
            }
            if (isTrue) {
                allStages.add(TriggerNewMap.get(appId).Stage__c);
                AllAssessmentStage.add(TriggerNewMap.get(appId).Assessment_Stage__c);
                allFunds.add(TriggerNewMap.get(appId).Fund__c);
            }
        }
        // get all Assessors for each for fund
        Map<Id, List<Fund_Assessor__c>> funds = new Map<Id, List<Fund_Assessor__c>>();
        for (Fund__c fund : [SELECT (SELECT Assessor_External__c, Assessor_Internal__c FROM Fund_Assessors__r) FROM Fund__c WHERE Id IN :allFunds]) {
            funds.put(fund.Id, fund.Fund_Assessors__r);
        }
        // get all Assessment Stage Definition for all funds and stages and make a map
        if (allStages.size() > 0 || AllAssessmentStage.size() > 0 || allFunds.size() > 0) {
            List<String> whereList = new List<String>();
            if (allStages.size() > 0) {
                whereList.add('Application_Stage__c IN :allStages');
            }
            if (AllAssessmentStage.size() > 0) {
                whereList.add('Application_Assessment_Stage__c IN :AllAssessmentStage');
            }
            if (allFunds.size() > 0) {
                whereList.add('Fund__c IN :allFunds');
            }
            Map<String, Assessment_Stage_Definition__c> stageDefinitions = new Map<String, Assessment_Stage_Definition__c>();
            if (whereList.size() > 0) {
                // preliminary selection
                for (Assessment_Stage_Definition__c stageDefinition : Database.query('SELECT Application_Stage__c, Application_Assessment_Stage__c, Assessors__c, Number_of_Assessments__c, Fund__c, (SELECT Type__c FROM Assessment_Criteria_Definitions__r) FROM Assessment_Stage_Definition__c WHERE ' + String.join(whereList, ' AND '))) {
                    if (String.isNotBlank(stageDefinition.Application_Stage__c)) {
                        stageDefinitions.put(stageDefinition.Application_Stage__c + stageDefinition.Application_Assessment_Stage__c + stageDefinition.Fund__c, stageDefinition);
                    }
                }
            }
            if (stageDefinitions.size() > 0) {
                Map<Id, Assessment_Stage_Definition__c> appIdsMap = new Map<Id, Assessment_Stage_Definition__c>();
                List<Stage_Assessment__c> newStageAssessments = new List<Stage_Assessment__c>();
                List<Id> existStageAssessments = new List<Id>();
                for (Id appId : TriggerNewMap.keySet()) {
                    // check stage change
                    Boolean isTrue = true;
                    if (TriggerIsUpdate) {
                        if ((TriggerNewMap.get(appId).Stage__c == TriggerOldMap.get(appId).Stage__c) && (TriggerNewMap.get(appId).Assessment_Stage__c == TriggerOldMap.get(appId).Assessment_Stage__c)) {
                            isTrue = false;
                        }
                    }
                    if (isTrue) {
                        Application__c currentApp = TriggerNewMap.get(appId);
                        if (String.isNotBlank(currentApp.Stage__c)) {
                            String key = currentApp.Stage__c + currentApp.Assessment_Stage__c + currentApp.Fund__c;
                            Boolean isStageDefinition = false;
                            if (stageDefinitions.containsKey(key)) {
                                appIdsMap.put(currentApp.Id, stageDefinitions.get(key));
                                isStageDefinition = true;
                            } else {
                                key = currentApp.Stage__c + 'null' + currentApp.Fund__c;
                                if (stageDefinitions.containsKey(key)) {
                                    appIdsMap.put(currentApp.Id, stageDefinitions.get(key));
                                    isStageDefinition = true;
                                }
                            }
                            if (isStageDefinition) {
                                String defKey = currentApp.Id + currentApp.Stage__c + currentApp.Assessment_Stage__c;
                                if (!existStageAssessmentsMap.containsKey(defKey)) {
                                    newStageAssessments.add(new Stage_Assessment__c(
                                            Application__c = currentApp.Id,
                                            Stage__c = currentApp.Stage__c,
                                            Assessment_Stage__c = currentApp.Assessment_Stage__c
                                    ));
                                } else {
                                    existStageAssessments.add(existStageAssessmentsMap.get(defKey).Id);
                                }
                            }
                        }
                    }
                }
                if (newStageAssessments.size() > 0 || existStageAssessments.size() > 0) {
                    if (newStageAssessments.size() > 0) {
                        insert newStageAssessments;
                    }
                    if (existStageAssessments.size() > 0) {
                        newStageAssessments.addAll([SELECT Application__c, Stage__c, Assessment_Stage__c FROM Stage_Assessment__c WHERE Id IN:existStageAssessments]);
                    }
                    Map<Id, Stage_Assessment__c> appIdsStageMap = new Map<Id, Stage_Assessment__c>(newStageAssessments);
                    List<Assessment__c> newAssessments = new List<Assessment__c>();
                    for (Stage_Assessment__c stage : newStageAssessments) {
                        if (!existAssessmentsMap.containsKey(stage.Id)) {
                            if (stage.Application__c != null && stage.Stage__c != null) {
                                if (appIdsMap.containsKey(stage.Application__c)) {
                                    Assessment_Stage_Definition__c stageDefinition = appIdsMap.get(stage.Application__c);
                                    switch on stageDefinition.Assessors__c {
                                        when 'All fund assessors' {
                                            Id fund = TriggerNewMap.get(stage.Application__c).Fund__c;
                                            if (funds.containsKey(fund)) {
                                                for (Fund_Assessor__c assessor : funds.get(fund)) {
                                                    newAssessments.add(new Assessment__c(
                                                            Status__c = 'Pending',
                                                            Stage_Assessment_Lookup__c = stage.Id,
                                                            Assessor_Internal__c = assessor.Assessor_Internal__c,
                                                            Assessor__c = assessor.Assessor_External__c
                                                    ));
                                                }
                                            }
                                        }
                                        when 'Random fund assessor' {
                                            Id fund = TriggerNewMap.get(stage.Application__c).Fund__c;
                                            if (funds.containsKey(fund)) {
                                                List<Fund_Assessor__c> assessors = funds.get(fund);
                                                Integer size = assessors.size();
                                                if (size > 0 && stageDefinition.Number_of_Assessments__c != null) {
                                                    if (size <= stageDefinition.Number_of_Assessments__c) {
                                                        for (Integer i = 0; i < size; i++) {
                                                            Fund_Assessor__c assessor = assessors.get(i);
                                                            newAssessments.add(new Assessment__c(
                                                                    Status__c = 'Pending',
                                                                    Stage_Assessment_Lookup__c = stage.Id,
                                                                    Assessor_Internal__c = assessor.Assessor_Internal__c,
                                                                    Assessor__c = assessor.Assessor_External__c
                                                            ));
                                                        }
                                                    } else {
                                                        Set<Integer> unique = new Set<Integer>();
                                                        while (unique.size() < stageDefinition.Number_of_Assessments__c) {
                                                            unique.add(Math.round(Math.random() * (size - 1)));
                                                        }
                                                        for (Integer i : unique) {
                                                            Fund_Assessor__c assessor = assessors.get(i);
                                                            newAssessments.add(new Assessment__c(
                                                                    Status__c = 'Pending',
                                                                    Stage_Assessment_Lookup__c = stage.Id,
                                                                    Assessor_Internal__c = assessor.Assessor_Internal__c,
                                                                    Assessor__c = assessor.Assessor_External__c
                                                            ));
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        when 'Manual selection' {
                                            for (Integer i = 0; i < stageDefinition.Number_of_Assessments__c; i++) {
                                                newAssessments.add(new Assessment__c(
                                                        Status__c = 'Pending',
                                                        Stage_Assessment_Lookup__c = stage.Id
                                                ));
                                            }
                                        }
                                        when else {
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if (newAssessments.size() > 0) {
                        insert newAssessments;
                        List<Assessment_Criteria__c> newAssessmentCriteria = new List<Assessment_Criteria__c>();
                        for (Assessment__c assessment : newAssessments) {
                            if (appIdsStageMap.containsKey(assessment.Stage_Assessment_Lookup__c)) {
                                Id currentAppId = appIdsStageMap.get(assessment.Stage_Assessment_Lookup__c).Application__c;
                                if (appIdsMap.containsKey(currentAppId)) {
                                    Assessment_Stage_Definition__c assessmentStageDefinition = appIdsMap.get(currentAppId);
                                    for (Assessment_Criteria_Definition__c criteria : assessmentStageDefinition.Assessment_Criteria_Definitions__r) {
                                        newAssessmentCriteria.add(new Assessment_Criteria__c(
                                                Assessment__c = assessment.Id,
                                                Type__c = criteria.Type__c,
                                                Assessment_Criteria_Definition__c = criteria.Id
                                        ));
                                    }
                                }
                            }
                        }
                        if (newAssessmentCriteria.size() > 0) {
                            insert newAssessmentCriteria;
                        }
                    }
                }
            }
        }
    }
    /** END Application Assessment functionality **/

    public void createMilestoneHistory(Map<Id, Application__c> newApplicationsMap, Map<Id, Application__c> oldApplicationsMap) {
        //-----Collect the Application Stages that have been changed and create new Milestone History records-----------
        Map<String, String> stageMap = new Map<String, String>();
        for (String key : newApplicationsMap.keySet()) {
            if (oldApplicationsMap == null || newApplicationsMap.get(key).Stage__c != oldApplicationsMap.get(key).Stage__c) {
                stageMap.put(key, newApplicationsMap.get(key).Stage__c);
            }
        }

        //-----Get the Milestone Configuration data and put it in the map using the Stage as a key---------------
        if (!stageMap.isEmpty()) {
            Map<String, Milestone_Configuration__c> milestoneConfigurationsMap = new Map<String, Milestone_Configuration__c>();
            for (Milestone_Configuration__c tempMilestoneConfiguration : [
                    SELECT Stage__c, Milestone_Name__c, Sequence__c
                    FROM Milestone_Configuration__c
                    WHERE Stage__c IN :stageMap.values() AND Object__c = 'Application'
            ]) {
                milestoneConfigurationsMap.put(tempMilestoneConfiguration.Stage__c, tempMilestoneConfiguration);
            }

            //-----Create a new Milestone History records---------------------------------------------
            List<Milestone_History__c> milestoneHistoryList = new List<Milestone_History__c>();
            for (String key : stageMap.keySet()) {
                if (milestoneConfigurationsMap.containsKey(stageMap.get(key))) {
                    milestoneHistoryList.add(new Milestone_History__c(
                            Milestone_Date__c = System.today(),
                            Milestone__c = milestoneConfigurationsMap.get(stageMap.get(key)).Milestone_Name__c,
                            Sequence__c = milestoneConfigurationsMap.get(stageMap.get(key)).Sequence__c,
                            Application__c = key
                    ));
                }
            }

            if (!milestoneHistoryList.isEmpty()) {
                try {
                    insert milestoneHistoryList;
                } catch(System.DmlException e) {
                    System.debug(e.getDmlMessage(0));
                    for (String key : stageMap.keySet()) {
                        newApplicationsMap.get(key).addError(System.Label.sfims.part_of_error_message_9 + ': ' + e.getDmlMessage(0));
                    }
                } 
            }
        }
    }

    public void generatePDF(List<Application__c> newApplications, Map<Id, Application__c> oldApplicationsMap) {
        List<Attachment> attachmentsToInsert = new List<Attachment>();
        Map<Id, Set<String>> applicationIdToAttachmentNames = new Map<Id, Set<String>>();
        if (oldApplicationsMap == null) {
            for (Application__c temp : newApplications) {
                if (temp.FormAssembly_EOI_content__c != null) {
                    attachmentsToInsert.add(ApplicationPDFGenerator.generateApplicationPDF(temp, temp.FormAssembly_EOI_Attachment_Name__c, temp.FormAssembly_EOI_content__c));
                }
                if (temp.FormAssembly_Full_Application_content__c != null) {
                    attachmentsToInsert.add(ApplicationPDFGenerator.generateApplicationPDF(temp, temp.FormAssembly_Application_Attach_Name__c, temp.FormAssembly_Full_Application_content__c));
                }
            }
        } else {
            for (Application__c temp : newApplications) {
                if (temp.FormAssembly_EOI_content__c != oldApplicationsMap.get(temp.Id).FormAssembly_EOI_content__c) {
                    attachmentsToInsert.add(ApplicationPDFGenerator.generateApplicationPDF(temp, temp.FormAssembly_EOI_Attachment_Name__c, temp.FormAssembly_EOI_content__c));
                    if (!applicationIdToAttachmentNames.containsKey(temp.Id)) applicationIdToAttachmentNames.put(temp.Id, new Set<String>());
                    applicationIdToAttachmentNames.get(temp.Id).add(temp.FormAssembly_EOI_Attachment_Name__c);
                }
                if (temp.FormAssembly_Full_Application_content__c != oldApplicationsMap.get(temp.Id).FormAssembly_Full_Application_content__c) {
                    attachmentsToInsert.add(ApplicationPDFGenerator.generateApplicationPDF(temp, temp.FormAssembly_Application_Attach_Name__c, temp.FormAssembly_Full_Application_content__c));
                    if (!applicationIdToAttachmentNames.containsKey(temp.Id)) applicationIdToAttachmentNames.put(temp.Id, new Set<String>());
                    applicationIdToAttachmentNames.get(temp.Id).add(temp.FormAssembly_Application_Attach_Name__c);
                }
            }
        }
        List<Attachment> attachmentsToDelete = new List<Attachment>();
        if (!applicationIdToAttachmentNames.isEmpty()) {
            List<Attachment> attachments = [SELECT Id, Name, ParentId FROM Attachment WHERE ParentId IN :applicationIdToAttachmentNames.keySet()];
            if (!attachments.isEmpty()) {
                for (Attachment temp : attachments) {
                    if (applicationIdToAttachmentNames.get(temp.ParentId).contains(temp.Name)) {
                        attachmentsToDelete.add(temp);
                    }
                }
            }
        }
        delete attachmentsToDelete;
        insert attachmentsToInsert;

    }

    public void deleteChildRecords(Map<Id, Application__c> oldApplicationsMap) {
        delete [SELECT Id FROM Progress_Report__c WHERE Application__c IN :oldApplicationsMap.keySet()];
    }

}