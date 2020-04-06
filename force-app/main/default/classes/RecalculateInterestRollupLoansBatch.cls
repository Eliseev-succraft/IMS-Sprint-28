public with sharing class RecalculateInterestRollupLoansBatch implements Database.Batchable<SObject>, Database.Stateful {
    // this batch checks if grace period is over for loans with the 'Interest Rollup' Grace Period Type and a variable interest rate
    // and if yes, reschedule these loans

    public final Date currentDate;
    
    public RecalculateInterestRollupLoansBatch(Date entryDate) {
        this.currentDate = entryDate;
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Loan__c
            FROM Repayment_Schedule__c
            WHERE Start_Date__c = :currentDate AND Active__c = true AND Migration__c = false 
                AND Status__c NOT IN ('Fee', 'Grace', 'Planned', 'Defaulted')
                AND Loan__r.Status__c = 'Active' AND Loan__r.Grace_Period_Type__c = 'Interest Rollup'
                AND Loan__r.Loan_Product__r.Interest_Rate_Source__c = 'Variable Interest' 
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Repayment_Schedule__c> scope) {
        // System.debug(scope[0]);
        Id loanId = scope[0].Loan__c;
        
        Map<String, List<SObject>> resultMap = RecalculateInterestRollupLoansBatch.updateRepaymentSchedules(loanId, currentDate);
        if (resultMap.containsKey('loanEvents')) {
            DMLManager.insertAsSystem(new List<Loan_Event__c>{(Loan_Event__c)resultMap.get('loanEvents')[0]});
        }
        if (resultMap.containsKey('repaymentSchedules')) {    
            DMLManager.updateAsUser(resultMap.get('repaymentSchedules'));
            LoanTransactionProcessor.processLoanTransactions(new Set<Id>{loanId});
        }
    }

    public void finish(Database.BatchableContext BC) {
        
    }

    public static Map<String, List<SObject>> updateRepaymentSchedules(Id loanId, Date currentDate) {
        System.debug('RecalculateInterestRollupLoansBatch.updateRepaymentSchedules');
        Map<String, List<SObject>> returnMap = new Map<String, List<SObject>>();
        
        List<Repayment_Schedule__c> previousRS = [
            SELECT Id, Name
            FROM Repayment_Schedule__c
            WHERE Start_Date__c < :currentDate AND Active__c = true AND Migration__c = false 
                AND Status__c NOT IN ('Fee', 'Grace', 'Planned', 'Defaulted') AND Loan__c = :loanId
            LIMIT 1 
        ];
        System.debug(previousRS);
        
        List<Repayment_Schedule__c> rsToUpdate = new List<Repayment_Schedule__c>();
        Loan_Event__c newLoanEvent = new Loan_Event__c();
        if (previousRS.isEmpty()) {
            Investment__c theLoan = [
                SELECT Number_of_Instalments__c, Repayment_Frequency__c, Repayment_Frequency_Unit__c, Amount__c,
                    Number_of_Grace_Periods__c, Grace_Period_Type__c, Capitalized_Amount__c, Capitalized_Fee_Amount__c,
                    Setup_Fee_Charging_Method__c, Setup_Fee_Expected__c, Disbursement_Date__c, First_Repayment_Date__c,
                    Open_Ended_Loan__c, Interest_Rate__c, Day_Count_Convention__c, Variable_Interest_Spread__c,
                    Loan_Product__r.Interest_Rate_Source__c, Loan_Product__r.Interest_Reference_Rate__c, 
                    Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c, 
                    Loan_Product__c, Non_Working_Days_Rescheduling__c, Monitoring_Fee_Percentage__c,
                    (
                        SELECT Principal_Expected__c, Interest_Expected_Standard_Loan__c, Fees_Expected__c, 
                            Interest_Rate__c, Expected_Principal_Balance__c, Principal_Balance__c
                        FROM Repayment_Schedules__r
                        WHERE Active__c = true AND Migration__c = false AND Status__c != 'Grace'
                        ORDER BY Due_Date__c
                     ),
                    (
                        SELECT Repayment_Frequency__c, Repayment_Frequency_Unit__c, Variable_Interest_Spread__c, 
                            Number_of_Instalments__c, Number_of_Grace_Periods__c, Grace_Period_Type__c, Amount__c
                        FROM Loan_Events__r
                        WHERE Loan_Event_Type__c IN ('Disbursement', 'Reschedule') AND Event_Date__c < :currentDate
                        ORDER BY Event_Date__c DESC
                        LIMIT 1
                    ) 
                FROM Investment__c
                WHERE Id = :loanId
            ];

            if (!theLoan.Loan_Events__r.isEmpty() && theLoan.Loan_Events__r[0].Grace_Period_Type__c == 'Interest Rollup') {
                Loan_Event__c le = theLoan.Loan_Events__r[0];
                // use actual loan parameters from the latest loan event
                theLoan.Capitalized_Amount__c = le.Amount__c;
                theLoan.Repayment_Frequency__c = le.Repayment_Frequency__c;
                theLoan.Repayment_Frequency_Unit__c = le.Repayment_Frequency_Unit__c;
                theLoan.Number_of_Instalments__c = le.Number_of_Instalments__c;
                theLoan.Number_of_Grace_Periods__c = le.Number_of_Grace_Periods__c;
                theLoan.Variable_Interest_Spread__c = le.Variable_Interest_Spread__c;

                Decimal interestRate = 0;    
                List<Interest_Rate__c> irList = [
                    SELECT Rate__c
                    FROM Interest_Rate__c
                    WHERE Interest_Rate_Source__c = :theLoan.Loan_Product__r.Interest_Reference_Rate__c
                        AND Date__c <= :currentDate
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


                    AggregateResult[] results = [
                        SELECT SUM(Interest_Charge__c)interestRollup
                        FROM Repayment_Schedule__c
                        WHERE Loan__c = :loanId AND Active__c = true AND Migration__c = false AND Status__c = 'Grace' 
                    ];

                    List<Repayment_Schedule__c> oldRSs = theLoan.Repayment_Schedules__r;
                    List<Repayment_Schedule__c> newRSs = LoanScheduler.createRepaymentSchedules(
                        theLoan, 
                        interestRate,
                        0,
                        0,
                        null, 
                        theLoan.Number_of_Instalments__c.intValue(), 
                        (Decimal)results[0].get('interestRollup'), 
                        theLoan.Number_of_Grace_Periods__c.intValue() + 1, 
                        currentDate
                    );
                    if (oldRSs.size() == newRSs.size()) {
                        Integer rsSize = oldRSs.size();
                        for (Integer i = 0; i < rsSize; i++) {
                            Repayment_Schedule__c oldRS = oldRSs[i];
                            Repayment_Schedule__c newRS = newRSs[i];
                            
                            oldRS.Principal_Expected__c = newRS.Principal_Expected__c;
                            oldRS.Interest_Expected_Standard_Loan__c = newRS.Interest_Expected_Standard_Loan__c;
                            oldRS.Fees_Expected__c = newRS.Fees_Expected__c;
                            oldRS.Interest_Rate__c = newRS.Interest_Rate__c;
                            oldRS.Expected_Principal_Balance__c = newRS.Expected_Principal_Balance__c;
                            oldRS.Principal_Balance__c = newRS.Principal_Balance__c;

                            rsToUpdate.add(oldRS);
                        }
                        returnMap.put('repaymentSchedules', rsToUpdate);
                        
                        newLoanEvent.Event_Date__c = currentDate;
                        newLoanEvent.Investment__c = loanId;
                        newLoanEvent.Loan_Event_Type__c = 'Interest Rollup Recalculation';
                        newLoanEvent.Loan_Product__c = theLoan.Loan_Product__c;
                        returnMap.put('loanEvents', new List<Loan_Event__c>{newLoanEvent});
                    } else {
                        // error
                    }
                } else {
                    // error
                }
            } else {
                // error
            }
        }

        return returnMap;
    }
}