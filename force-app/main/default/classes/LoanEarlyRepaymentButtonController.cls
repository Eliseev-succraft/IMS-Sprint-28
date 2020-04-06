public with sharing class LoanEarlyRepaymentButtonController {
    
    @AuraEnabled
    public static void loanPayOff(Map<String, Object> dataMap){
        // Check to see whether the caller has access to this information.
        if (!Investment__c.SObjectType.getDescribe().isAccessible()
            || !Investment__c.SObjectType.getDescribe().isUpdateable()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isAccessible()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isUpdateable()
            || !Loan_Event__c.SObjectType.getDescribe().isCreateable()
            || !Transaction__c.SObjectType.getDescribe().isCreateable())
        {
            throw new AuraHandledException(System.Label.sfims.error_message_23);
        }
        
        List<Repayment_Schedule__c> rsToUpdate = new List<Repayment_Schedule__c>();
        for (List<Repayment_Schedule__c> rsList : RescheduleLoanButtonController.writeOff(dataMap).values()) {
            rsToUpdate.addAll(rsList);
        }
        DMLManager.updateAsUser(rsToUpdate);
        System.debug(rsToUpdate);
        
        //-----Create a new Loan Event record-----
        Loan_Event__c loanEvent = new Loan_Event__c(
            Event_Date__c = Date.valueOf(String.valueOf(dataMap.get('earlyRepaymentDate'))),
            Fees_Written_Off__c = Decimal.valueOf(String.valueOf(dataMap.get('totalFeesWrittenOff'))),
            Interest_Written_Off__c = Decimal.valueOf(String.valueOf(dataMap.get('totalInterestWrittenOff'))),
            Investment__c = (Id)dataMap.get('recordId'),
            Loan_Event_Type__c = 'Closed (Early Repayment)',
            Late_Repayment_Fees_Written_Off__c = Decimal.valueOf(String.valueOf(dataMap.get('totalPenaltiesWrittenOff'))),
            Principal_Written_Off__c = Decimal.valueOf(String.valueOf(dataMap.get('totalPrincipalWrittenOff')))
        );

        //-----Insert the Loan Event record and update the Investment record with the new attributes-----
        DMLManager.insertAsUser(new List<Loan_Event__c>{loanEvent});
        
        //-----Create an early repayment transaction-----
        Transaction__c newTransaction = new Transaction__c(
            Investment__c = (Id)dataMap.get('recordId'),
            Loan_Event__c = loanEvent.Id,
            Amount__c = Decimal.valueOf(String.valueOf(dataMap.get('totalEarlyRepaymentAmount'))),
            Type__c = 'Repayment',
            Status__c = 'Received',
            Transaction_Date__c = System.today()
        );
        DMLManager.insertAsUser(new List<Transaction__c>{newTransaction});

        Investment__c theLoan = [SELECT Id, Status__c FROM Investment__c WHERE Id =: (Id)dataMap.get('recordId')];
        theLoan.Status__c = 'Closed - Early Repayment';
        DMLManager.updateAsUser(new List<Investment__c>{theLoan});
    }

}