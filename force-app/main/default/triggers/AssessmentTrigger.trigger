trigger AssessmentTrigger on Assessment__c (after delete, after insert, after update, before delete, before insert, before update) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        generateAssessmentName();
    }
    
    if (Trigger.isAfter && Trigger.isInsert) {
        populateStageAssessmentFields(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        populateStageAssessmentFields(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        populateStageAssessmentFields(Trigger.old);
    }
    
    public void generateAssessmentName(){
        Set<Id> stageIds = new Set<Id>();
        for (Assessment__c a : Trigger.new) {
            if (a.Stage_Assessment_Lookup__c != null) {
                stageIds.add(a.Stage_Assessment_Lookup__c);
            }
        }
        if (stageIds.size() > 0) {
            Map<Id, Stage_Assessment__c> stages = new Map<Id, Stage_Assessment__c> ([SELECT Name FROM Stage_Assessment__c WHERE Id IN :stageIds]);
            if (stages.size() > 0) {
                for (Assessment__c a : Trigger.new) {
                    if (stages.containsKey(a.Stage_Assessment_Lookup__c)) {
                        a.Name = stages.get(a.Stage_Assessment_Lookup__c).Name;
                    }
                }
            }
        }
    }

    public void populateStageAssessmentFields(List<Assessment__c> assessments){
        Set<Id> stageAssessmentIds = new Set<Id>();
        for (Assessment__c assessment : assessments) {
            if (assessment.Stage_Assessment_Lookup__c != null) {
                stageAssessmentIds.add(assessment.Stage_Assessment_Lookup__c);
            }
        }
        List<Stage_Assessment__c> stageAssessmentsToUpdate = new List<Stage_Assessment__c>();
        if (!stageAssessmentIds.isEmpty()) {
            for (Stage_Assessment__c stageAssessment : [SELECT Number_of_Assessments__c, Number_of_Assessments_Accepted__c, 
                Number_of_Assessments_Rejected__c, (SELECT Outcome__c FROM Assessments1__r) FROM Stage_Assessment__c 
                WHERE Id IN :stageAssessmentIds]) 
            {
                Integer numberOfAssessmentsAccepted = 0;
                Integer numberOfAssessmentsRejected = 0;
                for (Assessment__c assessment : stageAssessment.Assessments1__r) {
                    switch on assessment.Outcome__c {
                        when 'Accepted' {
                            numberOfAssessmentsAccepted++;
                        }
                        when 'Rejected' {
                            numberOfAssessmentsRejected++;
                        }
                    }
                }
                
                if (stageAssessment.Number_of_Assessments__c != stageAssessment.Assessments1__r.size()
                    || stageAssessment.Number_of_Assessments_Accepted__c != numberOfAssessmentsAccepted
                    || stageAssessment.Number_of_Assessments_Rejected__c != numberOfAssessmentsRejected)
                {
                    stageAssessment.Number_of_Assessments__c = stageAssessment.Assessments1__r.size();
                    stageAssessment.Number_of_Assessments_Accepted__c = numberOfAssessmentsAccepted;
                    stageAssessment.Number_of_Assessments_Rejected__c = numberOfAssessmentsRejected;
                    stageAssessmentsToUpdate.add(stageAssessment);
                }
            } 
        }

        if (!stageAssessmentsToUpdate.isEmpty()) update stageAssessmentsToUpdate;
    }
}