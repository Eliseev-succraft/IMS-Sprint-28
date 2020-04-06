/** Action list functionality * @author Alexey Eliseev * @date 9/17/19 **/
trigger TaskApprovalTrigger on Task_Approval__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isUpdate) {
            List<Id> approvedIds = new List<Id>();
            List<Id> rejectedIds = new List<Id>();
            List<Id> recalledIds = new List<Id>();
            for (Id taskApprovalId : Trigger.newMap.keySet()) {
                // check change status
                if (Trigger.newMap.get(taskApprovalId).Status__c != Trigger.oldMap.get(taskApprovalId).Status__c) {
                    // if new status - Approved or Rejected
                    switch on Trigger.newMap.get(taskApprovalId).Status__c {
                        when 'Approved' {
                            approvedIds.add(Trigger.newMap.get(taskApprovalId).Task_Id__c);
                        }
                        when 'Rejected' {
                            rejectedIds.add(Trigger.newMap.get(taskApprovalId).Task_Id__c);
                        }
                        when 'Recalled' {
                            recalledIds.add(Trigger.newMap.get(taskApprovalId).Task_Id__c);
                        }
                        when else {
                        }
                    }
                }
            }
            if (approvedIds.size() > 0 || rejectedIds.size() > 0 || recalledIds.size() > 0) {
                List<Task> tasksToUpdate = [SELECT Status FROM Task WHERE Id IN:approvedIds OR Id IN:rejectedIds OR Id IN:recalledIds];
                if (tasksToUpdate.size() > 0) {
                    for (Task t : tasksToUpdate) {
                        if (approvedIds.contains(t.Id)) {
                            t.Status = 'Done';
                            t.Read_Only__c = false;
                        } else {
                            if (rejectedIds.contains(t.Id)) {
                                t.Status = 'Rejected';
                                t.Read_Only__c = false;
                            } else {
                                if (recalledIds.contains(t.Id)) {
                                    t.Status = 'Open';
                                    t.Read_Only__c = false;
                                }
                            }
                        }
                    }
                    update tasksToUpdate;
                }
            }
        }
    }
}