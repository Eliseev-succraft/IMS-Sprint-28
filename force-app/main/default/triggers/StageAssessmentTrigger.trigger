trigger StageAssessmentTrigger on Stage_Assessment__c (after delete, after insert, after update, before delete, before insert, before update) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        generateStageAssessmentName();
    }
    
    public void generateStageAssessmentName() {                   
        Set<Id> appIds = new Set<Id>();
        for (Stage_Assessment__c s : Trigger.new) {
            if (s.Stage__c != null && s.Application__c != null) {
                appIds.add(s.Application__c);
            }
        }
        if (appIds.size() > 0) {
            Map<Id, Application__c> apps = new Map<Id, Application__c> ([SELECT Name FROM Application__c WHERE Id IN :appIds]);
            if (apps.size() > 0) {
                for (Stage_Assessment__c s : Trigger.new) {
                    if (apps.containsKey(s.Application__c)) {
                        s.Name = (s.Stage__c + (s.Assessment_Stage__c != null ? '-' + s.Assessment_Stage__c : '') + '-' + apps.get(s.Application__c).Name).mid(0, 80);
                    }
                }
            }
        }
    } 
}