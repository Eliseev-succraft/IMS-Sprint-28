public with sharing class LoanHealthCheckController {
    
    @AuraEnabled
    public static List<String> getLoanData(Id loanId) {
        // Check to see whether the caller has access to this information.
        if (!Repayment_Schedule__c.SObjectType.getDescribe().isAccessible()
            || !Transaction__c.SObjectType.getDescribe().isAccessible())
        {
            throw new AuraHandledException(System.Label.sfims.error_message_24);
        }

        Investment__c theLoan = [
            SELECT Principal_Remaining__c, Open_Ended_Loan__c, Status__c, Recalculation_Status__c,
                Interest_Expected_Open_Ended_Loan__c, Late_Repayment_Fees_Expected0__c,
            (
                SELECT Fees_Paid__c, Interest_Paid__c, Late_Repayment_Fees_Paid__c, Principal_Paid__c, 
                    Interest_Expected_Open_Ended_Loan__c, Late_Repayment_Fees_Expected0__c, 
                    Expected_Principal_Balance__c, Principal_Balance__c, Due_Date__c, Active__c
                FROM Repayment_Schedules__r
                ORDER BY Due_Date__c DESC
            ),
            (
                SELECT Fee_Amount__c, Interest_Amount__c, Late_Repayment_Fee_Amount__c, Principal_Amount__c,
                    Transaction_Date__c, Type__c, Status__c, Principal_Balance__c
                FROM Transactions__r
                ORDER BY Transaction_Date__c DESC, Name DESC
            )
            FROM Investment__c
            WHERE Id =: loanId
        ];

        return LoanHealthCheckController.getIssues(theLoan);

    }

    public static List<String> getIssues(Investment__c theLoan) {
        List<String> issues = new List<String>();
        List<Investment__c> loansToUpdate = new List<Investment__c>();
        switch on theLoan.Recalculation_Status__c {
            when 'Pending Recalculation' {
                issues.add(System.Label.sfims.health_check_1);
            }
            when 'In Progress' {
                issues.add(System.Label.sfims.health_check_2);
            }
            when 'Failed' {
                issues.add(System.Label.sfims.health_check_3);
            }
        } 
        
        Decimal feesPaid = 0;
        Decimal interestPaid = 0;
        Decimal lateRepaymentFeesPaid = 0;
        Decimal principalPaid = 0;
        Decimal interestExpected = 0;
        Decimal lateRepaymentFeesExpected = 0;
        Decimal feesAmount = 0;
        Decimal interestAmount = 0;
        Decimal lateRepaymentFeesAmount = 0;
        Decimal principalAmount = 0;
        
        Date dueDate;
        Repayment_Schedule__c lastRepaymentSchedule;
        List<Transaction__c> latePlannedDisbursementTansactions = new List<Transaction__c>();

        if (!theLoan.Repayment_Schedules__r.isEmpty()) {
            for (Repayment_Schedule__c rs : theLoan.Repayment_Schedules__r) {
                if (rs.Fees_Paid__c != null) feesPaid += rs.Fees_Paid__c;
                if (rs.Interest_Paid__c != null) interestPaid += rs.Interest_Paid__c;
                if (rs.Late_Repayment_Fees_Paid__c != null) lateRepaymentFeesPaid += rs.Late_Repayment_Fees_Paid__c;
                if (rs.Principal_Paid__c != null) principalPaid += rs.Principal_Paid__c;

                if (theLoan.Open_Ended_Loan__c) {
                    if (rs.Interest_Expected_Open_Ended_Loan__c != null) interestExpected += rs.Interest_Expected_Open_Ended_Loan__c;
                } else {
                    if (rs.Late_Repayment_Fees_Expected0__c != null) lateRepaymentFeesExpected += rs.Late_Repayment_Fees_Expected0__c;
                }

                if (rs.Active__c && dueDate == null) {
                    dueDate = rs.Due_Date__c;
                    lastRepaymentSchedule = rs;
                }
            }
        }

        Integer numberOfDisbursements = 0;
        Integer numberOfRepayments = 0;
        if (!theLoan.Transactions__r.isEmpty()) {
            for (Transaction__c tr : theLoan.Transactions__r) {
                switch on tr.Type__c {
                    when 'Repayment' {
                        if (tr.Fee_Amount__c != null) feesAmount += tr.Fee_Amount__c;
                        if (tr.Interest_Amount__c != null) interestAmount += tr.Interest_Amount__c;
                        if (tr.Late_Repayment_Fee_Amount__c != null) lateRepaymentFeesAmount += tr.Late_Repayment_Fee_Amount__c;
                        if (tr.Principal_Amount__c != null) principalAmount += tr.Principal_Amount__c;

                        numberOfRepayments++;
                    }
                    when 'Disbursement' {
                        if (tr.Status__c == 'Planned' && tr.Transaction_Date__c < System.today()) 
                            latePlannedDisbursementTansactions.add(tr);

                        numberOfDisbursements++;
                    }
                }
            }
        }

        if (!theLoan.Repayment_Schedules__r.isEmpty()) {
            if (theLoan.Open_Ended_Loan__c) {
                if (theLoan.Interest_Expected_Open_Ended_Loan__c != interestExpected.setScale(2)) {
                    theLoan.Interest_Expected_Open_Ended_Loan__c = interestExpected.setScale(2);
                    loansToUpdate.add(theLoan);
                }
            } else {
                if (theLoan.Late_Repayment_Fees_Expected0__c != lateRepaymentFeesExpected.setScale(2)) {
                    theLoan.Late_Repayment_Fees_Expected0__c = lateRepaymentFeesExpected.setScale(2);
                    loansToUpdate.add(theLoan);
                }  
            }
        }
        
        if (feesPaid != feesAmount) issues.add(generateErrorMessageWhenPaidSumsNotEqual(System.Label.sfims.amount_type_1, feesPaid, feesAmount));
        if (interestPaid != interestAmount) issues.add(generateErrorMessageWhenPaidSumsNotEqual(System.Label.sfims.amount_type_2, interestPaid, interestAmount));
        if (lateRepaymentFeesPaid != lateRepaymentFeesAmount) 
            issues.add(generateErrorMessageWhenPaidSumsNotEqual(System.Label.sfims.amount_type_3, lateRepaymentFeesPaid, lateRepaymentFeesAmount));
        if (principalPaid != principalAmount) issues.add(generateErrorMessageWhenPaidSumsNotEqual(System.Label.sfims.amount_type_4, principalPaid, principalAmount));

        if (!latePlannedDisbursementTansactions.isEmpty()) issues.add(System.Label.sfims.health_check_4);

        if (lastRepaymentSchedule != null) {
            if (lastRepaymentSchedule.Expected_Principal_Balance__c != null 
                && lastRepaymentSchedule.Expected_Principal_Balance__c.setScale(2) != 0) 
                issues.add(System.Label.sfims.health_check_5);
            
            if (lastRepaymentSchedule.Principal_Balance__c != null 
                && lastRepaymentSchedule.Principal_Balance__c.setScale(2) != theLoan.Principal_Remaining__c)
                issues.add(System.Label.sfims.health_check_6);
        }  
        if (!theLoan.Transactions__r.isEmpty()) {
            Transaction__c lastTransaction = theLoan.Transactions__r[0];
            if (theLoan.Status__c != 'Closed - Written Off' && lastTransaction.Principal_Balance__c != null 
                && lastTransaction.Principal_Balance__c.setScale(2) != theLoan.Principal_Remaining__c)
                issues.add(System.Label.sfims.health_check_7);
        }

        if (numberOfRepayments > 0 && numberOfDisbursements == 0) issues.add(System.Label.sfims.health_check_8);
        
        if (!loansToUpdate.isEmpty()) update loansToUpdate;

        return issues;
    } 

    public static String generateErrorMessageWhenPaidSumsNotEqual(String typeOfAmount, Decimal paidOnRepaymentSchedules, Decimal paidOnTransactions) {
        
        return System.Label.sfims.part_of_health_check_1 + ' ' + typeOfAmount + ' ' + System.Label.sfims.part_of_health_check_2 + 
            ' (' + currencySymbol + paidOnTransactions.setScale(2) + ') ' + System.Label.sfims.part_of_health_check_3 + ' ' + 
            System.Label.sfims.part_of_health_check_1 + ' ' + typeOfAmount + ' ' + System.Label.sfims.part_of_health_check_4 + 
            ' (' + currencySymbol + paidOnRepaymentSchedules.setScale(2) + ').';
    }

    public static String currencySymbol {
        get{
            if (currencySymbol == null) {
                String Iso = UserInfo.getDefaultCurrency();
                currencySymbol = 
                    ('USD' == Iso ? '$' : 
                    ('CAD' == Iso ? '$' : 
                    ('GBP' == Iso ? '£' : 
                    ('JPY' == Iso ? '¥' : 
                    ('KRW' == Iso ? '₩' : 
                    ('CNY' == Iso ? '元' : 
                    ('EUR' == Iso ? '€' : 
                    Iso)))))));
            }
            return currencySymbol;
        }
        set;
    }

}