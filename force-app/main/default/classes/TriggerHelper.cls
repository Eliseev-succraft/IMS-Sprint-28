public with sharing class TriggerHelper {
    public class CustomException extends Exception {
    }
    /** Auto-assigned tasks functionality * @author Alexey Eliseev * @date 8/28/19
    *   for use
    *   if (Trigger.isAfter) {
    *       if (Trigger.isInsert || Trigger.isUpdate) {
    *           TriggerHelper.createCustomTask(Trigger.newMap, Trigger.oldMap, Trigger.isUpdate);
    *       }
    *   }
    * **/
    public static void createCustomTask(Map<Id, SObject> TriggerNewMap, Map<Id, SObject> TriggerOldMap, Boolean TriggerIsUpdate) {
        // list of new tasks for insert after
        Map<String, Task> tasks = new Map<String, Task>();
        String objectName = String.valueOf(TriggerNewMap.getSObjectType());
        // get record types
        Id customRecordTypeId;
        Map<String, RecordTypeInfo> recordTypes = Schema.SObjectType.Task.getRecordTypeInfosByName();
        if (recordTypes.containsKey('Custom')) {
            customRecordTypeId = recordTypes.get('Custom').getRecordTypeId();
        } else {
            throw new CustomException(System.Label.sfims.error_message_36);
        }
        Id standardRecordTypeId;
        if (recordTypes.containsKey('Standard')) {
            standardRecordTypeId = recordTypes.get('Standard').getRecordTypeId();
        } else {
            throw new CustomException(System.Label.sfims.error_message_37);
        }
        // get all templates and template items for the current object
        List<Task_List_Template__c> templatesCurrObj = [
                SELECT Object_Status_Field__c, Trigger_Status__c, (
                        SELECT Subject__c, Assignee_Type__c, Assignee_User__c, Assignee_Field__c, Description__c, Priority__c, Depends_On__c, Flow_Name__c, Task_Type__c
                        FROM Task_List_Template_Items__r
                )
                FROM Task_List_Template__c
                WHERE Object_Name__c = :objectName
        ];

        Map<String, String> relatedFields = new Map<String, String>();
        if (templatesCurrObj.size() > 0) {
            // get related fields
            for (Task_List_Template__c taskListTemplate : templatesCurrObj) {
                String objectField = taskListTemplate.Object_Status_Field__c;
                if (String.isNotBlank(objectField)) {
                    // check status field
                    for (Id recordId : TriggerNewMap.keySet()) {
                        Boolean isTrue = true;
                        if (TriggerIsUpdate) {
                            if (TriggerNewMap.get(recordId).get(objectField) == TriggerOldMap.get(recordId).get(objectField)) {
                                isTrue = false;
                            }
                        }
                        // add related field to list
                        if (isTrue && TriggerNewMap.get(recordId).get(objectField) == taskListTemplate.Trigger_Status__c) {
                            for (Task_List_Template_Item__c taskListTemplateItem : taskListTemplate.Task_List_Template_Items__r) {
                                if (taskListTemplateItem.Assignee_Type__c == 'Related Field') {
                                    if (taskListTemplateItem.Assignee_Field__c != null) {
                                        String key = (String) taskListTemplate.Id + (String) taskListTemplateItem.Id + (String) recordId;
                                        relatedFields.put(key, taskListTemplateItem.Assignee_Field__c);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // get all tasks for the current object
            for (Task_List_Template__c taskListTemplate : templatesCurrObj) {
                String objectField = taskListTemplate.Object_Status_Field__c;
                if (String.isNotBlank(objectField)) {
                    for (Id recordId : TriggerNewMap.keySet()) {
                        // check stage change
                        Boolean isTrue = true;
                        if (TriggerIsUpdate) {
                            if (TriggerNewMap.get(recordId).get(objectField) == TriggerOldMap.get(recordId).get(objectField)) {
                                isTrue = false;
                            }
                        }
                        if (isTrue && TriggerNewMap.get(recordId).get(objectField) == taskListTemplate.Trigger_Status__c) {
                            // if the status is valid - create tasks
                            for (Task_List_Template_Item__c taskListTemplateItem : taskListTemplate.Task_List_Template_Items__r) {
                                Id ownerId;
                                switch on taskListTemplateItem.Assignee_Type__c {
                                    when 'Record Owner' {
                                        if (TriggerIsUpdate) {
                                            ownerId = (Id) TriggerNewMap.get(recordId).get('OwnerId');
                                        } else {
                                            ownerId = UserInfo.getUserId();
                                        }
                                    }
                                    when 'User' {
                                        ownerId = taskListTemplateItem.Assignee_User__c;
                                    }
                                    when 'Related Field' {
                                        String key = (String) taskListTemplate.Id + (String) taskListTemplateItem.Id + (String) recordId;
                                        if (relatedFields.containsKey(key) && TriggerNewMap.get(recordId).get(relatedFields.get(key)) != null) {
                                            ownerId = (Id) TriggerNewMap.get(recordId).get(relatedFields.get(key));
                                        } else {
                                            throw new CustomException(System.Label.sfims.error_message_38);
                                        }
                                    }
                                    when else {
                                        ownerId = UserInfo.getUserId();
                                    }
                                }
                                tasks.put(recordId + '_' + taskListTemplateItem.Id, new Task(
                                        ActivityDate = Date.today(),
                                        Subject = taskListTemplateItem.Subject__c,
                                        OwnerId = ownerId,
                                        Priority = taskListTemplateItem.Priority__c,
                                        Status = (taskListTemplateItem.Depends_On__c != null) ? 'Pending' : 'Open',
                                        WhatId = recordId,
                                        Read_Only__c = true,
                                        RecordTypeId = (taskListTemplateItem.Task_Type__c == 'Custom') ? customRecordTypeId : standardRecordTypeId,
                                        Description = taskListTemplateItem.Description__c,
                                        Task_List_Template_Item__c = taskListTemplateItem.Id,
                                        Depends_On__c = (taskListTemplateItem.Depends_On__c != null) ? taskListTemplateItem.Depends_On__c : null
                                ));
                            }
                        }
                    }
                }
            }
        }
        // create tasks
        if (tasks.size() > 0) {
            List<Task> insertList = new List<Task>();
            List<Task> notInsertList = new List<Task>();
            Map<String, Id> junctions = new Map<String, Id>();
            // find the last elements in a queue, without dependencies
            for (String key : tasks.keySet()) {
                Task taskItem = tasks.get(key);
                if (taskItem.Depends_On__c == null) {
                    insertList.add(taskItem);
                } else {
                    notInsertList.add(taskItem);
                }
            }
            if (insertList.size() > 0) {
                insert insertList;
                // remember tasks Ids
                for (Task taskItem : insertList) {
                    junctions.put(taskItem.WhatId + '_' + taskItem.Task_List_Template_Item__c, taskItem.Id);
                }
                while (notInsertList.size() > 0) {
                    insertList.clear();
                    Integer size = notInsertList.size();
                    List<Task> tmpNotInsertList = new List<Task>();
                    for (Integer i = 0; i < size; i++) {
                        if (notInsertList[i].WhatId != null && notInsertList[i].Depends_On__c != null) {
                            if (junctions.containsKey(notInsertList[i].WhatId + '_' + notInsertList[i].Depends_On__c)) {
                                notInsertList[i].Depends_On__c = junctions.get(notInsertList[i].WhatId + '_' + notInsertList[i].Depends_On__c);
                                insertList.add(notInsertList[i]);

                            } else {
                                tmpNotInsertList.add(notInsertList[i]);
                            }
                        } else {
                            tmpNotInsertList.add(notInsertList[i]);
                        }
                    }
                    notInsertList = new List<Task>(tmpNotInsertList);
                    if (insertList.size() > 0) {
                        insert insertList;
                        for (Task taskItem : insertList) {
                            junctions.put(taskItem.WhatId + '_' + taskItem.Task_List_Template_Item__c, taskItem.Id);
                        }
                    } else {
                        if (notInsertList.size() > 0) {
                            insert notInsertList;
                            notInsertList.clear();
                        }
                    }
                }
            } else {
                if (notInsertList.size() > 0) {
                    insert notInsertList;
                }
            }
        }
    }

    /** END Auto-assigned tasks functionality **/
    public static List<String> getObjectFieldList(String objectName) {
        List<String> response = new List<String>();
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Schema.SObjectType cType = schemaMap.get(objectName);
        if (cType != null) {
            Map<String, Schema.SObjectField> schemaMapField = cType.getDescribe().fields.getMap();
            for (String fieldName : schemaMapField.keySet()) {
                response.add(schemaMapField.get(fieldName).getDescribe().getName());
            }
        }
        return response;
    }

    public static String runRecalculateLoanFromScratch(List<Investment__c> loansToUpdate) {
        if (!loansToUpdate.isEmpty()) {
            try {
                DMLManager.updateAsSystem(loansToUpdate);
            } catch(System.DmlException e) {
                System.debug(e.getDmlMessage(0));
                return System.Label.sfims.part_of_error_message_8 + ': ' + e.getDmlMessage(0);
            }
        
            List<String> standardLoanIds = new List<String>();
            List<String> openEndedLoanIds = new List<String>();
            for (Investment__c theLoan : loansToUpdate) {
                if (theLoan.Open_Ended_Loan__c) openEndedLoanIds.add(theLoan.Id);
                else standardLoanIds.add(theLoan.Id);
            }

            if (!standardLoanIds.isEmpty()) {
                if (TriggerHelper.checkAsyncApexJobs('RecalculateLoanFromScratchBatch').isEmpty()) {
                    Database.executeBatch(new RecalculateLoanFromScratchBatch(), 1);
                }
                
            }

            if (!openEndedLoanIds.isEmpty()) {
                if (TriggerHelper.checkAsyncApexJobs('RecalculateOpenEndedLoan').isEmpty()) {
                    Database.executeBatch(new RecalculateOpenEndedLoan(), 1);
                }
            }    
        }

        return null;
    }

    public static List<AsyncApexJob> checkAsyncApexJobs(String apexClassName) {
        return [
            SELECT Id
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex' AND ApexClass.Name = :apexClassName
                AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
        ];
    }

    public static Map<String, List<SObject>> processInterestRates(Investment__c theLoan, Date startDate, List<Interest_Rate__c> interestRates) {
        // System.debug('TriggerHelper.processInterestRates');
        Map<String, List<SObject>> returnMap = new Map<String, List<SObject>>();
        List<Investment__c> loansToUpdate = new List<Investment__c>();
        List<Loan_Event__c> newLoanEvents = new List<Loan_Event__c>();
        Set<Date> dateList = new Set<Date>();
        
        Date endDate;
        if (theLoan.Expected_End_Date__c != null && theLoan.Expected_End_Date__c < System.today()) {
            endDate = theLoan.Expected_End_Date__c;
        } else {
            endDate = System.today();
        }
        
        Boolean beforeStartDate = false;
        // define a loan event date for each rate
        for (Interest_Rate__c rate : interestRates) {
            // System.debug(rate);
            if (rate.Date__c < startDate) beforeStartDate = true;
            else if (rate.Date__c >= startDate && rate.Date__c < endDate) {
                if (theLoan.Loan_Product__r.Interest_Rate_Review_Frequency__c == 'Daily') {
                    dateList.add(rate.Date__c.addDays(1));
                } else {
                    Date eventDate;
                    Integer counter = 0;
                    do {
                        switch on theLoan.Loan_Product__r.Interest_Rate_Review_Frequency__c {
                            when 'Monthly' {
                                eventDate = startDate.addMonths(1 + counter);
                            }
                            when 'Quarterly' {
                                eventDate = startDate.addMonths(3 * (1 + counter));
                            }
                            when 'Yearly' {
                                eventDate = startDate.addYears(1 + counter);
                            }
                        }
                        counter++;
                    } while (rate.Date__c >= eventDate);
                    // System.debug(eventDate);
                    if (eventDate <= System.today()) dateList.add(eventDate); 
                }
            } 
        }
        // System.debug(dateList.size());
        // System.debug(dateList);
        if (!dateList.isEmpty()) {
            // this means that there are some new interest rates in active loan period
            // the loan should be recalculated 
            theLoan.Recalculation_Status__c = 'Pending Recalculation';
            loansToUpdate.add(theLoan);

            // check if there are loan events on the dates on which we need to create new loan events
            // remove these dates from the list
            List<Date> loanEventDates = new List<Date>();
            for (Loan_Event__c le : theLoan.Loan_Events__r) {
                loanEventDates.add(le.Event_Date__c);
            }
            // System.debug(loanEventDates.size());
            // System.debug(loanEventDates[0]);
            dateList.removeAll(loanEventDates);
            // System.debug(dateList.size());
            // create a new loan event for each date of the list
            for (Date newLoanEventDate : dateList) {
                newLoanEvents.add(new Loan_Event__c(
                    Event_Date__c = newLoanEventDate,
                    Investment__c = theLoan.Id,
                    Loan_Event_Type__c = 'Interest Rate Change',
                    Loan_Product__c = theLoan.Loan_Product__c
                ));
            }
        } else {
            if (beforeStartDate) {
                theLoan.Recalculation_Status__c = 'Pending Recalculation';
                loansToUpdate.add(theLoan);
            }
        }
        if (!loansToUpdate.isEmpty()) returnMap.put('loans', loansToUpdate);
        if (!newLoanEvents.isEmpty()) returnMap.put('loanEvents', newLoanEvents);
        return returnMap;
    }
}