public with sharing class RescheduleLoanButtonController {

    @AuraEnabled
    public static Investment__c getLoan(String loanId) {
        // Check to see whether the caller has access to this information.
        if (!Investment__c.SObjectType.getDescribe().isAccessible()){
            throw new AuraHandledException(System.Label.sfims.error_message_34);
        }
        return [
            SELECT Status__c, Number_of_Instalments__c, Repayment_Frequency__c, Repayment_Frequency_Unit__c, Amount__c,
                Number_of_Grace_Periods__c, Grace_Period_Type__c, Capitalized_Amount__c, Capitalized_Fee_Amount__c,
                Setup_Fee_Charging_Method__c, Setup_Fee_Expected__c, Disbursement_Date__c, First_Repayment_Date__c,
                Open_Ended_Loan__c, Day_Count_Convention__c, Interest_Rate__c, Variable_Interest_Spread__c,
                Fees_Remaining__c, Late_Repayment_Fees_Remaining__c, Principal_Remaining__c, Interest_Overdue__c,
                Non_Working_Days_Rescheduling__c, Last_Instalment_Amount__c, Monitoring_Fee_Percentage__c,
                Loan_Product__r.Interest_Rate_Source__c, Loan_Product__r.Interest_Reference_Rate__c,
                Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c,
                Loan_Product__r.Grace_Period_Types__c, 
                (
                    SELECT Due_Date__c
                    FROM Repayment_Schedules__r
                    WHERE Due_Date__c > TODAY AND Active__c = TRUE AND Migration__c = FALSE
                    ORDER BY Due_Date__c
                )
            FROM Investment__c
            WHERE Id = :loanId
        ];

    }

    @AuraEnabled
    public static List<Repayment_Schedule__c> generateSchedulePreview(Map<String, Object> dataMap) {
        // Check to see whether the caller has access to this information.
        if (!Investment__c.SObjectType.getDescribe().isAccessible()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isAccessible())
        {
            throw new AuraHandledException(System.Label.sfims.error_message_22);
        }

        // System.debug((String)dataMap.get('loan'));
        Investment__c rescheduleInvestment = (Investment__c)JSON.deserialize((String)dataMap.get('loan'), Investment__c.class);
        // prevent creating a fees repayment schedule
        if (rescheduleInvestment.Setup_Fee_Charging_Method__c == 'Paid Up Front (scheduled)') 
            rescheduleInvestment.Setup_Fee_Charging_Method__c = null;
        // System.debug(rescheduleInvestment);
        Decimal initialInterest = 0;
        Decimal initialMonitoringFee = 0;
        if (dataMap.containsKey('additionalInterest')) initialInterest = Decimal.valueOf(String.valueOf(dataMap.get('additionalInterest')));
        if (dataMap.containsKey('additionalMonitoringFee')) initialMonitoringFee = Decimal.valueOf(String.valueOf(dataMap.get('additionalMonitoringFee')));
        
        if (String.valueOf(dataMap.get('action')) == 'Reschedule' 
            && (String.valueOf(dataMap.get('selectedType')) == 'Change Payment Date'
            || String.valueOf(dataMap.get('selectedType')) == 'Change Periodic Repayment Amount')) 
        {
            Date rescheduleDate = Date.valueOf(String.valueOf(dataMap.get('rescheduleDate')));
            // System.debug(rescheduleInvestment.Grace_Period_Type__c);
            // System.debug(rescheduleInvestment.Number_of_Grace_Periods__c);
            rescheduleInvestment.Number_of_Grace_Periods__c = [
                SELECT COUNT()
                FROM Repayment_Schedule__c
                WHERE Loan__c = :rescheduleInvestment.Id AND Due_Date__c > :rescheduleDate 
                    AND Active__c = TRUE AND Migration__c = FALSE AND Status__c = 'Grace'   
            ];
            // System.debug(rescheduleInvestment.Number_of_Grace_Periods__c);
        }

        Decimal pmtValue;
        if (dataMap.containsKey('pmtValue')) {
            pmtValue = Decimal.valueOf(String.valueOf(dataMap.get('pmtValue')));
            rescheduleInvestment.Number_of_Instalments__c = Math.floor(rescheduleInvestment.Capitalized_Amount__c / pmtValue).intValue() + 1;
            if (String.valueOf(dataMap.get('action')) == 'Reschedule' && String.valueOf(dataMap.get('selectedType')) == 'Change Periodic Repayment Amount')
                rescheduleInvestment.Number_of_Instalments__c += rescheduleInvestment.Number_of_Grace_Periods__c;
        }

        //-----Generate the new schedule based on the incoming loan-----
        //-----(link the new schedules to the original loan)-----
        List<Repayment_Schedule__c> rsToInsert = new List<Repayment_Schedule__c>();
        for (Repayment_Schedule__c rs : LoanScheduler.generateSchedule(rescheduleInvestment, initialInterest, initialMonitoringFee, pmtValue)) {
            // rs.Loan__c = recordId;
            rs.Loan__c = rescheduleInvestment.Id;
            rsToInsert.add(rs);
        }

        return rsToInsert;

    }

    @AuraEnabled
    public static void rescheduleLoan(Map<String, Object> dataMap){

        Map<String, List<SObject>> loanMap = RescheduleLoanButtonController.processRescheduling(dataMap);
        if (loanMap.containsKey('toUpdate')) {
            DMLManager.updateAsUser(loanMap.get('toUpdate'));
        }
        if (loanMap.containsKey('toDelete')) {
            DMLManager.deleteAsUser(loanMap.get('toDelete'));
        }
        DMLManager.insertAsUser(loanMap.get('toInsert'));
        Id loanId = (Id)dataMap.get('recordId');
        Investment__c inv = [
            SELECT Last_Instalment_Amount__c
            FROM Investment__c
            WHERE Id = :loanId
        ];
        inv.Last_Instalment_Amount__c = Utility.InstalmentAmount;
        DMLManager.updateAsUser(new List<Investment__c>{ inv });
        
        // re-apply transactions
        LoanTransactionProcessor.processLoanTransactions(new Set<Id>{loanId});

        // insert the Loan Event record
        DMLManager.insertAsSystem(loanMap.get('loanEvent'));

    }

    public static Map<String, List<SObject>> processRescheduling(Map<String, Object> dataMap){
        // Check to see whether the caller has access to this information.
        if (!Investment__c.SObjectType.getDescribe().isAccessible()
            || !Investment__c.SObjectType.getDescribe().isUpdateable()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isAccessible()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isCreateable()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isUpdateable()
            || !Loan_Event__c.SObjectType.getDescribe().isCreateable())
        {
            throw new AuraHandledException(System.Label.sfims.error_message_34);
        }

        Map<String, List<SObject>> returnMap = new Map<String, List<SObject>>();
        // process old repayment schedules
        Map<String, List<Repayment_Schedule__c>> repaymentSchedulesMap = RescheduleLoanButtonController.writeOff(dataMap);
        
        if (!repaymentSchedulesMap.isEmpty()) {
            List<Repayment_Schedule__c> rsToUpdate = RescheduleLoanButtonController.updateRepaymentSchedules(repaymentSchedulesMap);
            if (repaymentSchedulesMap.containsKey('delete')) {
                if (String.valueOf(dataMap.get('action')) == 'Reschedule') {                
                    Date rescheduleDate = Date.valueOf(String.valueOf(dataMap.get('rescheduleDate')));
                    List<Repayment_Schedule__c> rsToDelete = new List<Repayment_Schedule__c>();
                    for (Repayment_Schedule__c rs : repaymentSchedulesMap.get('delete')) {
                        if (rs.Start_Date__c >= rescheduleDate) {
                            rsToDelete.add(rs);
                            continue;
                        }
                        rs.Active__c = false;

                        Decimal feesPaid = 0;
                        Decimal principalPaid = 0;
                        Decimal feesWrittenOff = 0;
                        Decimal principalWrittenOff = 0;
                        
                        if (rs.Fees_Paid__c != null) feesPaid = rs.Fees_Paid__c;
                        if (rs.Principal_Paid__c != null) principalPaid = rs.Principal_Paid__c;
                        if (rs.Fees_Written_Off__c != null) feesWrittenOff = rs.Fees_Written_Off__c;
                        if (rs.Principal_Written_Off__c != null) principalWrittenOff = rs.Principal_Written_Off__c;

                        // make Expected amounts equal to sum of Paid and Written Off amount  
                        rs.Fees_Expected__c = feesPaid + feesWrittenOff;
                        rs.Principal_Expected__c = principalPaid + principalWrittenOff;

                        // update Due amounts that will be ignored by the RepaymentrsTrigger
                        if (rs.Due_Date__c < System.today()) {
                            rs.Fees_Due__c = rs.Fees_Expected__c;
                            rs.Principal_Due__c = rs.Principal_Expected__c;
                        }

                        if (rs.Due_Date__c > rescheduleDate) {
                            rs.Interest_Expected_Standard_Loan__c = rs.Interest_Expected_Standard_Loan__c * rs.Start_Date__c.daysBetween(rescheduleDate) / rs.Start_Date__c.daysBetween(rs.Due_Date__c);
                            rs.Due_Date__c = rescheduleDate;
                        }
                        rsToUpdate.add(rs);                    
                    }
                    if (!rsToDelete.isEmpty()) returnMap.put('toDelete', rsToDelete);
                } else {
                    returnMap.put('toDelete', repaymentSchedulesMap.get('delete'));
                }
            } 
            if (!rsToUpdate.isEmpty()) {
                returnMap.put('toUpdate', rsToUpdate);
            } 
        }

        // generate a new schedule
        List<Repayment_Schedule__c> rsToInsert = RescheduleLoanButtonController.generateSchedulePreview(dataMap);
        returnMap.put('toInsert', rsToInsert);

        // create a new Loan Event record
        Loan_Event__c loanEvent = RescheduleLoanButtonController.createLoanEvent(dataMap);
        returnMap.put('loanEvent', new List<SObject>{loanEvent});

        return returnMap;

    }

    @AuraEnabled
    public static void loanWriteOff(Map<String, Object> dataMap){
        // Check to see whether the caller has access to this information.
        if (!Investment__c.SObjectType.getDescribe().isAccessible()
            || !Investment__c.SObjectType.getDescribe().isUpdateable()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isAccessible()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isUpdateable()
            || !Loan_Event__c.SObjectType.getDescribe().isCreateable())
        {
            throw new AuraHandledException(System.Label.sfims.error_message_35);
        }
        System.debug(writeOff(dataMap));
        List<Repayment_Schedule__c> rsToUpdate = RescheduleLoanButtonController.writeOff(dataMap).get('written off');
        System.debug(rsToUpdate.size());
        
        Investment__c theLoan = [SELECT Id, Status__c FROM Investment__c WHERE Id =: (Id)dataMap.get('recordId')];
        theLoan.Status__c = 'Closed - Written Off';
        
        // the status updates need to be done as system user since normal users will not have update rights on the status fields on both objects.
        DMLManager.updateAsSystem(new List<Investment__c>{theLoan});

        for (Repayment_Schedule__c temp : rsToUpdate) {
            temp.Status__c = 'Defaulted';
        }
        System.debug(rsToUpdate[0].Status__c);
        DMLManager.updateAsSystem(rsToUpdate);

        //-----Create a new Loan Event record-----
        Loan_Event__c loanEvent = new Loan_Event__c(
            Event_Date__c = Date.valueOf(String.valueOf(dataMap.get('writeOffDate'))),
            Fees_Written_Off__c = Decimal.valueOf(String.valueOf(dataMap.get('totalFeesWrittenOff'))),
            Interest_Written_Off__c = Decimal.valueOf(String.valueOf(dataMap.get('totalInterestWrittenOff'))),
            Investment__c = (Id)dataMap.get('recordId'),
            Loan_Event_Type__c = 'Closed (Written Off)',
            Late_Repayment_Fees_Written_Off__c = Decimal.valueOf(String.valueOf(dataMap.get('totalPenaltiesWrittenOff'))),
            Principal_Written_Off__c = Decimal.valueOf(String.valueOf(dataMap.get('totalPrincipalWrittenOff')))
        );

        //-----Insert the Loan Event record and update the Investment record with the new attributes-----
        DMLManager.insertAsUser(new List<Loan_Event__c>{loanEvent});

    }

    public static Map<String, List<Repayment_Schedule__c>> writeOff(Map<String, Object> dataMap){
        // Check to see whether the caller has access to this information.
        if (!Repayment_Schedule__c.SObjectType.getDescribe().isAccessible()) {
            throw new AuraHandledException(System.Label.sfims.error_message_35);
        }

        Map<String, List<Repayment_Schedule__c>> returnMap = new Map<String, List<Repayment_Schedule__c>>();
        // System.debug(dataMap);

        List<Repayment_Schedule__c> repaymentSchedules = new List<Repayment_Schedule__c>();
        if (dataMap.containsKey('repaymentSchedules')) {
            if (String.isBlank((String)dataMap.get('repaymentSchedules'))) {
                return returnMap;
            }
            repaymentSchedules = (List<Repayment_Schedule__c>)JSON.deserialize((String)dataMap.get('repaymentSchedules'), List<Repayment_Schedule__c>.class);
        } else {
            repaymentSchedules = [
                SELECT Active__c, Total_Paid__c, Principal_Remaining__c, Principal_Written_Off__c, Interest_Remaining__c, Interest_Written_Off__c, Due_Date__c,
                    Fees_Remaining__c, Fees_Written_Off__c, Late_Repayment_Fees_Remaining__c, Late_Repayment_Fees_Written_Off__c, Loan__c, Total_Due__c,
                    Principal_Balance__c, Status__c, Fees_Paid__c, Interest_Paid__c, Late_Repayment_Fees_Paid__c, Principal_Paid__c, Start_Date__c, 
                    Interest_Expected_Standard_Loan__c, Current_Interest_Expected__c 
                FROM Repayment_Schedule__c
                WHERE Loan__c =: (Id)dataMap.get('recordId') AND Active__c = true
                ORDER BY Due_Date__c ASC
            ];
        }

        Decimal principalWrittenOff = Decimal.valueOf(String.valueOf(dataMap.get('totalPrincipalWrittenOff')));
        Decimal interestWrittenOff = Decimal.valueOf(String.valueOf(dataMap.get('totalInterestWrittenOff')));
        Decimal feesWrittenOff = Decimal.valueOf(String.valueOf(dataMap.get('totalFeesWrittenOff')));
        Decimal penaltiesWrittenOff = Decimal.valueOf(String.valueOf(dataMap.get('totalPenaltiesWrittenOff')));
        
        if (!repaymentSchedules.isEmpty()) {
            Map<String, Repayment_Schedule__c> repaymentSchedulesMap = new Map<String, Repayment_Schedule__c>(repaymentSchedules);
            Decimal sumPrincipalWrittenOff = 0;

            for (String key : repaymentSchedulesMap.keySet()) {
                Repayment_Schedule__c schedule = repaymentSchedulesMap.get(key);
                Boolean writtenOff = false;

                if (principalWrittenOff > 0 && schedule.Principal_Remaining__c > 0) {
                    writtenOff = true;
                    if (principalWrittenOff >= schedule.Principal_Remaining__c) {
                        principalWrittenOff -= schedule.Principal_Remaining__c;
                        if (schedule.Principal_Written_Off__c != null) {
                            schedule.Principal_Written_Off__c += schedule.Principal_Remaining__c;
                        } else {
                            schedule.Principal_Written_Off__c = schedule.Principal_Remaining__c;
                        }
                        sumPrincipalWrittenOff += schedule.Principal_Remaining__c;
                    } else {
                        if (schedule.Principal_Written_Off__c != null) {
                            schedule.Principal_Written_Off__c += principalWrittenOff;
                        } else {
                            schedule.Principal_Written_Off__c = principalWrittenOff;
                        }
                        sumPrincipalWrittenOff += principalWrittenOff;
                        principalWrittenOff = 0;
                    }
                }

                if (sumPrincipalWrittenOff != 0) { 
                    schedule.Principal_Balance__c -= sumPrincipalWrittenOff;
                }  

                if (interestWrittenOff > 0 && schedule.Interest_Remaining__c > 0) {
                    if (writtenOff == false) writtenOff = true;
                    if (interestWrittenOff >= schedule.Interest_Remaining__c) {
                        interestWrittenOff -= schedule.Interest_Remaining__c;
                        if (schedule.Interest_Written_Off__c != null) {
                            schedule.Interest_Written_Off__c += schedule.Interest_Remaining__c;
                        } else {
                            schedule.Interest_Written_Off__c = schedule.Interest_Remaining__c;
                        }
                    } else {
                        if (schedule.Interest_Written_Off__c != null) {
                            schedule.Interest_Written_Off__c += interestWrittenOff;
                        } else {
                            schedule.Interest_Written_Off__c = interestWrittenOff;
                        }
                        interestWrittenOff = 0;
                    }
                }

                if (feesWrittenOff > 0 && schedule.Fees_Remaining__c > 0) {
                    if (writtenOff == false) writtenOff = true;
                    if (feesWrittenOff >= schedule.Fees_Remaining__c) {
                        feesWrittenOff -= schedule.Fees_Remaining__c;
                        if (schedule.Fees_Written_Off__c != null) {
                            schedule.Fees_Written_Off__c += schedule.Fees_Remaining__c;
                        } else {
                            schedule.Fees_Written_Off__c = schedule.Fees_Remaining__c;
                        }
                    } else {
                        if (schedule.Fees_Written_Off__c != null) {
                            schedule.Fees_Written_Off__c += feesWrittenOff;
                        } else {
                            schedule.Fees_Written_Off__c = feesWrittenOff;
                        }
                        feesWrittenOff = 0;
                    }
                }

                if (penaltiesWrittenOff > 0 && schedule.Late_Repayment_Fees_Remaining__c > 0) {
                    if (writtenOff == false) writtenOff = true;
                    if (penaltiesWrittenOff >= schedule.Late_Repayment_Fees_Remaining__c) {
                        penaltiesWrittenOff -= schedule.Late_Repayment_Fees_Remaining__c;
                        if (schedule.Late_Repayment_Fees_Written_Off__c != null) {
                            schedule.Late_Repayment_Fees_Written_Off__c += schedule.Late_Repayment_Fees_Remaining__c;
                        } else {
                            schedule.Late_Repayment_Fees_Written_Off__c = schedule.Late_Repayment_Fees_Remaining__c;
                        }
                    } else {
                        if (schedule.Late_Repayment_Fees_Written_Off__c != null) {
                            schedule.Late_Repayment_Fees_Written_Off__c += penaltiesWrittenOff;
                        } else {
                            schedule.Late_Repayment_Fees_Written_Off__c = penaltiesWrittenOff;
                        }
                        penaltiesWrittenOff = 0;
                    }
                }
                
                if (String.valueOf(dataMap.get('action')) == 'Reschedule' && schedule.Start_Date__c < Date.valueOf(String.valueOf(dataMap.get('rescheduleDate')))) {
                    if (!returnMap.containsKey('delete')) {
                        returnMap.put('delete', new List<Repayment_Schedule__c>());
                    }
                    returnMap.get('delete').add(schedule);
                    continue;
                }
                if (writtenOff) {
                    if (!returnMap.containsKey('written off')) {
                        returnMap.put('written off', new List<Repayment_Schedule__c>());
                    }
                    returnMap.get('written off').add(schedule);
                    continue;
                }

                if (schedule.Total_Paid__c > 0) {
                     if (!returnMap.containsKey('paid')) {
                        returnMap.put('paid', new List<Repayment_Schedule__c>());
                    }
                    returnMap.get('paid').add(schedule);
                    continue;
                }

                if (!returnMap.containsKey('delete')) {
                    returnMap.put('delete', new List<Repayment_Schedule__c>());
                }
                returnMap.get('delete').add(schedule);
            }   
        }

        return returnMap;

    }

    public static List<Repayment_Schedule__c> updateRepaymentSchedules(Map<String, List<Repayment_Schedule__c>> repaymentSchedulesMap){
        List<Repayment_Schedule__c> rsToUpdate = new List<Repayment_Schedule__c>();
        if (repaymentSchedulesMap.containsKey('written off')) {
            rsToUpdate.addAll(repaymentSchedulesMap.get('written off'));
            
        }
        if (repaymentSchedulesMap.containsKey('paid')) {
            rsToUpdate.addAll(repaymentSchedulesMap.get('paid'));
        }
        
        // update repayment schedules in which there is a Paid or Written Off amount
        Repayment_Schedule__c schedule = new Repayment_Schedule__c();
        if (!rsToUpdate.isEmpty()) {
            for (Repayment_Schedule__c temp : rsToUpdate) {
                Decimal feesPaid = 0;
                Decimal interestPaid = 0;
                Decimal lateRepaymentFeesPaid = 0;
                Decimal principalPaid = 0;

                Decimal feesWrittenOff = 0;
                Decimal interestWrittenOff = 0;
                Decimal lateRepaymentFeesWrittenOff = 0;
                Decimal principalWrittenOff = 0;
                
                schedule = temp;
                schedule.Active__c = false;
                
                if (schedule.Fees_Paid__c != null) feesPaid = schedule.Fees_Paid__c;
                if (schedule.Interest_Paid__c != null) interestPaid = schedule.Interest_Paid__c;
                if (schedule.Late_Repayment_Fees_Paid__c != null) lateRepaymentFeesPaid = schedule.Late_Repayment_Fees_Paid__c;
                if (schedule.Principal_Paid__c != null) principalPaid = schedule.Principal_Paid__c;
                if (schedule.Fees_Written_Off__c != null) feesWrittenOff = schedule.Fees_Written_Off__c;
                if (schedule.Interest_Written_Off__c != null) interestWrittenOff = schedule.Interest_Written_Off__c;
                if (schedule.Late_Repayment_Fees_Written_Off__c != null) lateRepaymentFeesWrittenOff = schedule.Late_Repayment_Fees_Written_Off__c;
                if (schedule.Principal_Written_Off__c != null) principalWrittenOff = schedule.Principal_Written_Off__c;

                // make Expected amounts equal to sum of Paid and Written Off amount  
                schedule.Fees_Expected__c = feesPaid + feesWrittenOff;
                schedule.Principal_Expected__c = principalPaid + principalWrittenOff;
                schedule.Interest_Expected_Standard_Loan__c = interestPaid + interestWrittenOff;
                schedule.Late_Repayment_Fees_On_Last_Paid_Date__c = lateRepaymentFeesPaid + lateRepaymentFeesWrittenOff;

                // update Due amounts that will be ignored by the RepaymentScheduleTrigger
                if (schedule.Due_Date__c < System.today()) {
                    schedule.Fees_Due__c = schedule.Fees_Expected__c;
                    schedule.Interest_Due__c = schedule.Interest_Expected_Standard_Loan__c;
                    schedule.Late_Repayment_Fees_Due__c = schedule.Late_Repayment_Fees_On_Last_Paid_Date__c;
                    schedule.Principal_Due__c = schedule.Principal_Expected__c;
                }
            }
        }
        
        return rsToUpdate;

    }

    public static Loan_Event__c createLoanEvent(Map<String, Object> dataMap){
        Investment__c rescheduleInvestment = (Investment__c)JSON.deserialize((String)dataMap.get('loan'), Investment__c.class);
        //-----Create a new Loan Event record-----
        System.debug(Utility.InstalmentAmount);
        Loan_Event__c loanEvent = new Loan_Event__c(
            Fees_Written_Off__c = Decimal.valueOf(String.valueOf(dataMap.get('totalFeesWrittenOff'))),
            Interest_Written_Off__c = Decimal.valueOf(String.valueOf(dataMap.get('totalInterestWrittenOff'))),
            Loan_Event_Type__c = String.valueOf(dataMap.get('action')),
            Amount__c = rescheduleInvestment.Capitalized_Amount__c,
            First_Repayment_Date__c = rescheduleInvestment.First_Repayment_Date__c,
            Number_of_Grace_Periods__c = rescheduleInvestment.Number_of_Grace_Periods__c,
            Grace_Period_Type__c = rescheduleInvestment.Grace_Period_Type__c,
            Instalment_Amount__c = Utility.InstalmentAmount,
            Investment__c = rescheduleInvestment.Id,
            Loan_Product__c = rescheduleInvestment.Loan_Product__c,
            Number_of_Instalments__c = rescheduleInvestment.Number_of_Instalments__c,
            Late_Repayment_Fees_Written_Off__c = Decimal.valueOf(String.valueOf(dataMap.get('totalPenaltiesWrittenOff'))),
            Principal_Written_Off__c = Decimal.valueOf(String.valueOf(dataMap.get('totalPrincipalWrittenOff'))),
            Repayment_Frequency__c = rescheduleInvestment.Repayment_Frequency__c,
            Repayment_Frequency_Unit__c = rescheduleInvestment.Repayment_Frequency_Unit__c
        );
        if (dataMap.containsKey('rationale')) {
            // System.debug((String)dataMap.get('rationale'));
            loanEvent.Comment__c = (String)dataMap.get('rationale');
        }
        switch on rescheduleInvestment.Loan_Product__r.Interest_Rate_Source__c {
            when 'Fixed Interest' {
                loanEvent.Interest_Rate__c = rescheduleInvestment.Interest_Rate__c;
            }
            when 'Variable Interest' {
                loanEvent.Variable_Interest_Spread__c = rescheduleInvestment.Variable_Interest_Spread__c;        
            }
        }
        switch on String.valueOf(dataMap.get('action')) {
            when 'Refinance' {
                loanEvent.Event_Date__c = Date.valueOf(String.valueOf(dataMap.get('refinanceDate')));
            }
            when 'Reschedule' {
                loanEvent.Event_Date__c = Date.valueOf(String.valueOf(dataMap.get('rescheduleDate')));
                loanEvent.Reschedule_Type__c = (String)dataMap.get('selectedType');               
            }
            when 'Disbursement' {
                loanEvent.Event_Date__c = Date.valueOf(String.valueOf(dataMap.get('disbursementDate')));
            }
        }
        return loanEvent;
    }

}