trigger MilestoneHistoryTrigger on Milestone_History__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {

    if (Trigger.isAfter && Trigger.isInsert) {
        countDaysInMilestone(Trigger.newMap);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        countDaysInMilestone(Trigger.newMap);
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        countDaysInMilestone(Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isUndelete) {
        countDaysInMilestone(Trigger.newMap);
    }

    public void countDaysInMilestone(Map<Id, Milestone_History__c> newMilestoneHistoriesMap){
        // System.debug('bypass: ' + Utility.bypassMilestoneHistoryTrigger);
        if (Utility.bypassMilestoneHistoryTrigger) {
            Utility.bypassMilestoneHistoryTrigger = false;
            return;
        }
        
        Map<Id, List<Milestone_History__c>> applicationIdToHistories = new Map<Id, List<Milestone_History__c>>();
        for (Milestone_History__c temp : newMilestoneHistoriesMap.values()) {
            if (temp.Application__c != null) applicationIdToHistories.put(temp.Application__c, new List<Milestone_History__c>());
        }

        if (!applicationIdToHistories.isEmpty()) {
            Boolean failed = false;
            for (Milestone_History__c temp : [SELECT Milestone_Date__c, Days_in_Milestone__c, Sequence__c, 
                Milestone__c, Application__c, Contract__c, Investment__c FROM Milestone_History__c 
                WHERE Application__c IN :applicationIdToHistories.keySet() ORDER BY Sequence__c ASC]) 
            {
                applicationIdToHistories.get(temp.Application__c).add(temp);
            }

            // when moving to the previous stage
            Map<Id, Milestone_History__c> milestoneHistoriesToDelete = new Map<Id, Milestone_History__c>();
            // if (Trigger.isInsert) {
            //     for (Milestone_History__c temp : newMilestoneHistoriesMap.values()) {
            //         if (temp.Application__c != null) {
            //             List<Milestone_History__c> milestoneHistories = applicationIdToHistories.get(temp.Application__c);
            //             if (!milestoneHistories.isEmpty()) {
            //                 Milestone_History__c lastMilestoneHistory = milestoneHistories[milestoneHistories.size() - 1];
            //                 if (temp.Sequence__c < lastMilestoneHistory.Sequence__c) {
            //                     if (temp.Application__c == lastMilestoneHistory.Application__c
            //                         && temp.Contract__c == lastMilestoneHistory.Contract__c
            //                         && temp.Investment__c == lastMilestoneHistory.Investment__c) 
            //                     {
            //                         for (Milestone_History__c mh : milestoneHistories) {
            //                             if (mh.Id != temp.Id && mh.Sequence__c >= temp.Sequence__c) milestoneHistoriesToDelete.put(mh.Id, mh);
            //                         }
            //                     } else {
            //                         String objectName;
            //                         if (lastMilestoneHistory.Contract__c != null) objectName = 'Contract';
            //                         if (lastMilestoneHistory.Investment__c != null) objectName = 'Investment';
            //                         temp.addError('This stage update interferes with a milestone on a related object: ' + objectName + 
            //                             ' - ' + lastMilestoneHistory.Milestone__c + ' - ' + lastMilestoneHistory.Milestone_Date__c.format() + 
            //                             '. Please undo the milestone on the related object before you can apply this stage update.');
            //                         if (!failed) failed = true;  
            //                     }
            //                 }
            //             }
            //         }
            //     }
            // }

            List<Milestone_History__c> milestoneHistoriesToUpdate = new List<Milestone_History__c>();
            for (Id key : applicationIdToHistories.keySet()) {
                List<Milestone_History__c> milestoneHistories = applicationIdToHistories.get(key);
                if (!milestoneHistoriesToDelete.isEmpty()) {
                    List<Milestone_History__c> milestoneHistoriesAfterDelete = new List<Milestone_History__c>();
                    for (Integer i = 0; i < milestoneHistories.size(); i++) {
                        Milestone_History__c milestoneHistory = milestoneHistories[i];
                        if (!milestoneHistoriesToDelete.containsKey(milestoneHistory.Id)) milestoneHistoriesAfterDelete.add(milestoneHistory);
                    }
                    milestoneHistories = milestoneHistoriesAfterDelete;
                }

                for (Integer i = 0; i < milestoneHistories.size(); i++) {
                    Milestone_History__c milestoneHistory = milestoneHistories[i];
                    // System.debug(milestoneHistory);
                    // System.debug(milestoneHistory.Sequence__c);

                    // if (i - 1 >= 0) {
                    //     Milestone_History__c previousMilestoneHistory = milestoneHistories[i-1];
                    //     if (milestoneHistory.Milestone_Date__c < previousMilestoneHistory.Milestone_Date__c) {
                    //         if (newMilestoneHistoriesMap.containsKey(milestoneHistory.Id)) {
                    //             failed = true;
                    //             newMilestoneHistoriesMap.get(milestoneHistory.Id).Milestone_Date__c.addError(
                    //                 'The Milestone Date must not be earlier than the Milestone Date of the previous Milestone History (' +
                    //                 previousMilestoneHistory.Milestone_Date__c.format() + ').');
                    //         }
                    //     }
                    // }

                    if (i + 1 < milestoneHistories.size()) {
                        Milestone_History__c nextMilestoneHistory = milestoneHistories[i+1];
                        // if (milestoneHistory.Milestone_Date__c > nextMilestoneHistory.Milestone_Date__c) {
                        //     if (newMilestoneHistoriesMap.containsKey(milestoneHistory.Id)) {
                        //         newMilestoneHistoriesMap.get(milestoneHistory.Id).Milestone_Date__c.addError(
                        //             'The Milestone Date must not be later than the Milestone Date of the next Milestone History (' +
                        //             nextMilestoneHistory.Milestone_Date__c.format() + ').');
                        //         if (!failed) failed = true; 
                        //         break;
                        //     }
                        // }
                        // System.debug('process');
                        if (milestoneHistory.Days_in_Milestone__c != milestoneHistory.Milestone_Date__c.daysBetween(nextMilestoneHistory.Milestone_Date__c)) {
                            milestoneHistory.Days_in_Milestone__c = milestoneHistory.Milestone_Date__c.daysBetween(nextMilestoneHistory.Milestone_Date__c);
                            milestoneHistoriesToUpdate.add(milestoneHistory);
                        }
                    } else if (i + 1 == milestoneHistories.size()) {
                        // if (failed) break;
                        // System.debug('process');
                        if (milestoneHistory.Days_in_Milestone__c != null) {
                            milestoneHistory.Days_in_Milestone__c = null;
                            milestoneHistoriesToUpdate.add(milestoneHistory);
                        }
                    }
                }
            }

            if (!failed) {
                Utility.bypassMilestoneHistoryTrigger = true;
                if (!milestoneHistoriesToDelete.isEmpty()) delete milestoneHistoriesToDelete.values();
                if (!milestoneHistoriesToUpdate.isEmpty()) update milestoneHistoriesToUpdate;
            }
        }
    }

}