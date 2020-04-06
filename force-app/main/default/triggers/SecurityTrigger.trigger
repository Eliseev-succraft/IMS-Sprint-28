trigger SecurityTrigger on Security__c (after insert, after update, after delete) {
    if (Trigger.isAfter && Trigger.isInsert) {
        populateInvestmentFields(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        populateInvestmentFields(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isDelete) {
        populateInvestmentFields(Trigger.old);
    }

    public void populateInvestmentFields(List<Security__c> securities) {
        Map<Id, Decimal> investmentIdToTotalCollateral = new Map<Id, Decimal>();
        Map<Id, Decimal> investmentIdToTotalGuarantee = new Map<Id, Decimal>();
        for (Security__c security : securities) {
            if (Trigger.isUpdate) {
                // check security status
                if (security.Status__c == 'Confirmed' && Trigger.oldMap.get(security.Id).Status__c == 'Confirmed') {
                    // in this case we should check if amount, investment or recordtype has been changed
                    if (security.Investment__c != Trigger.oldMap.get(security.Id).Investment__c) {
                        // if investment has been changed, both them should be recalculated
                        if (security.Investment__c != null) {
                            investmentIdToTotalCollateral = addCollateral(security, investmentIdToTotalCollateral);
                            investmentIdToTotalGuarantee = addGuarantee(security, investmentIdToTotalGuarantee);
                        }

                        if (Trigger.oldMap.get(security.Id).Investment__c != null) {
                            investmentIdToTotalCollateral = addCollateral(Trigger.oldMap.get(security.Id), investmentIdToTotalCollateral);
                            investmentIdToTotalGuarantee = addGuarantee(Trigger.oldMap.get(security.Id), investmentIdToTotalGuarantee);
                        }
                    } else
                    if (security.RecordTypeId != Trigger.oldMap.get(security.Id).RecordTypeId && security.Investment__c != null) {
                        // if recordtype has been changed, Total Collateral and Total Guarantee should be recalculated at the Investment level
                        investmentIdToTotalCollateral = addCollateral(security, investmentIdToTotalCollateral);
                        investmentIdToTotalGuarantee = addGuarantee(security, investmentIdToTotalGuarantee);
                
                        investmentIdToTotalCollateral = addCollateral(Trigger.oldMap.get(security.Id), investmentIdToTotalCollateral);
                        investmentIdToTotalGuarantee = addGuarantee(Trigger.oldMap.get(security.Id), investmentIdToTotalGuarantee);
                    } else
                    if (security.Amount__c != Trigger.oldMap.get(security.Id).Amount__c && security.Investment__c != null) {
                        investmentIdToTotalCollateral = addCollateral(security, investmentIdToTotalCollateral);
                        investmentIdToTotalGuarantee = addGuarantee(security, investmentIdToTotalGuarantee);
                    }
                } else 
                if (security.Status__c == 'Confirmed' && Trigger.oldMap.get(security.Id).Status__c != 'Confirmed' && security.Investment__c != null) {
                    // this case is similar to insert
                    investmentIdToTotalCollateral = addCollateral(security, investmentIdToTotalCollateral);
                    investmentIdToTotalGuarantee = addGuarantee(security, investmentIdToTotalGuarantee);
                } else
                if (security.Status__c != 'Confirmed' && Trigger.oldMap.get(security.Id).Status__c == 'Confirmed' 
                    && Trigger.oldMap.get(security.Id).Investment__c != null) 
                {
                    // this case is similar to delete
                    investmentIdToTotalCollateral = addCollateral(Trigger.oldMap.get(security.Id), investmentIdToTotalCollateral);
                    investmentIdToTotalGuarantee = addGuarantee(Trigger.oldMap.get(security.Id), investmentIdToTotalGuarantee);
                } 
            } else {// insert or delete
                if (security.Status__c == 'Confirmed' && security.Investment__c != null) {
                    investmentIdToTotalCollateral = addCollateral(security, investmentIdToTotalCollateral);
                    investmentIdToTotalGuarantee = addGuarantee(security, investmentIdToTotalGuarantee);
                }
            }
        }
        if (!investmentIdToTotalCollateral.isEmpty()) {
            // сount Total Collateral for each investment in the Collateral map
            for (Security__c security : [SELECT Amount__c, Investment__c FROM Security__c WHERE Status__c = 'Confirmed'
                AND RecordTypeId = :Utility.collateralRecordTypeId AND Investment__c IN :investmentIdToTotalCollateral.keySet()]) 
            {
                Decimal totalCollateral = investmentIdToTotalCollateral.get(security.Investment__c) + security.Amount__c;
                investmentIdToTotalCollateral.put(security.Investment__c, totalCollateral);
            }
        }

        if (!investmentIdToTotalGuarantee.isEmpty()) {
            // сount Total Guarantee for each investment in the Guarantee map
            for (Security__c security : [SELECT Amount__c, Investment__c FROM Security__c WHERE Status__c = 'Confirmed'
                AND RecordTypeId = :Utility.guaranteeRecordTypeId AND Investment__c IN :investmentIdToTotalGuarantee.keySet()]) 
            {
                Decimal totalGuarantee = investmentIdToTotalGuarantee.get(security.Investment__c) + security.Amount__c;
                investmentIdToTotalGuarantee.put(security.Investment__c, totalGuarantee);
            }
        }
        
        // update investments
        Set<Id> investmentIds = new Set<Id>();
        investmentIds.addAll(investmentIdToTotalCollateral.keySet());
        investmentIds.addAll(investmentIdToTotalGuarantee.keySet());
        List<Investment__c> investmentsToUpdate = new List<Investment__c>();
        for (Id key : investmentIds) {
            Investment__c inv = new Investment__c(Id = key);
            if (investmentIdToTotalCollateral.containsKey(key)) inv.Total_Collateral__c = investmentIdToTotalCollateral.get(key);
            if (investmentIdToTotalGuarantee.containsKey(key)) inv.Total_Guarantee__c = investmentIdToTotalGuarantee.get(key);
            investmentsToUpdate.add(inv);
        }
        update investmentsToUpdate;
    }

    public Map<Id, Decimal> addCollateral(Security__c security, Map<Id, Decimal> investmentIdToTotalCollateral) {
        if (security.RecordTypeId == Utility.collateralRecordTypeId) {
            if (!investmentIdToTotalCollateral.containsKey(security.Investment__c)) 
                investmentIdToTotalCollateral.put(security.Investment__c, 0);
        }
        return investmentIdToTotalCollateral;
    }

    public Map<Id, Decimal> addGuarantee(Security__c security, Map<Id, Decimal> investmentIdToTotalGuarantee) {
        if (security.RecordTypeId == Utility.guaranteeRecordTypeId) {
            if (!investmentIdToTotalGuarantee.containsKey(security.Investment__c)) 
                investmentIdToTotalGuarantee.put(security.Investment__c, 0);
        }
        return investmentIdToTotalGuarantee;
    }
}