trigger AssessmentCriteriaTrigger on Assessment_Criteria__c (before insert, before update) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        runValidations();
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        runValidations();
    }

    public void runValidations() {
        Map<Id, Assessment_Criteria_Definition__c> definitionIdToDefinition = new Map<Id, Assessment_Criteria_Definition__c>();
        Map<Id, List<Assessment_Criteria__c>> assessmentIdToAssessmentCriteria = new Map<Id, List<Assessment_Criteria__c>>();
        for (Assessment_Criteria__c criteria : Trigger.new) {
            if (criteria.Assessment_Criteria_Definition__c != null) {
                definitionIdToDefinition.put(criteria.Assessment_Criteria_Definition__c, null);
            }
            
            if (Trigger.isUpdate) {
                if (!assessmentIdToAssessmentCriteria.containsKey(criteria.Assessment__c))
                    assessmentIdToAssessmentCriteria.put(criteria.Assessment__c, new List<Assessment_Criteria__c>());
                assessmentIdToAssessmentCriteria.get(criteria.Assessment__c).add(criteria);
            }
        }

        if (Trigger.isUpdate) {
            for (Assessment__c assessment : [SELECT Status__c FROM Assessment__c WHERE Id IN :assessmentIdToAssessmentCriteria.keySet()]) {
                if (assessment.Status__c == 'Approved' || assessment.Status__c == 'Completed') {
                    for (Assessment_Criteria__c criteria : assessmentIdToAssessmentCriteria.get(assessment.Id)) {
                        criteria.addError(System.Label.sfims.error_message_39);
                    }
                }
            }
        }
        if (!definitionIdToDefinition.isEmpty()) {
            definitionIdToDefinition = new Map<Id, Assessment_Criteria_Definition__c> ([
                SELECT Name, Picklist_Values__c, Maximum_Rating__c, Minimum_Rating__c  
                FROM Assessment_Criteria_Definition__c 
                WHERE Id IN :definitionIdToDefinition.keySet()
            ]);
            if (definitionIdToDefinition.size() > 0) {
                for (Assessment_Criteria__c criteria : Trigger.new) {
                    if (definitionIdToDefinition.containsKey(criteria.Assessment_Criteria_Definition__c)) {
                        Assessment_Criteria_Definition__c definition = definitionIdToDefinition.get(criteria.Assessment_Criteria_Definition__c);
                        
                        // populate the assessment criteria name
                        if (Trigger.isInsert) criteria.Name = definition.Name;
                        
                        // validate the selected picklist value
                        if (criteria.Selected_Picklist_Value__c != null) {
                            if (definition.Picklist_Values__c != null) {
                                List<String> options = definition.Picklist_Values__c.split(';');
                                Integer size = options.size();
                                for (Integer i = 0; i < size; i++) {
                                    options[i] = options[i].trim();
                                }
                                if (!options.contains(criteria.Selected_Picklist_Value__c)) {
                                    criteria.addError(
                                        System.Label.sfims.part_of_error_message_10 + ' "' + criteria.Selected_Picklist_Value__c + '" ' + 
                                        System.Label.sfims.part_of_error_message_11 + '.'
                                    );
                                }
                            }
                        }

                        // validate rating
                        if (criteria.Rating__c != null) {
                            Boolean outOfRange = false;
                            if (definition.Minimum_Rating__c != null) {
                                if (criteria.Rating__c < definition.Minimum_Rating__c) outOfRange = true;
                            }
                            if (definition.Maximum_Rating__c != null) {
                                if (criteria.Rating__c > definition.Maximum_Rating__c) outOfRange = true;
                            }

                            if (outOfRange) {
                                List<String> ranges = new List<String>();
                                if (definition.Minimum_Rating__c != null) ranges.add(System.Label.sfims.range_1 + ': ' + definition.Minimum_Rating__c.intValue()); 
                                if (definition.Maximum_Rating__c != null) ranges.add(System.Label.sfims.range_2 + ': ' + definition.Maximum_Rating__c.intValue());
                                
                                criteria.addError(
                                    System.Label.sfims.range_3 + (!ranges.isEmpty() ? ' (' + String.join(ranges, ', ') + ')' : '')      
                                );
                            }
                        }
                    }
                }
            }
        }
    }
}