public with sharing class LoanScheduler {
    
    @AuraEnabled
    public static void recalculateLoanSchedule(String loanId){
        // Check to see whether the caller has access to this information. 
        if (!Investment__c.SObjectType.getDescribe().isAccessible()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isCreateable()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isDeletable()) { 
            throw new AuraHandledException(System.Label.sfims.error_message_25);
        }

        List<Repayment_Schedule__c> scheduleToInsert = LoanScheduler.generateScheduleById(loanId);

        // try{
            
            DMLManager.deleteAsUser([SELECT Id FROM Repayment_Schedule__c WHERE Loan__c = :loanId AND Migration__c = false]);
            // we need to use insertAsSystem because we are writing to fields that normal users don't have access to (they should not be able to modify the fields themselves directly)
            DMLManager.insertAsUser(scheduleToInsert);
            
            System.debug(Utility.InstalmentAmount);
            Investment__c inv = [
                SELECT Last_Instalment_Amount__c
                FROM Investment__c
                WHERE Id = :loanId
            ];
            inv.Last_Instalment_Amount__c = Utility.InstalmentAmount;
            DMLManager.updateAsUser(new List<Investment__c>{ inv });

            //-----Re-apply any existing transactions on the loan-----
            DMLManager.updateAsUser([SELECT Id FROM Transaction__c WHERE Investment__c =: loanId]);

        // } catch (Exception e){
        //     throw new AuraHandledException(e.getMessage());
        // }
    }

    @AuraEnabled
    public static List<Repayment_Schedule__c> generateScheduleById(String loanId){
        // Check to see whether the caller has access to this information. 
        if (!Investment__c.SObjectType.getDescribe().isAccessible()
            || !Repayment_Schedule__c.SObjectType.getDescribe().isCreateable()) { 
            throw new AuraHandledException(System.Label.sfims.error_message_25);
        }                     
        Investment__c theLoan = [
            SELECT Number_of_Instalments__c, Repayment_Frequency__c, Repayment_Frequency_Unit__c, Amount__c,
                Number_of_Grace_Periods__c, Grace_Period_Type__c, Capitalized_Amount__c, Capitalized_Fee_Amount__c,
                Setup_Fee_Charging_Method__c, Setup_Fee_Expected__c, Disbursement_Date__c, First_Repayment_Date__c,
                Open_Ended_Loan__c, Interest_Rate__c, Day_Count_Convention__c, Variable_Interest_Spread__c,
                Loan_Product__r.Interest_Rate_Source__c, Loan_Product__r.Interest_Reference_Rate__c, 
                Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c, 
                Non_Working_Days_Rescheduling__c, Monitoring_Fee_Percentage__c 
            FROM Investment__c
            WHERE Id = :loanId
        ];
        return generateSchedule(theLoan);
    }

    public static List<Repayment_Schedule__c> generateSchedule(Investment__c theLoan){
        return LoanScheduler.generateSchedule(theLoan, 0, 0);
    }

    public static List<Repayment_Schedule__c> generateSchedule(Investment__c theLoan, Decimal initialInterest, Decimal initialMonitoringFee) {
        return LoanScheduler.generateSchedule(theLoan, initialInterest, initialMonitoringFee, null);
    }

    public static List<Repayment_Schedule__c> generateSchedule(Investment__c theLoan, Decimal initialInterest, Decimal initialMonitoringFee, Decimal pmtValue){    
        System.debug('LoanScheduler.generateSchedule');
        List<Repayment_Schedule__c> theRepaymentSchedule = new List<Repayment_Schedule__c>(); 
        Decimal interestRate = 0;
        switch on theLoan.Loan_Product__r.Interest_Rate_Source__c {
            when 'Fixed Interest', null {
                if (theLoan.Interest_Rate__c != null) interestRate = theLoan.Interest_Rate__c;
            }
            when 'Variable Interest' {
                List<Interest_Rate__c> irList = [
                    SELECT Rate__c
                    FROM Interest_Rate__c
                    WHERE Interest_Rate_Source__c = :theLoan.Loan_Product__r.Interest_Reference_Rate__c
                        AND Date__c <= :theLoan.Disbursement_Date__c
                    ORDER BY Date__c DESC
                    LIMIT 1
                ];
                if (!irList.isEmpty()) {
                    interestRate += irList[0].Rate__c;
                    if (theLoan.Variable_Interest_Spread__c != null) 
                        interestRate += theLoan.Variable_Interest_Spread__c;
                    if (theLoan.Loan_Product__r.Minimum_Interest_Bandwidth__c > interestRate) 
                        interestRate = theLoan.Loan_Product__r.Minimum_Interest_Bandwidth__c;
                    if (theLoan.Loan_Product__r.Maximum_Interest_Bandwidth__c < interestRate) 
                        interestRate = theLoan.Loan_Product__r.Maximum_Interest_Bandwidth__c;
                } else {
                    throw new AuraHandledException(System.Label.sfims.error_message_26);
                }
            }
        }
        
        if (!theLoan.Open_Ended_Loan__c) {
            // standard loan recalculation
            
            // only continue if all required fields are filled in    
            if (theLoan.Number_of_Instalments__c > 0 
                && theLoan.Repayment_Frequency__c > 0 
                && theLoan.Repayment_Frequency_Unit__c != null 
                && theLoan.Grace_Period_Type__c != null 
                && theLoan.Capitalized_Amount__c > 0 
                && theLoan.First_Repayment_Date__c != null
                && theLoan.Disbursement_Date__c != null)
            {
            
                switch on theLoan.Grace_Period_Type__c {
                    when 'Interest Rollup' {
                        List<Repayment_Schedule__c> graceRS = LoanScheduler.createRepaymentSchedules(
                            theLoan, 
                            interestRate,
                            initialInterest,
                            initialMonitoringFee,
                            pmtValue, 
                            theLoan.Number_of_Grace_Periods__c.intValue()
                        );
                        Decimal interestRollup = 0;
                        Integer listSize = graceRS.size();
                        for (Integer i = 0; i < listSize; i++) {
                            Repayment_Schedule__c rs = graceRS[i];
                            rs.Status__c = 'Grace';
                            interestRollup += rs.Interest_Expected_Standard_Loan__c;
                            rs.Interest_Charge__c = rs.Interest_Expected_Standard_Loan__c;
                            rs.Interest_Expected_Standard_Loan__c = 0;
                            theRepaymentSchedule.add(rs);
                        }
                        // System.debug(interestRollup);
                        theRepaymentSchedule.addAll(LoanScheduler.createRepaymentSchedules(
                            theLoan, 
                            interestRate,
                            initialInterest,
                            initialMonitoringFee,
                            pmtValue, 
                            theLoan.Number_of_Instalments__c.intValue(), 
                            interestRollup, 
                            theLoan.Number_of_Grace_Periods__c.intValue() + 1, 
                            graceRS[graceRS.size() - 1].Due_Date__c
                        ));
                    }
                    when else {
                        theRepaymentSchedule.addAll(LoanScheduler.createRepaymentSchedules(theLoan, interestRate, initialInterest, initialMonitoringFee,pmtValue));
                    }
                }

            } else {
                // optionally add code to report missing data
                // theLoan.addError('Some of required fields are not populated');
            }
        } else {
            // open ended loan recalculation
            if (theLoan.Capitalized_Amount__c > 0) {
                Repayment_Schedule__c repayment = new Repayment_Schedule__c(
                    Loan__c = theLoan.Id,
                    Status__c = 'Pending',
                    Interest_Rate__c = interestRate,
                    Principal_Expected__c = theLoan.Capitalized_Amount__c - theLoan.Capitalized_Fee_Amount__c,
                    Interest_Expected_On_Last_Paid_Date__c = 0,
                    Interest_Paid__c = 0,
                    Principal_Paid__c = 0,
                    Fees_Paid__c = 0
                );
                // set fees expected for a loan with the 'Capitalized' setup fee charging method
                if (theLoan.Capitalized_Fee_Amount__c > 0) {
                    repayment.Fees_Expected__c = theLoan.Capitalized_Fee_Amount__c;
                    repayment.Setup_Fees_Expected__c = theLoan.Capitalized_Fee_Amount__c;
                } else {
                    repayment.Fees_Expected__c = 0;
                    repayment.Setup_Fees_Expected__c = 0;
                }
                theRepaymentSchedule.add(repayment);
            }
        }
        
        if (theLoan.Setup_Fee_Charging_Method__c == 'Paid Up Front (scheduled)') {
            theRepaymentSchedule.add(0, createFeesRepaymentSchedule(theLoan.Id, theLoan.Disbursement_Date__c, theLoan.Setup_Fee_Expected__c));
        }
        return theRepaymentSchedule;
    }

    public static List<Repayment_Schedule__c> createRepaymentSchedules(Investment__c theLoan, Decimal interestRate, Decimal initialInterest, Decimal initialMonitoringFee, Decimal pmtValue) {
        return LoanScheduler.createRepaymentSchedules(theLoan, interestRate, initialInterest, initialMonitoringFee, pmtValue, theLoan.Number_of_Instalments__c.intValue());
    }

    public static List<Repayment_Schedule__c> createRepaymentSchedules(Investment__c theLoan, Decimal interestRate, Decimal initialInterest, Decimal initialMonitoringFee ,Decimal pmtValue, Integer periods) {
        return LoanScheduler.createRepaymentSchedules(theLoan, interestRate, initialInterest, initialMonitoringFee, pmtValue, periods, 0, 1, null);
    }

    public static List<Repayment_Schedule__c> createRepaymentSchedules(Investment__c theLoan, Decimal interestRate, Decimal initialInterest, Decimal initialMonitoringFee, Decimal pmtValue, Integer periods, Decimal interestRollup, Integer startNumber, Date start) {
        System.debug('LoanScheduler.createRepaymentSchedules');
        List<Repayment_Schedule__c> theRepaymentSchedule = new List<Repayment_Schedule__c>();
        Date dueDate;
        Decimal principalToDate = 0;
        Decimal monitoringFeeRate = 0;
        Decimal expectedPrincipalBalance = theLoan.Capitalized_Amount__c - theLoan.Capitalized_Fee_Amount__c;
        Integer interestPeriodNumber = 0;
        Integer monitoringFeePeriodNumber = 0;
        Boolean initialPMT = pmtValue != null;
        //Loop through instalments for this loan record to produce loan schedule
        // calculate pmt
        Integer numberOfGracePeriods = 0;
        if (theLoan.Number_of_Grace_Periods__c != null) numberOfGracePeriods = theLoan.Number_of_Grace_Periods__c.intValue();
        if (theLoan.Monitoring_Fee_Percentage__c != null) monitoringFeeRate = theLoan.Monitoring_Fee_Percentage__c;
        if (!initialPMT) pmtValue = LoanUtils.calculatePMT(theLoan.Number_of_Instalments__c.intValue(),theLoan.Repayment_Frequency__c.intValue(), theLoan.Repayment_Frequency_Unit__c, numberOfGracePeriods, theLoan.Grace_Period_Type__c, (theLoan.Capitalized_Amount__c + interestRollup), interestRate);
        Utility.InstalmentAmount = pmtValue;
        // System.debug(Utility.InstalmentAmount);
        // some helper variables for period 0 calculations
        Decimal periodsPerYear = LoanUtils.getPeriodsPerYear(theLoan.Repayment_Frequency__c.intValue(),theLoan.Repayment_Frequency_Unit__c);                   
        
        // go through all instalments and create repayment period records
        for (Integer periodNumber = startNumber; periodNumber <= periods; periodNumber++){ 
            Decimal principalPlusInterest = 0;
            Decimal interest = 0;
            Decimal principal = 0;
            Decimal setupFees = 0;
            Decimal monitoringFees = 0;
            
            Repayment_Schedule__c repayment = new Repayment_Schedule__c(Loan__c = theLoan.Id);
            repayment.Status__c = 'Pending';

            // some total counters for correcting the last periods
            Decimal totalPrincipal = 0;
                    
            Boolean fullGrace = false;
            Boolean adminFeePeriod = true;
            Boolean principalPeriod = true;
            Boolean interestPeriod = true;
            
            if (theLoan.Number_of_Grace_Periods__c >= periodNumber){
                switch on theLoan.Grace_Period_Type__c {
                    when 'Full' {
                        fullGrace = true;
                        adminFeePeriod = false;
                        principalPeriod = false;
                        interestPeriod = false;
                        repayment.Status__c = 'Grace';
                    }
                    when 'Admin' {
                        principalPeriod = false;
                        interestPeriod = false;
                        repayment.Status__c = 'Grace';
                    }
                    when 'Interest', 'Interest Rollup' {
                        adminFeePeriod = false;
                        principalPeriod = false;
                        repayment.Status__c = 'Grace';
                    }
                    when else {
                        // no grace.
                    }
                }
            }

            Date startDate;
            if (periodNumber == 1) {
                startDate = theLoan.Disbursement_Date__c;
                dueDate = theLoan.First_Repayment_Date__c;
            } else if (periodNumber > 1){
                if (dueDate == null) dueDate = start;
                startDate = dueDate;
                switch on theLoan.Repayment_Frequency_Unit__c {
                    when 'Days' {
                        dueDate = theLoan.First_Repayment_Date__c.addDays(((periodNumber-1)*theLoan.Repayment_Frequency__c).intValue());
                    }
                    when 'Weeks' {
                        dueDate = theLoan.First_Repayment_Date__c.addDays((7*(periodNumber-1)*theLoan.Repayment_Frequency__c).intValue());  
                    }
                    when 'Months' {
                        dueDate = theLoan.First_Repayment_Date__c.addMonths(((periodNumber-1)*theLoan.Repayment_Frequency__c).intValue());
                    }
                    when 'Years' {
                        dueDate = theLoan.First_Repayment_Date__c.addYears(((periodNumber-1)*theLoan.Repayment_Frequency__c).intValue());
                    }
                } 
            }
            
            repayment.Start_Date__c = startDate;
            repayment.Theoretical_Due_Date__c = dueDate;

            // Adjust due date according to selected non-working days rescheduling option
            switch on theLoan.Non_Working_Days_Rescheduling__c {
                when 'Move ahead to next working day' {
                    if (!BusinessHours.isWithin(Utility.businessHoursId, dueDate)) {
                        dueDate = BusinessHours.nextStartDate(Utility.businessHoursId, dueDate).date();
                    }
                }
                when 'Move backward to previous working day' {
                    while (!BusinessHours.isWithin(Utility.businessHoursId, dueDate)) {
                        dueDate = dueDate.addDays(-1);
                    }
                }
            }
                    
            repayment.Due_Date__c = dueDate;
    
            // set interest and monitoring fees
            if (interestPeriod || (!fullGrace && monitoringFeeRate > 0)) {
                // perform calculations for 1%
                Decimal onePercentPerPeriod = 0;
                Integer days = 0;
                
                switch on theLoan.Day_Count_Convention__c {
                    when '30/360', null, '' {
                        onePercentPerPeriod = 0.01 / periodsPerYear;
                        System.debug(onePercentPerPeriod);
                        // correct the interest if the first period is not exactly 1 term length
                        if (periodNumber == 1) {
                            Date theoreticalTermStartDate;
                            switch on theLoan.Repayment_Frequency_Unit__c {
                                when 'Days' {
                                    theoreticalTermStartDate = theLoan.First_Repayment_Date__c.addDays((-1*theLoan.Repayment_Frequency__c).intValue());
                                }
                                when 'Weeks' {
                                    theoreticalTermStartDate = theLoan.First_Repayment_Date__c.addDays((7*-1*theLoan.Repayment_Frequency__c).intValue());   
                                }
                                when 'Months' {
                                    theoreticalTermStartDate = theLoan.First_Repayment_Date__c.addMonths((-1*theLoan.Repayment_Frequency__c).intValue());
                                }
                                when 'Years' {
                                    theoreticalTermStartDate = theLoan.First_Repayment_Date__c.addYears((-1*theLoan.Repayment_Frequency__c).intValue());
                                }
                            }

                            if (theLoan.Disbursement_Date__c != theoreticalTermStartDate) {
                                onePercentPerPeriod += 0.01 / 365 * theLoan.Disbursement_Date__c.daysBetween(theoreticalTermStartDate);
                            }
                        }
                    }
                    when 'Actual/365' {

                        onePercentPerPeriod = 0.01 / 365 * startDate.daysBetween(dueDate);
                        
                    }
                    when 'Actual/365L' {

                        if (startDate.year() == dueDate.year()) {
                            Integer daysInYear = 0;
                            if (Date.isLeapYear(dueDate.year())) {
                                daysInYear = 366;
                            } else {
                                daysInYear = 365;
                            }

                            onePercentPerPeriod = 0.01 / daysInYear * startDate.daysBetween(dueDate);

                        } else {
                            for (Integer i = 0; i <= (dueDate.year() - startDate.year()); i++) {  // 2020-2019 = 1  previousdd 1/12/2019 duedate 1/1/2020
                                
                                Date firstDate;
                                Date endDate;

                                if (i == 0 ) {
                                    firstDate = startDate; // 1-12-2019
                                } else if (i > 0) {
                                    firstDate = Date.newinstance(startDate.year() + i, 1, 1); // 1-1-2020
                                } 
                                
                                if (i == (dueDate.year() - startDate.year())){
                                    endDate = dueDate; // 1-1-2020
                                } else if (i < (dueDate.year() - startDate.year())) {
                                    //endDate = Date.newinstance(startDate.year() + i, 12, 31); // 31-12-2019
                                    endDate = Date.newinstance(dueDate.year() + i, 1, 1); // 1-1-2020
                                }

                                Integer daysInYear = 0;
                                if (Date.isLeapYear(firstDate.year())) {
                                    daysInYear = 366;
                                } else {
                                    daysInYear = 365;
                                }

                                onePercentPerPeriod += 0.01 / daysInYear * firstDate.daysBetween(endDate) ; // 8% / 365 + 30

                            }
                        }
                    }
                }

                // set interest amount
                if (interestPeriod && interestRate > 0) {
                    interest = ((theLoan.Capitalized_Amount__c - principalToDate) * onePercentPerPeriod * interestRate).setScale(2);
                    if (interestPeriodNumber == 0) interest += initialInterest;
                    interestPeriodNumber++;
                }
                
                if (monitoringFeeRate > 0) {
                    monitoringFees = ((theLoan.Capitalized_Amount__c - theLoan.Capitalized_Fee_Amount__c) * onePercentPerPeriod * monitoringFeeRate).setScale(2);
                    if (monitoringFeePeriodNumber == 0) monitoringFees += initialMonitoringFee;
                    monitoringFeePeriodNumber++;
                }
            }

            // set principal
            if (principalPeriod && interestPeriod){
                                                                                        
                if (periodNumber != periods || (periodNumber == periods && initialPMT && expectedPrincipalBalance > pmtValue)){
                    if (pmtValue != null) principalPlusInterest = pmtValue;
                    
                    if (interestRollup > 0 && principalPlusInterest - interest > 0) {
                        if (interestRollup > principalPlusInterest - interest) {
                            interestRollup -= principalPlusInterest - interest;
                            interest += principalPlusInterest - interest;
                        } else {
                            interest += interestRollup;
                            interestRollup = 0;
                        }
                    }
                    principal = principalPlusInterest - interest;
                    if (periodNumber == periods && initialPMT && expectedPrincipalBalance > pmtValue) periods++;
                } else {
                    // if this is the last principal period, correct rounding discrepancies
                    principal = theLoan.Capitalized_Amount__c - principalToDate;
                    principalPlusInterest = principal + interest;
                }
            }                     

            principalToDate += principal;

            // when setting the principal on the schedule, 
            // it needs to be split up into principal and fee 
            // for the 'Capitalized' type of the Setup Fee Charging Method
            if (theLoan.Setup_Fee_Charging_Method__c == 'Capitalized') {
                if (periodNumber != periods) {
                    setupFees = (principal * (theLoan.Capitalized_Fee_Amount__c/theLoan.Capitalized_Amount__c)).setScale(2);
                    principal -= setupFees;    
                } else {
                    setupFees = principal - expectedPrincipalBalance;
                    principal -= setupFees;
                }         
            }
            
            expectedPrincipalBalance -= principal;

            repayment.Principal_Expected__c = principal;
            repayment.Interest_Expected_Standard_Loan__c = interest;
            repayment.Fees_Expected__c = setupFees + monitoringFees;
            repayment.Setup_Fees_Expected__c = setupFees;
            repayment.Monitoring_Fees_Expected__c = monitoringFees;
            repayment.Interest_Paid__c = 0;
            repayment.Principal_Paid__c = 0;
            repayment.Fees_Paid__c = 0;
            repayment.Interest_Rate__c = interestRate;
            repayment.Monitoring_Fee_Percentage__c = theLoan.Monitoring_Fee_Percentage__c;
            repayment.Expected_Principal_Balance__c = expectedPrincipalBalance;
            repayment.Principal_Balance__c = theLoan.Capitalized_Amount__c - theLoan.Capitalized_Fee_Amount__c;
            theRepaymentSchedule.add(repayment);
        }

        return theRepaymentSchedule;
    }

    public static Repayment_Schedule__c createFeesRepaymentSchedule(String loanId, Date dueDate, Decimal setupFeesExpected) {
        return new Repayment_Schedule__c(
            Loan__c = loanId,
            Status__c = 'Fee',
            Due_Date__c = dueDate,
            Principal_Expected__c = 0,
            Interest_Expected_Standard_Loan__c = 0,
            Fees_Expected__c = setupFeesExpected,
            Setup_Fees_Expected__c = setupFeesExpected,
            Interest_Paid__c = 0,
            Principal_Paid__c = 0,
            Fees_Paid__c = 0
        );
    }
}