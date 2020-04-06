trigger ContractTrigger on Contract__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {

    if (Trigger.isAfter && Trigger.isInsert) {
        createMilestoneHistory(Trigger.newMap, null);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
       createMilestoneHistory(Trigger.newMap, Trigger.oldMap);
    }

    public void createMilestoneHistory(Map<Id, Contract__c> newContractsMap, Map<Id, Contract__c> oldContractsMap){
        //-----Collect the Contract Statuses that have been changed and create new Milestone History records------------
        Map<String, String> statusMap = new Map<String, String>();
        for (String key : newContractsMap.keySet()) {
            if (oldContractsMap == null || newContractsMap.get(key).Status__c != oldContractsMap.get(key).Status__c) {
                statusMap.put(key, newContractsMap.get(key).Status__c);
            }
        }
        
        //-----Get the Milestone Configuration data and put it in the map using the Stage as a key---------------
        if (!statusMap.isEmpty()) {
            Map<String, Milestone_Configuration__c> milestoneConfigurationsMap = new Map<String, Milestone_Configuration__c>();
            for (Milestone_Configuration__c tempMilestoneConfiguration : [
                SELECT Stage__c, Milestone_Name__c, Sequence__c
                FROM Milestone_Configuration__c
                WHERE Stage__c IN : statusMap.values() AND Object__c = 'Contract'
            ]) {
                milestoneConfigurationsMap.put(tempMilestoneConfiguration.Stage__c, tempMilestoneConfiguration);
            }
            
            //-----Create a new Milestone History records---------------------------------------------
            List<Milestone_History__c> milestoneHistoryList = new List<Milestone_History__c>();
            for (String key : statusMap.keySet()) {
                if (milestoneConfigurationsMap.containsKey(statusMap.get(key))) {
                    milestoneHistoryList.add(new Milestone_History__c(
                        Milestone_Date__c = System.today(),
                        Milestone__c = milestoneConfigurationsMap.get(statusMap.get(key)).Milestone_Name__c,
                        Sequence__c = milestoneConfigurationsMap.get(statusMap.get(key)).Sequence__c,
                        Application__c = newContractsMap.get(key).Application__c,
                        Contract__c = key
                    ));
                }
            }
            
            if (!milestoneHistoryList.isEmpty()) {
                try {
                    insert milestoneHistoryList;
                } catch(System.DmlException e) {
                    System.debug(e.getDmlMessage(0));
                    for (String key : statusMap.keySet()) {
                        newContractsMap.get(key).addError(System.Label.sfims.part_of_error_message_9 + ': ' + e.getDmlMessage(0));
                    }
                }
            } 
        }
    }
    
}