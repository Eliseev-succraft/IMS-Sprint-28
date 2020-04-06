public with sharing class CancelLateRepaymentFeeButtonController {
    
    // this method is executed when the Disburse Loan button is clicked
    @AuraEnabled
    public static String cancelLateRepaymentFee(Id rsId) {
        // Check to see whether the caller has access to this information.
        if (!Repayment_Schedule__c.SObjectType.getDescribe().isAccessible()
            || !Loan_Event__c.SObjectType.getDescribe().isCreateable())
        {
            throw new AuraHandledException(System.Label.sfims.error_message_60);
        }
        
        Repayment_Schedule__c rs = [
            SELECT Due_Date__c, Late_Repayment_Fees_Expected0__c, Loan__c, Loan__r.Loan_Product__c, Cancel_Late_Repayment_Fee__c, Loan__r.Open_Ended_Loan__c
            FROM Repayment_Schedule__c
            WHERE Id =: rsId
        ];

        if (rs.Loan__r.Open_Ended_Loan__c) throw new AuraHandledException(System.Label.sfims.error_message_61);
        if (rs.Cancel_Late_Repayment_Fee__c) throw new AuraHandledException(System.Label.sfims.error_message_62);
        if (rs.Late_Repayment_Fees_Expected0__c <= 0) throw new AuraHandledException(System.Label.sfims.error_message_63);
        
        //-----Check if this button has been already clicked and this action is pending approval-----
        List<Loan_Event_Detail__c> leds = [
            SELECT Id, Name
            FROM Loan_Event_Detail__c
            WHERE Loan_Event__r.Investment__c = :rs.Loan__c AND Loan_Event__r.Loan_Event_Type__c = 'Fee Cancelled'
                AND Loan_Event__r.Approval_Status__c = 'Pending Approval' AND Due_Date__c = :rs.Due_Date__c
            LIMIT 1
        ];

        if (leds.isEmpty()) {
            //-----Create a new Loan Event record-----
            Loan_Event__c loanEvent = new Loan_Event__c(
                Event_Date__c = System.today(),
                Loan_Event_Type__c = 'Fee Cancelled',
                Investment__c = rs.Loan__c,
                Loan_Product__c = rs.Loan__r.Loan_Product__c,
                Approval_Status__c = 'Pending Approval'
            );
            DMLManager.insertAsSystem(new List<SObject>{loanEvent});

            //-----Create a new Loan Event Detail record-----
            Loan_Event_Detail__c detail = new Loan_Event_Detail__c(
                Loan_Event__c = loanEvent.Id,
                Cancel_Late_Repayment_Fee__c = true,
                Due_Date__c = rs.Due_Date__c
            );
            DMLManager.insertAsSystem(new List<SObject>{detail});

            //-----Submit for Approval-----
            Approval.ProcessSubmitRequest request = new Approval.ProcessSubmitRequest();
            request.setObjectId(loanEvent.Id);
            request.setSubmitterId(UserInfo.getUserId());
            
            Approval.ProcessResult result = Approval.process(request, false);
            if (result.isSuccess()) {
                System.debug('success');
                return System.Label.sfims.success_message_2;
            } else {
                System.debug(result.getErrors()[0].getMessage());
                if (result.getErrors()[0].getMessage().contains(System.Label.sfims.error_message_59)) {
                    loanEvent.Approval_Status__c = 'No Approval Required';
                    DMLManager.updateAsSystem(new List<SObject>{loanEvent});
                    return System.Label.sfims.success_message_1;
                } else {
                    throw new AuraHandledException(result.getErrors()[0].getMessage());
                }
            }    
        } else {
            throw new AuraHandledException(System.Label.sfims.error_message_64);
        }    
    }
}