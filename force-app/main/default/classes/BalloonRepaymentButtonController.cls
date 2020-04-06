public class BalloonRepaymentButtonController {
    // this method is executed when the Schedule Balloon Repayment button is clicked
    @AuraEnabled
    public static Investment__c getRepaymentSchedules(Id loanId) {
        // Check to see whether the caller has access to this information.
        if (!Repayment_Schedule__c.SObjectType.getDescribe().isAccessible()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isUpdateable()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isDeletable())
        {
            throw new AuraHandledException(System.Label.sfims.error_message_1);
        }

        return [
            SELECT Open_Ended_Loan__c,
            (
                SELECT Due_Date__c, Fees_Expected__c, Fees_Paid__c, Fees_Written_Off__c, 
                    Principal_Expected__c, Principal_Paid__c, Principal_Written_Off__c,
                    Monitoring_Fees_Expected__c, Setup_Fees_Expected__c, Total_Expected__c
                FROM Repayment_Schedules__r
                WHERE Active__c = true AND Migration__c = false AND Due_Date__c > TODAY
                ORDER BY Due_Date__c
            )
            FROM Investment__c
            WHERE Id =: loanId    
        ];

    }

    // this method is executed when the Confirm button on the Schedule Balloon Repayment pop-up is clicked
    @AuraEnabled
    public static void scheduleBalloonRepayment(String schedulesString, Integer scheduleNumber, Id loanId) {
        List<Repayment_Schedule__c> schedules = (List<Repayment_Schedule__c>)JSON.deserialize(schedulesString, List<Repayment_Schedule__c>.class);
        
        Map<String, List<Repayment_Schedule__c>> schedulesMap = BalloonRepaymentButtonController.processRepaymentSchedules(schedules, scheduleNumber, loanId);

        // Savepoint sp = Database.setSavepoint();
        // try {
            if (!schedulesMap.get('schedulesToDelete').isEmpty()) DMLManager.deleteAsUser(schedulesMap.get('schedulesToDelete'));
            DMLManager.updateAsUser(schedulesMap.get('schedulesToUpdate'));

            Loan_Event__c le = new Loan_Event__c(
                Event_Date__c = System.today(),                     
                Investment__c = loanId,
                Loan_Event_Type__c = 'Bullet Repayment',
                Balloon_Repayment_Period__c = scheduleNumber
            );
            DMLManager.insertAsSystem(new List<Loan_Event__c>{le});
            
        // } catch(System.DmlException e) {
        //    Database.rollback(sp);
        //    throw new AuraHandledException(e.getDmlMessage(0));
        // }
    }

    public static Map<String, List<Repayment_Schedule__c>> processRepaymentSchedules(List<Repayment_Schedule__c> schedules, Integer scheduleNumber, Id loanId) {
        List<Repayment_Schedule__c> schedulesToDelete = new List<Repayment_Schedule__c>();
        List<Repayment_Schedule__c> schedulesToUpdate = new List<Repayment_Schedule__c>();
        
        Decimal principalExpected = 0;
        Decimal setupFeesExpected = 0;
        Decimal monitoringFeeExpected = 0;
        Decimal principalPaid = 0;
        Decimal feesPaid = 0;
        Decimal principalWrittenOff = 0;
        Decimal feesWrittenOff = 0;
        
        Repayment_Schedule__c schedule = new Repayment_Schedule__c();
        for (Integer i = scheduleNumber + 1; i < schedules.size(); i++) {
            schedule = schedules[i];
            
            principalExpected += schedule.Principal_Expected__c;
            setupFeesExpected += schedule.Setup_Fees_Expected__c;
            monitoringFeeExpected += schedule.Monitoring_Fees_Expected__c;

            principalPaid += schedule.Principal_Paid__c;
            feesPaid += schedule.Fees_Paid__c;

            principalWrittenOff += schedule.Principal_Written_Off__c;
            feesWrittenOff += schedule.Fees_Written_Off__c;

            schedulesToDelete.add(schedule);
        }
        
        schedule = schedules[scheduleNumber];
        schedule.Principal_Expected__c += principalExpected;
        schedule.Fees_Expected__c += setupFeesExpected + monitoringFeeExpected;
        schedule.Setup_Fees_Expected__c += setupFeesExpected;
        schedule.Monitoring_Fees_Expected__c += monitoringFeeExpected;
        schedule.Principal_Paid__c += principalPaid;
        schedule.Fees_Paid__c += feesPaid;
        schedule.Principal_Written_Off__c += principalWrittenOff;
        schedule.Fees_Written_Off__c += feesWrittenOff;

        schedule.Expected_Principal_Balance__c = 0;
        schedulesToUpdate.add(schedule);

        Map<String, List<Repayment_Schedule__c>> returnMap = new Map<String, List<Repayment_Schedule__c>>();
        returnMap.put('schedulesToUpdate', schedulesToUpdate);
        returnMap.put('schedulesToDelete', schedulesToDelete);
        
        return returnMap;

    }
}