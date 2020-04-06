public with sharing class VariableInterestRateBatch implements Database.Batchable<sObject>, Database.Stateful {
    // this batch defines which loans should be recalculated

    public final Date currentDate;
    
    public VariableInterestRateBatch(Date entryDate) {
        this.currentDate = entryDate;
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Variable_Interest_Spread__c, Open_Ended_Loan__c, Disbursement_Date__c, Loan_Product__c,
                Loan_Product__r.Interest_Rate_Review_Frequency__c, Loan_Product__r.Interest_Reference_Rate__c,
                Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c,
                Loan_Product__r.Default_Interest_Rate__c, Grace_Period_Type__c,
                (
                    SELECT Start_Date__c, Due_Date__c
                    FROM Repayment_Schedules__r
                    WHERE (Start_Date__c < :currentDate OR Start_Date__c = null) AND Active__c = true AND Migration__c = false AND Status__c != 'Fee'
                    ORDER BY Start_Date__c ASC
                )
            FROM Investment__c
            WHERE Status__c = 'Active' AND Loan_Product__r.Interest_Rate_Source__c = 'Variable Interest'
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Investment__c> scope) {
        // System.debug(scope[0]);
        
        Investment__c theLoan = scope[0];
        List<Repayment_Schedule__c> rsToUpdate = VariableInterestRateBatch.processRepaymentSchedules(theLoan, currentDate);
        
        if (!rsToUpdate.isEmpty()) {
            Savepoint sp = Database.setSavepoint();
            Loan_Event__c le = new Loan_Event__c(
                Event_Date__c = currentDate,
                Investment__c = theLoan.Id,
                Loan_Event_Type__c = 'Interest Rate Change',
                Loan_Product__c = theLoan.Loan_Product__c
            );
            DMLManager.insertAsSystem(new List<Loan_Event__c>{le});
            
            if (!theLoan.Open_Ended_Loan__c) {
                DMLManager.updateAsUser(rsToUpdate);
                LoanTransactionProcessor.processLoanTransactions(new Set<Id>{theLoan.Id});
            } else {
                Map<String, String> result = RecalculateOpenEndedLoan.processOpenEndedLoan(theLoan.Id);
                // System.debug(result);
                if (result.containsKey('error')) {
                    Database.rollback(sp);
                    throw new ApplicationException(result.get('error'));
                }
            }
        }
    }

    public void finish(Database.BatchableContext BC) {
        Database.executeBatch(new RecalculateInterestRollupLoansBatch(System.today()), 1);
    }

    public static List<Repayment_Schedule__c> processRepaymentSchedules(Investment__c theLoan, Date currentDate) {
        List<Repayment_Schedule__c> rsToUpdate = new List<Repayment_Schedule__c>();
        if (!theLoan.Repayment_Schedules__r.isEmpty()) {
            Repayment_Schedule__c rs = theLoan.Repayment_Schedules__r[0];
            if (theLoan.Open_Ended_Loan__c) {
                rs.Start_Date__c = theLoan.Disbursement_Date__c;
                rs.Due_Date__c = currentDate;
            }

            // check if today is a day when the loan should be recalculated
            Boolean toRecalculate = false;
            Date startDate;
            Date endDate;

            // System.debug(theLoan.Loan_Product__r.Interest_Rate_Review_Frequency__c);
            switch on theLoan.Loan_Product__r.Interest_Rate_Review_Frequency__c {
                when 'Daily' {
                    toRecalculate = true;
                    rs = theLoan.Repayment_Schedules__r[theLoan.Repayment_Schedules__r.size()-1];
                    startDate = rs.Start_Date__c;
                    endDate = rs.Due_Date__c;
                }
                when 'Monthly' {
                    // System.debug(rs.Start_Date__c.day());
                    // System.debug(currentDate.day());
                    if (rs.Start_Date__c.day() == currentDate.day()) {
                        toRecalculate = true;
                        startDate = currentDate.addMonths(-1);
                        endDate = currentDate;
                    }
                }
                when 'Quarterly' {
                    if (rs.Start_Date__c.day() == currentDate.day()) {
                        Decimal result = Decimal.valueOf(currentDate.month() - rs.Start_Date__c.month()).divide(3, 2);
                        if (result.intValue() == result) {
                            toRecalculate = true;
                            startDate = currentDate.addMonths(-3);
                            endDate = currentDate;
                        }
                    }
                }
                when 'Yearly' {
                    if (rs.Start_Date__c.day() == currentDate.day() && rs.Start_Date__c.month() == currentDate.month()) {
                        toRecalculate = true;
                        startDate = currentDate.addYears(-1);
                        endDate = currentDate;
                    }
                }
            }
            
            if (toRecalculate) {
                // check if new Interest Rates were added for the current period
                List<Interest_Rate__c> currentInterestRates = [
                    SELECT Date__c, Rate__c
                    FROM Interest_Rate__c
                    WHERE Interest_Rate_Source__c = :theLoan.Loan_Product__r.Interest_Reference_Rate__c
                        AND Date__c >= :startDate AND Date__c < :endDate
                    ORDER BY Date__c ASC
                ];

                if (theLoan.Loan_Product__r.Interest_Rate_Review_Frequency__c == 'Daily') {
                    Boolean toUpdate = false;
                    for (Integer i = currentInterestRates.size() - 1; i >= 0; i--) {
                        Interest_Rate__c rate = currentInterestRates[i];
                        if (rate.Date__c == currentDate.addDays(-1)) {
                            toUpdate = true;
                            break;
                        }
                    }
                    if (!toUpdate) currentInterestRates.clear();
                }

                if (!currentInterestRates.isEmpty()) {
                    if (theLoan.Open_Ended_Loan__c) {
                        rsToUpdate.add(rs);
                        return rsToUpdate;
                    } else {
                        // determine weighted average interest rate
                        Decimal interestRateOnStartDate = 0;
                        if (currentInterestRates[0].Date__c != startDate) {
                            Interest_Rate__c previousInterestRate = [
                                SELECT Date__c, Rate__c
                                FROM Interest_Rate__c
                                WHERE Interest_Rate_Source__c = :theLoan.Loan_Product__r.Interest_Reference_Rate__c
                                    AND Date__c < :startDate
                                ORDER BY Date__c DESC
                                LIMIT 1
                            ];
                            interestRateOnStartDate = previousInterestRate.Rate__c;
                        } else {
                            interestRateOnStartDate = currentInterestRates[0].Rate__c;
                            // currentInterestRates.remove(0);
                        }
                        System.debug(interestRateOnStartDate);

                        List<Repayment_Schedule__c> repaymentSchedules = [
                            SELECT Interest_Rate__c, Interest_Expected_Standard_Loan__c, Start_Date__c, Due_Date__c, Interest_Charge__c, Status__c
                            FROM Repayment_Schedule__c
                            WHERE Loan__c =: theLoan.Id
                                AND Due_Date__c > :startDate AND Active__c = true AND Migration__c = false AND Status__c != 'Fee'
                            ORDER BY Start_Date__c ASC
                        ];

                        Integer currentRate = 0;
                        for (Repayment_Schedule__c tempRS : repaymentSchedules) {
                            Date startInterestRateDate = tempRS.Start_Date__c;
                            Double expression = 0;
                            for (Integer i = currentRate; i < currentInterestRates.size(); i++) {
                                Interest_Rate__c rate = currentInterestRates[i];
                                if (rate.Date__c < tempRS.Due_Date__c) {
                                    expression += interestRateOnStartDate * startInterestRateDate.daysBetween(rate.Date__c);
                                    startInterestRateDate = rate.Date__c;
                                    interestRateOnStartDate = rate.Rate__c;
                                    currentRate++;
                                }
                            }
                            expression += interestRateOnStartDate * startInterestRateDate.daysBetween(tempRS.Due_Date__c);
                            // System.debug(expression);
                            Decimal weightedAverageInterestRate = expression / tempRS.Start_Date__c.daysBetween(tempRS.Due_Date__c);
                            // System.debug(weightedAverageInterestRate);
                            
                            // add variable interest spread
                            if (theLoan.Variable_Interest_Spread__c != null) {
                                weightedAverageInterestRate += theLoan.Variable_Interest_Spread__c;
                                // System.debug(weightedAverageInterestRate);
                            }

                            // System.debug(theLoan.Loan_Product__r.Maximum_Interest_Bandwidth__c);
                            // System.debug(theLoan.Loan_Product__r.Minimum_Interest_Bandwidth__c);
                            
                            // check if weighted average interest rate is out of allowed range
                            if (theLoan.Loan_Product__r.Maximum_Interest_Bandwidth__c != null
                                && weightedAverageInterestRate > theLoan.Loan_Product__r.Maximum_Interest_Bandwidth__c)
                                weightedAverageInterestRate = theLoan.Loan_Product__r.Maximum_Interest_Bandwidth__c;
                            if (theLoan.Loan_Product__r.Minimum_Interest_Bandwidth__c != null
                                && weightedAverageInterestRate < theLoan.Loan_Product__r.Minimum_Interest_Bandwidth__c)
                                weightedAverageInterestRate = theLoan.Loan_Product__r.Minimum_Interest_Bandwidth__c;

                            System.debug(weightedAverageInterestRate);
                            if (tempRS.Interest_Rate__c != weightedAverageInterestRate) {
                                // repayment schedule should be updated
                                if (theLoan.Grace_Period_Type__c == 'Interest Rollup' && tempRS.Status__c == 'Grace') tempRS.Interest_Charge__c *= weightedAverageInterestRate / tempRS.Interest_Rate__c;
                                else tempRS.Interest_Expected_Standard_Loan__c *= weightedAverageInterestRate / tempRS.Interest_Rate__c;
                                tempRS.Interest_Rate__c = weightedAverageInterestRate;
                                rsToUpdate.add(tempRS);
                            }
                            // System.debug('-----------------------------------------');
                        }
                    }
                }
            }
        }

        return rsToUpdate;
    }

}