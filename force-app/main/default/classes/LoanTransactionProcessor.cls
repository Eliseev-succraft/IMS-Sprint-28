public with sharing class LoanTransactionProcessor {// ONLY FOR STANDARD LOANS

    // used by TransactionTrigger
    public static void processLoanTransactions(Set<Id> loanIds) {
        // Check to see whether the caller has access to this information.
        if (!Investment__c.SObjectType.getDescribe().isAccessible()
                || !Repayment_Schedule__c.SObjectType.getDescribe().isUpdateable()
                || !Transaction__c.SObjectType.getDescribe().isUpdateable()) {
            throw new AuraHandledException(System.Label.sfims.error_message_27);
        }

        Map<Id, Investment__c> idToInvestment = new Map<Id, Investment__c>();

        if (!loanIds.isEmpty()) {
            //Create map of Loan Id to Investment record
            idToInvestment = new Map<Id, Investment__c>([
                    SELECT Id, Amount__c, Interest_Rate__c, Late_Repayment_Calculation_Method__c, Late_Repayment_Interest_Rate__c,
                            Disbursement_Date__c, Open_Ended_Loan__c, Late_Repayment_Fees_Expected0__c, Interest_Expected_Open_Ended_Loan__c,
                            Capitalized_Amount__c, Capitalized_Fee_Amount__c, Disbursement_Method__c, Variable_Interest_Spread__c,
                            Setup_Fee_Charging_Method__c, Setup_Fee__c, Setup_Fee_Expected__c, Loan_Product__c, Late_Repayment_Fixed_Fee__c,
                            Loan_Product__r.Interest_Rate_Review_Frequency__c, Loan_Product__r.Interest_Reference_Rate__c,
                            Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c,
                            Loan_Product__r.Default_Interest_Rate__c, Loan_Product__r.Interest_Rate_Source__c,
                            Loan_Product__r.Repayment_Allocation_Type__c, Loan_Product__r.Repayment_Allocation_Order__c, (
                            SELECT Id, Name, Loan__c, Start_Date__c, Due_Date__c, Migration__c, Fees_Expected__c, Fees_Paid__c, Fees_Written_Off__c,
                                    Interest_Expected0__c, Interest_Expected_On_Last_Paid_Date__c, Interest_Paid__c, Interest_Written_Off__c,
                                    Late_Repayment_Fees_On_Last_Paid_Date__c, Late_Repayment_Fees_Paid__c, Late_Repayment_Fees_Written_Off__c,
                                    Late_Repayment_Fixed_Fee__c, Due_Date_with_Tolerance_Period__c, Cancel_Late_Repayment_Fee__c, Last_Action_Date__c,
                                    Principal_Expected__c, Principal_Paid__c, Principal_Written_Off__c
                            FROM Repayment_Schedules__r
                            ORDER BY Due_Date__c
                    ), (
                            SELECT Id, Name, Transaction_Date__c, Amount__c, Migration__c, Type__c, Investment__c,
                                    Late_Repayment_Fee_Amount__c, Interest_Amount__c, Principal_Amount__c, Fee_Amount__c,
                                    Created_Using_The_Disburse_Button__c, Repayment_Allocation_Order__c
                            FROM Transactions__r
                            WHERE (Type__c = 'Repayment' AND Status__c = 'Received') OR (Type__c = 'Disbursement' AND Status__c = 'Disbursed')
                            ORDER BY Transaction_Date__c, CreatedDate
                    ), (
                            SELECT Event_Date__c
                            FROM Loan_Events__r
                            WHERE Loan_Event_Type__c = 'Interest Rate Change'
                            ORDER BY Event_Date__c DESC, CreatedDate DESC
                            LIMIT 1
                    )
                    FROM Investment__c
                    WHERE Id IN :loanIds AND Open_Ended_Loan__c = false
            ]);
        }

        LoanTransactionProcessor.processLoanTransactions(idToInvestment);

    }

    // used by RecalculateLoanFromScratch
    public static void processLoanTransactions(Id loanId, Date eventDate) {
        // Check to see whether the caller has access to this information.
        if (!Investment__c.SObjectType.getDescribe().isAccessible()
                || !Repayment_Schedule__c.SObjectType.getDescribe().isUpdateable()
                || !Transaction__c.SObjectType.getDescribe().isUpdateable()) {
            throw new AuraHandledException(System.Label.sfims.error_message_27);
        }

        //Create map of Loan Id to Investment record
        Map<Id, Investment__c> idToInvestment = new Map<Id, Investment__c>([
                SELECT Id, Amount__c, Interest_Rate__c, Late_Repayment_Calculation_Method__c, Late_Repayment_Interest_Rate__c,
                        Disbursement_Date__c, Open_Ended_Loan__c, Late_Repayment_Fees_Expected0__c, Interest_Expected_Open_Ended_Loan__c,
                        Capitalized_Amount__c, Capitalized_Fee_Amount__c, Disbursement_Method__c, Variable_Interest_Spread__c,
                        Setup_Fee_Charging_Method__c, Setup_Fee__c, Setup_Fee_Expected__c, Loan_Product__c, Late_Repayment_Fixed_Fee__c,
                        Loan_Product__r.Interest_Rate_Review_Frequency__c, Loan_Product__r.Interest_Reference_Rate__c,
                        Loan_Product__r.Maximum_Interest_Bandwidth__c, Loan_Product__r.Minimum_Interest_Bandwidth__c,
                        Loan_Product__r.Default_Interest_Rate__c, Loan_Product__r.Interest_Rate_Source__c,
                        Loan_Product__r.Repayment_Allocation_Type__c, Loan_Product__r.Repayment_Allocation_Order__c, (
                        SELECT Id, Name, Loan__c, Start_Date__c, Due_Date__c, Migration__c, Fees_Expected__c, Fees_Paid__c, Fees_Written_Off__c,
                                Interest_Expected0__c, Interest_Expected_On_Last_Paid_Date__c, Interest_Paid__c, Interest_Written_Off__c,
                                Late_Repayment_Fees_On_Last_Paid_Date__c, Late_Repayment_Fees_Paid__c, Late_Repayment_Fees_Written_Off__c,
                                Late_Repayment_Fixed_Fee__c, Due_Date_with_Tolerance_Period__c, Cancel_Late_Repayment_Fee__c, Last_Action_Date__c,
                                Principal_Expected__c, Principal_Paid__c, Principal_Written_Off__c
                        FROM Repayment_Schedules__r
                        ORDER BY Due_Date__c, CreatedDate
                ), (
                        SELECT Id, Name, Transaction_Date__c, Amount__c, Migration__c, Type__c, Investment__c,
                                Late_Repayment_Fee_Amount__c, Interest_Amount__c, Principal_Amount__c, Fee_Amount__c,
                                Created_Using_The_Disburse_Button__c, Repayment_Allocation_Order__c
                        FROM Transactions__r
                        WHERE (Type__c = 'Repayment' AND Status__c = 'Received' AND Transaction_Date__c < :eventDate) OR (Type__c = 'Disbursement' AND Status__c = 'Disbursed')
                        ORDER BY Transaction_Date__c, CreatedDate
                ), (
                        SELECT Event_Date__c
                        FROM Loan_Events__r
                        WHERE Loan_Event_Type__c = 'Interest Rate Change'
                        ORDER BY Event_Date__c DESC, CreatedDate DESC
                        LIMIT 1
                )
                FROM Investment__c
                WHERE Id = :loanId AND Open_Ended_Loan__c = false
        ]);

        LoanTransactionProcessor.processLoanTransactions(idToInvestment);

    }

    public static void processLoanTransactions(Map<Id, Investment__c> idToInvestment) {
        System.debug('LoanTransactionProcessor.processLoanTransactions');
        if (!idToInvestment.isEmpty()) {
            //initialise payment variables;
            Map<Id, List<Transaction__c>> loanIdToDisbursements = new Map<Id, List<Transaction__c>>();
            Map<Id, List<Transaction__c>> loanIdToRepayments = new Map<Id, List<Transaction__c>>();
            Map<Id, List<Repayment_Schedule__c>> loanIdToSchedules = new Map<Id, List<Repayment_Schedule__c>>();
            for (Id key : idToInvestment.keySet()) {
                Investment__c thisLoan = idToInvestment.get(key);
                if (!thisLoan.Transactions__r.isEmpty()) { //this check is only for when all payments get deleted
                    for (Transaction__c initTransaction : thisLoan.Transactions__r) {
                        switch on initTransaction.Type__c {
                            when 'Disbursement' {
                                initTransaction.Created_Using_The_Disburse_Button__c = true;
                                if (!loanIdToDisbursements.containsKey(key)) loanIdToDisbursements.put(key, new List<Transaction__c>());
                                loanIdToDisbursements.get(key).add(initTransaction);
                            }
                            when 'Repayment' {
                                if (!initTransaction.Migration__c) {
                                    initTransaction.Late_Repayment_Fee_Amount__c = 0;
                                    initTransaction.Principal_Amount__c = 0;
                                    initTransaction.Fee_Amount__c = 0;
                                    initTransaction.Interest_Amount__c = 0;

                                    if (!loanIdToRepayments.containsKey(key)) loanIdToRepayments.put(key, new List<Transaction__c>());
                                    loanIdToRepayments.get(key).add(initTransaction);
                                }
                            }
                        }
                    }
                }
                if (!thisLoan.Repayment_Schedules__r.isEmpty()) {
                    for (Repayment_Schedule__c initSched : thisLoan.Repayment_Schedules__r) {
                        if (!initSched.Migration__c) {
                            initSched.Interest_Paid__c = 0;
                            initSched.Interest_Bonus__c = 0;
                            initSched.Fees_Paid__c = 0;
                            initSched.Principal_Paid__c = 0;
                            initSched.Last_Paid_Date__c = null;
                            initSched.Repaid_Date__c = null;
                            initSched.Late_Repayment_Fees_Paid__c = 0;
                            switch on thisLoan.Late_Repayment_Calculation_Method__c {
                                when 'Principal', 'Principal+Interest' {
                                    initSched.Late_Repayment_Fees_On_Last_Paid_Date__c = 0;
                                }
                            }
                            if (initSched.Fees_Written_Off__c == null) initSched.Fees_Written_Off__c = 0;
                            if (initSched.Interest_Written_Off__c == null) initSched.Interest_Written_Off__c = 0;
                            if (initSched.Principal_Written_Off__c == null) initSched.Principal_Written_Off__c = 0;
                            if (initSched.Late_Repayment_Fees_Written_Off__c == null) initSched.Late_Repayment_Fees_Written_Off__c = 0;

                            if (!loanIdToSchedules.containsKey(key)) loanIdToSchedules.put(key, new List<Repayment_Schedule__c>());
                            loanIdToSchedules.get(key).add(initSched);
                        }
                    }
                }
            }

            //List to hold schedule for update
            List<Repayment_Schedule__c> repaymentSchedulesToUpdate = new List <Repayment_Schedule__c>();
            //List to hold transactions for update
            List<Transaction__c> transactionsToUpdate = new List <Transaction__c>();

            // process per loan, so we can track which schedules were matched within the loan
            for (Id key : idToInvestment.keySet()) {
                Investment__c thisLoan = idToInvestment.get(key);

                List<Repayment_Schedule__c> schedules = new List<Repayment_Schedule__c>();
                if (loanIdToSchedules.containsKey(key)) schedules = loanIdToSchedules.get(key);
                Integer currentSchedule = 0;
                Integer currentFeeSchedule = 0;
                Integer currentInterestSchedule = 0;
                Integer currentLateRepaymentFeeSchedule = 0;
                Integer currentPrincipalSchedule = 0;

                if (loanIdToRepayments.containsKey(key)) { //this check is only for when all payments get deleted
                    // process a standard loan
                    for (Transaction__c theTransaction : loanIdToRepayments.get(key)) {//start payment loop
                        Decimal amountToAllocate = theTransaction.Amount__c;

                        Decimal interestPaidNew = 0;
                        Decimal interestRemaining = 0;

                        Decimal lateRepaymentFeesExpected = 0;
                        Decimal lateRepaymentFeesPaidNew = 0;
                        Decimal lateRepaymentFeesRemaining = 0;

                        Decimal adminFeeRemaining = 0;
                        Decimal adminFeePaidNew = 0;

                        Decimal principalPaidNew = 0;
                        Decimal principalRemaining = 0;
                        Decimal principalEarlyPaid = 0;

                        Repayment_Schedule__c schedule = new Repayment_Schedule__c();

                        // System.debug(amountToAllocate);
                        // System.debug(theTransaction.Transaction_Date__c);


                        if (!schedules.isEmpty()) {

                            // Calculate how much penalty is due
                            switch on thisLoan.Late_Repayment_Calculation_Method__c {
                                when 'Principal', 'Principal+Interest', 'Fixed Fee' {
                                    for (Integer i = currentSchedule; i < schedules.size(); i++) {
                                        schedule = schedules[i];
                                        // System.debug(schedule.Due_Date__c);

                                        if (theTransaction.Transaction_Date__c <= schedule.Due_Date_with_Tolerance_Period__c) {
                                            if (thisLoan.Late_Repayment_Calculation_Method__c == 'Fixed Fee') {
                                                for (Integer j = i; j < schedules.size(); j++) {
                                                    if (schedule.Late_Repayment_Fixed_Fee__c != null) {
                                                        schedule.Late_Repayment_Fixed_Fee__c = null;
                                                    }
                                                }
                                            }

                                            // System.debug('quit loop');
                                            // if payment date is before schedule date, quit the loop.
                                            i = schedules.size();
                                            continue;
                                        }

                                        principalRemaining = schedule.Principal_Expected__c - schedule.Principal_Paid__c - schedule.Principal_Written_Off__c;
                                        interestRemaining = schedule.Interest_Expected0__c - schedule.Interest_Paid__c - schedule.Interest_Written_Off__c;
                                        adminFeeRemaining = schedule.Fees_Expected__c - schedule.Fees_Paid__c - schedule.Fees_Written_Off__c;

                                        //Calculate the interest penalty for this scheduled period
                                        Decimal amountRemaining = 0;
                                        switch on thisLoan.Late_Repayment_Calculation_Method__c {
                                            when 'Fixed Fee' {
                                                if ((principalRemaining + interestRemaining + adminFeeRemaining) > 0 && schedule.Late_Repayment_Fixed_Fee__c == null) {
                                                    schedule.Late_Repayment_Fixed_Fee__c = thisLoan.Late_Repayment_Fixed_Fee__c;
                                                }
                                                continue;
                                            }
                                            when 'Principal' {
                                                if (principalRemaining > 0) amountRemaining = principalRemaining; else continue;
                                            }
                                            when 'Principal+Interest' {
                                                if ((principalRemaining + interestRemaining) > 0) amountRemaining = principalRemaining + interestRemaining; else continue;
                                            }
                                        }

                                        Integer daysLate = 0;
                                        if (schedule.Last_Paid_Date__c == null || schedule.Last_Paid_Date__c <= schedule.Due_Date_with_Tolerance_Period__c) {
                                            daysLate = schedule.Due_Date_with_Tolerance_Period__c.daysBetween(theTransaction.Transaction_Date__c);
                                        } else {
                                            daysLate = schedule.Last_Paid_Date__c.daysBetween(theTransaction.Transaction_Date__c);
                                            if (daysLate == 0) continue;
                                        }

                                        lateRepaymentFeesExpected = (daysLate * ((thisLoan.Late_Repayment_Interest_Rate__c / 365) / 100) * amountRemaining).setScale(16);
                                        schedule.Late_Repayment_Fees_On_Last_Paid_Date__c += lateRepaymentFeesExpected; //the interest penalty due on schedule period

                                    }
                                }
                            }

                            switch on thisLoan.Loan_Product__r.Repayment_Allocation_Type__c {
                                when 'Loan-based' {
                                    for (String amount : thisLoan.Loan_Product__r.Repayment_Allocation_Order__c.split(';')) {
                                        switch on amount {
                                            when 'Fees' {
                                                for (Integer i = currentFeeSchedule; i < schedules.size(); i++) {
                                                    schedule = schedules[i];
                                                    // System.debug(schedule.Due_Date__c);

                                                    if (theTransaction.Transaction_Date__c < schedule.Due_Date__c) {
                                                        // System.debug('quit loop');
                                                        // if payment date is before schedule date, quit the loop.
                                                        i = schedules.size();
                                                        continue;
                                                    }

                                                    //if any admin fee is remaining, pay the admin fee
                                                    adminFeeRemaining = schedule.Fees_Expected__c - schedule.Fees_Paid__c - schedule.Fees_Written_Off__c;
                                                    if (amountToAllocate > 0 && adminFeeRemaining > 0) {
                                                        if (amountToAllocate > adminFeeRemaining) {
                                                            adminFeePaidNew = adminFeeRemaining;
                                                        } else {
                                                            adminFeePaidNew = amountToAllocate;
                                                        }
                                                        schedule.Fees_Paid__c += adminFeePaidNew;
                                                        theTransaction.Fee_Amount__c += adminFeePaidNew;

                                                        //Add value to summary fields
                                                        schedule.Last_Paid_Date__c = theTransaction.Transaction_Date__c;
                                                        amountToAllocate -= adminFeePaidNew;
                                                    }

                                                    if ((schedule.Fees_Expected__c - schedule.Fees_Paid__c - schedule.Fees_Written_Off__c) <= 0) {
                                                        currentFeeSchedule++;
                                                    }

                                                    if (amountToAllocate <= 0) {
                                                        // if no payment amount is left, quit the loop.
                                                        i = schedules.size();
                                                    }
                                                }
                                            }
                                            when 'Interest' {
                                                for (Integer i = currentInterestSchedule; i < schedules.size(); i++) {
                                                    schedule = schedules[i];
                                                    // System.debug(schedule.Due_Date__c);

                                                    if (theTransaction.Transaction_Date__c < schedule.Due_Date__c) {
                                                        // System.debug('quit loop');
                                                        // if payment date is before schedule date, quit the loop.
                                                        i = schedules.size();
                                                        continue;
                                                    }

                                                    //Calculate how much of the interest can be paid
                                                    interestRemaining = schedule.Interest_Expected0__c - schedule.Interest_Paid__c - schedule.Interest_Written_Off__c;
                                                    if (interestRemaining > 0 && amountToAllocate > 0) {
                                                        if (amountToAllocate > interestRemaining) {
                                                            interestPaidNew = interestRemaining;
                                                        } else {
                                                            interestPaidNew = amountToAllocate;
                                                        }
                                                        schedule.Interest_Paid__c += interestPaidNew;
                                                        theTransaction.Interest_Amount__c += interestPaidNew;

                                                        //the remaining amount to be allocated is the old amount minus the just allocated interest amount
                                                        schedule.Last_Paid_Date__c = theTransaction.Transaction_Date__c;
                                                        amountToAllocate -= interestPaidNew;
                                                    }

                                                    if ((schedule.Interest_Expected0__c - schedule.Interest_Paid__c - schedule.Interest_Written_Off__c) <= 0) {
                                                        currentInterestSchedule++;
                                                    }

                                                    if (amountToAllocate <= 0) {
                                                        // if no payment amount is left, quit the loop.
                                                        i = schedules.size();
                                                    }
                                                }
                                            }
                                            when 'Late Repayment Fees' {
                                                for (Integer i = currentLateRepaymentFeeSchedule; i < schedules.size(); i++) {
                                                    schedule = schedules[i];
                                                    // System.debug(schedule.Due_Date__c);

                                                    if (theTransaction.Transaction_Date__c < schedule.Due_Date__c) {
                                                        // System.debug('quit loop');
                                                        // if payment date is before schedule date, quit the loop.
                                                        i = schedules.size();
                                                        continue;
                                                    }

                                                    if (schedule.Cancel_Late_Repayment_Fee__c) continue;

                                                    //Calculate how much of the penalty can be paid
                                                    Decimal lateRepaymentFeeExpected = 0;
                                                    switch on thisLoan.Late_Repayment_Calculation_Method__c {
                                                        when 'Fixed Fee' {
                                                            if (schedule.Late_Repayment_Fixed_Fee__c != null) lateRepaymentFeeExpected = schedule.Late_Repayment_Fixed_Fee__c;
                                                        }
                                                        when 'Principal', 'Principal+Interest' {
                                                            lateRepaymentFeeExpected = schedule.Late_Repayment_Fees_On_Last_Paid_Date__c;
                                                        }
                                                    }

                                                    lateRepaymentFeesRemaining = lateRepaymentFeeExpected - schedule.Late_Repayment_Fees_Paid__c - schedule.Late_Repayment_Fees_Written_Off__c;
                                                    if (lateRepaymentFeesRemaining > 0 && amountToAllocate > 0) {
                                                        if (amountToAllocate > lateRepaymentFeesRemaining) {
                                                            lateRepaymentFeesPaidNew = lateRepaymentFeesRemaining;
                                                        } else {
                                                            lateRepaymentFeesPaidNew = amountToAllocate;//paid interest penalty
                                                        }
                                                        schedule.Late_Repayment_Fees_Paid__c += lateRepaymentFeesPaidNew;
                                                        theTransaction.Late_Repayment_Fee_Amount__c += lateRepaymentFeesPaidNew;

                                                        schedule.Last_Paid_Date__c = theTransaction.Transaction_Date__c;
                                                        amountToAllocate -= lateRepaymentFeesPaidNew;
                                                    }

                                                    if ((lateRepaymentFeeExpected - schedule.Late_Repayment_Fees_Paid__c - schedule.Late_Repayment_Fees_Written_Off__c) <= 0) {
                                                        currentLateRepaymentFeeSchedule++;
                                                    }

                                                    if (amountToAllocate <= 0) {
                                                        // if no payment amount is left, quit the loop.
                                                        i = schedules.size();
                                                    }
                                                }
                                            }
                                            when 'Principal' {
                                                for (Integer i = currentPrincipalSchedule; i < schedules.size(); i++) {
                                                    schedule = schedules[i];
                                                    // System.debug(schedule.Due_Date__c);

                                                    if (theTransaction.Transaction_Date__c < schedule.Due_Date__c) {
                                                        // System.debug('quit loop');
                                                        // if payment date is before schedule date, quit the loop.
                                                        i = schedules.size();
                                                        continue;
                                                    }

                                                    //Pay principal due
                                                    principalRemaining = schedule.Principal_Expected__c - schedule.Principal_Paid__c - schedule.Principal_Written_Off__c;
                                                    if (principalRemaining > 0 && amountToAllocate > 0) {//any principal due to be paid?
                                                        if (amountToAllocate > principalRemaining) {
                                                            principalPaidNew = principalRemaining;
                                                        } else {
                                                            principalPaidNew = amountToAllocate;//amount of principal paid in this payment
                                                        }
                                                        schedule.Principal_Paid__c += principalPaidNew;//update schedule record
                                                        theTransaction.Principal_Amount__c += principalPaidNew;//update payment record

                                                        //Add value to summary fields
                                                        schedule.Last_Paid_Date__c = theTransaction.Transaction_Date__c;
                                                        amountToAllocate -= principalPaidNew;//update the remainder of amount available
                                                    }

                                                    if ((schedule.Principal_Expected__c - schedule.Principal_Paid__c - schedule.Principal_Written_Off__c) <= 0) {
                                                        currentPrincipalSchedule++;
                                                    }

                                                    if (amountToAllocate <= 0) {
                                                        // if no payment amount is left, quit the loop.
                                                        i = schedules.size();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    List<Integer> currentScheduleList = new List<Integer>{
                                            currentFeeSchedule,
                                            currentInterestSchedule,
                                            currentLateRepaymentFeeSchedule,
                                            currentPrincipalSchedule
                                    };
                                    currentScheduleList.sort();
                                    currentSchedule = currentScheduleList[0];
                                }
                                when 'Schedule-based' {
                                    for (Integer i = currentSchedule; i < schedules.size(); i++) {
                                        schedule = schedules[i];
                                        // System.debug(schedule.Due_Date__c);

                                        if (theTransaction.Transaction_Date__c < schedule.Due_Date__c) {
                                            // System.debug('quit loop');
                                            // if payment date is before schedule date, quit the loop.
                                            i = schedules.size();
                                            continue;
                                        }

                                        Decimal lateRepaymentFeeExpected = 0;

                                        String allocationOrder = String.isBlank(theTransaction.Repayment_Allocation_Order__c) ?
                                                thisLoan.Loan_Product__r.Repayment_Allocation_Order__c :
                                                theTransaction.Repayment_Allocation_Order__c;
                                        for (String amount : allocationOrder.split(';')) {
                                            switch on amount {
                                                when 'Fees' {
                                                    //if any admin fee is remaining, pay the admin fee
                                                    adminFeeRemaining = schedule.Fees_Expected__c - schedule.Fees_Paid__c - schedule.Fees_Written_Off__c;
                                                    if (amountToAllocate > 0 && adminFeeRemaining > 0) {
                                                        if (amountToAllocate > adminFeeRemaining) {
                                                            adminFeePaidNew = adminFeeRemaining;
                                                        } else {
                                                            adminFeePaidNew = amountToAllocate;
                                                        }
                                                        schedule.Fees_Paid__c += adminFeePaidNew;
                                                        theTransaction.Fee_Amount__c += adminFeePaidNew;

                                                        //Add value to summary fields
                                                        schedule.Last_Paid_Date__c = theTransaction.Transaction_Date__c;
                                                        amountToAllocate -= adminFeePaidNew;
                                                    }
                                                }
                                                when 'Interest' {
                                                    //Calculate how much of the interest can be paid
                                                    interestRemaining = schedule.Interest_Expected0__c - schedule.Interest_Paid__c - schedule.Interest_Written_Off__c;
                                                    if (interestRemaining > 0 && amountToAllocate > 0) {
                                                        if (amountToAllocate > interestRemaining) {
                                                            interestPaidNew = interestRemaining;
                                                        } else {
                                                            interestPaidNew = amountToAllocate;
                                                        }
                                                        schedule.Interest_Paid__c += interestPaidNew;
                                                        theTransaction.Interest_Amount__c += interestPaidNew;

                                                        //the remaining amount to be allocated is the old amount minus the just allocated interest amount
                                                        schedule.Last_Paid_Date__c = theTransaction.Transaction_Date__c;
                                                        amountToAllocate -= interestPaidNew;
                                                    }
                                                }
                                                when 'Late Repayment Fees' {
                                                    if (!schedule.Cancel_Late_Repayment_Fee__c) {
                                                        //Calculate how much of the penalty can be paid
                                                        switch on thisLoan.Late_Repayment_Calculation_Method__c {
                                                            when 'Fixed Fee' {
                                                                if (schedule.Late_Repayment_Fixed_Fee__c != null) lateRepaymentFeeExpected = schedule.Late_Repayment_Fixed_Fee__c;
                                                            }
                                                            when 'Principal', 'Principal+Interest' {
                                                                lateRepaymentFeeExpected = schedule.Late_Repayment_Fees_On_Last_Paid_Date__c;
                                                            }
                                                        }

                                                        lateRepaymentFeesRemaining = lateRepaymentFeeExpected - schedule.Late_Repayment_Fees_Paid__c - schedule.Late_Repayment_Fees_Written_Off__c;
                                                        if (lateRepaymentFeesRemaining > 0 && amountToAllocate > 0) {
                                                            if (amountToAllocate > lateRepaymentFeesRemaining) {
                                                                lateRepaymentFeesPaidNew = lateRepaymentFeesRemaining;
                                                            } else {
                                                                lateRepaymentFeesPaidNew = amountToAllocate;//paid interest penalty
                                                            }
                                                            schedule.Late_Repayment_Fees_Paid__c += lateRepaymentFeesPaidNew;
                                                            theTransaction.Late_Repayment_Fee_Amount__c += lateRepaymentFeesPaidNew;

                                                            schedule.Last_Paid_Date__c = theTransaction.Transaction_Date__c;
                                                            amountToAllocate -= lateRepaymentFeesPaidNew;
                                                        }
                                                    }
                                                }
                                                when 'Principal' {
                                                    //Pay principal due
                                                    principalRemaining = schedule.Principal_Expected__c - schedule.Principal_Paid__c - schedule.Principal_Written_Off__c;
                                                    if (principalRemaining > 0 && amountToAllocate > 0) {//any principal due to be paid?
                                                        if (amountToAllocate > principalRemaining) {
                                                            principalPaidNew = principalRemaining;
                                                        } else {
                                                            principalPaidNew = amountToAllocate;//amount of principal paid in this payment
                                                        }
                                                        schedule.Principal_Paid__c += principalPaidNew;//update schedule record
                                                        theTransaction.Principal_Amount__c += principalPaidNew;//update payment record

                                                        //Add value to summary fields
                                                        schedule.Last_Paid_Date__c = theTransaction.Transaction_Date__c;
                                                        amountToAllocate -= principalPaidNew;//update the remainder of amount available
                                                    }
                                                }
                                            }
                                        }

                                        // update the starting schedule if all payments in the current schedule have been made
                                        if ((schedule.Fees_Expected__c - schedule.Fees_Paid__c - schedule.Fees_Written_Off__c <= 0)
                                                && (schedule.Interest_Expected0__c - schedule.Interest_Paid__c - schedule.Interest_Written_Off__c <= 0)
                                                && (lateRepaymentFeeExpected - schedule.Late_Repayment_Fees_Paid__c - schedule.Late_Repayment_Fees_Written_Off__c <= 0)
                                                && (schedule.Principal_Expected__c - schedule.Principal_Paid__c - schedule.Principal_Written_Off__c <= 0)) {
                                            currentSchedule++;
                                        }

                                        if (amountToAllocate <= 0) {
                                            // if no payment amount is left, quit the loop.
                                            i = schedules.size();
                                        }
                                    }

                                    if (amountToAllocate <= 0) continue;

                                }
                            }

                            //Allocate early pay
                            for (Integer i = currentSchedule; i < schedules.size(); i++) {

                                schedule = schedules[i];
                                // System.debug(schedule.Due_Date__c);
                                System.debug(amountToAllocate);

                                if (theTransaction.Transaction_Date__c < schedule.Due_Date__c) {

                                    principalRemaining = schedule.Principal_Expected__c - schedule.Principal_Paid__c - schedule.Principal_Written_Off__c;
                                    if (principalRemaining > 0) {
                                        //Calculate how much of the future principal can already be paid
                                        if (amountToAllocate > principalRemaining) {
                                            principalEarlyPaid = principalRemaining;
                                        } else {
                                            principalEarlyPaid = amountToAllocate;
                                        }

                                        schedule.Principal_paid__c += principalEarlyPaid;
                                        // System.debug(schedule.Principal_paid__c);
                                        theTransaction.Principal_Amount__c += principalEarlyPaid;

                                        if (principalEarlyPaid > 0) schedule.Last_Paid_Date__c = theTransaction.Transaction_Date__c;
                                        amountToAllocate -= principalEarlyPaid;

                                        if (amountToAllocate <= 0) {
                                            // if no payment amount is left, quit the loop.
                                            i = schedules.size();
                                        }
                                    }

                                    //if any admin fee is remaining, pay the admin fee
                                    adminFeeRemaining = schedule.Fees_Expected__c - schedule.Fees_Paid__c - schedule.Fees_Written_Off__c;
                                    if (adminFeeRemaining > 0) {//have we got an admin fee to pay and is there money to pay it?
                                        if (amountToAllocate > adminFeeRemaining) {
                                            adminFeePaidNew = adminFeeRemaining;
                                        } else {
                                            adminFeePaidNew = amountToAllocate;
                                        }

                                        schedule.Fees_Paid__c += adminFeePaidNew;
                                        // System.debug(schedule.Fees_Paid__c);
                                        theTransaction.Fee_Amount__c += adminFeePaidNew;

                                        //Add value to summary fields
                                        if (adminFeePaidNew > 0) schedule.Last_Paid_Date__c = theTransaction.Transaction_Date__c;
                                        amountToAllocate -= adminFeePaidNew;

                                        if (amountToAllocate <= 0) {
                                            // if no payment amount is left, quit the loop.
                                            i = schedules.size();
                                        }
                                    }
                                }
                            }//end loan schedule loop

                            if (amountToAllocate > 0) {
                                //add any overpayment to the last schedule (Principal paid field)
                                schedule = schedules[schedules.size() - 1];
                                schedule.Principal_Paid__c += amountToAllocate;
                                if (amountToAllocate > 0) schedule.Last_Paid_Date__c = theTransaction.Transaction_Date__c;

                                // set to 0 as the amount has been added to the last schedule.
                                amountToAllocate = 0;
                            }
                        }
                    }//end payment loop



                } else {// if all transactions are deleted

                }

                //---------------------------------------------PRINCIPAL BALANCE LOGIC---------------------------------------------
                /*
                System.debug('PRINCIPAL BALANCE LOGIC');
                // populate the Principal Balance
                Decimal principalBalance = 0;
                Integer currentDisbursement = 0;
                List<Transaction__c> disbursements = new List<Transaction__c>();
                if (loanIdToDisbursements.containsKey(key)) disbursements = loanIdToDisbursements.get(key);
                // if there are no disbursements for the loan, get Loan Amount as the initial amount of the Principal Balance
                if (disbursements.isEmpty()) {
                    Decimal capitalizedAmount = 0;
                    Decimal capitalizedFeeAmount = 0;
                    if (thisLoan.Capitalized_Amount__c != null) capitalizedAmount = thisLoan.Capitalized_Amount__c;
                    if (thisLoan.Capitalized_Fee_Amount__c != null) capitalizedFeeAmount = thisLoan.Capitalized_Fee_Amount__c;
                    principalBalance = capitalizedAmount - capitalizedFeeAmount;
                }

                // Principal Balance is equal to Principal Expected - Principal Paid - Principal Written Off
                // calculate for transactions
                Map<Id, Transaction__c> repaymentIdToRepayment = new Map<Id, Transaction__c>();
                if (loanIdToRepayments.containsKey(key)) {
                    repaymentIdToRepayment = new Map<Id, Transaction__c>(loanIdToRepayments.get(key));
                }

                if (thisLoan.Setup_Fee_Charging_Method__c == 'Deducted From Principal') {
                    principalBalance += thisLoan.Setup_Fee_Expected__c;
                }

                Decimal principalBalanceForTransactions = principalBalance;
                currentSchedule = 0;
                if (!thisLoan.Transactions__r.isEmpty()) {
                    for (Transaction__c tr : thisLoan.Transactions__r) {
                        switch on tr.Type__c {
                            when 'Disbursement' {
                                // increase by the disbursement Amount (Principal Expected)
                                principalBalanceForTransactions += tr.Amount__c;
                            }
                            when 'Repayment' {
                                if (!tr.Migration__c) tr = repaymentIdToRepayment.get(tr.Id);

                                // minus Principal Written Off
                                for (Integer i = currentSchedule; i < schedules.size(); i++) {
                                    Repayment_Schedule__c schedule = schedules[i];
                                    if (tr.Transaction_Date__c <= schedule.Due_Date__c) {
                                        if (schedule.Principal_Written_Off__c != null) principalBalanceForTransactions -= schedule.Principal_Written_Off__c;
                                        currentSchedule++;
                                    } else {
                                        i = schedules.size();
                                    }
                                }

                                // minus Principal Paid
                                if (tr.Principal_Amount__c != null) {
                                    if (principalBalanceForTransactions < tr.Principal_Amount__c) {
                                        // overpayment should not be reflected in principal balance
                                        principalBalanceForTransactions = 0;
                                    } else {
                                        principalBalanceForTransactions -= tr.Principal_Amount__c;
                                    }
                                }
                            }
                        }
                        tr.Principal_Balance__c = principalBalanceForTransactions;
                        transactionsToUpdate.add(tr);
                    }
                }

                // calculate for repayment schedules
                Map<Id, Repayment_Schedule__c> scheduleIdToSchedule = new Map<Id, Repayment_Schedule__c>();
                if (loanIdToSchedules.containsKey(key)) {
                    scheduleIdToSchedule = new Map<Id, Repayment_Schedule__c>(loanIdToSchedules.get(key));
                    // System.debug(scheduleIdToSchedule.size());
                }

                currentDisbursement = 0;
                List<Repayment_Schedule__c> schedulesForBalance = thisLoan.Repayment_Schedules__r;
                // System.debug(schedulesForBalance.size());
                for (Integer i = 0; i < schedulesForBalance.size(); i++) {
                    // System.debug(i);
                    Repayment_Schedule__c schedule = new Repayment_Schedule__c();
                    if (schedulesForBalance[i].Migration__c) schedule = schedulesForBalance[i]; else schedule = scheduleIdToSchedule.get(schedulesForBalance[i].Id);
                    // System.debug(schedule);
                    // increase by the disbursement Amount (Principal Expected)
                    for (Integer j = currentDisbursement; j < disbursements.size(); j++) {
                        Transaction__c disb = disbursements[j];
                        if (disb.Transaction_Date__c <= schedule.Due_Date__c) {
                            principalBalance += disb.Amount__c;
                            currentDisbursement++;
                        } else {
                            j = disbursements.size();
                        }
                    }
                    // minus Principal Written Off
                    if (schedule.Principal_Written_Off__c != null) principalBalance -= schedule.Principal_Written_Off__c;
                    // minus Principal Paid
                    if (i == schedulesForBalance.size() - 1) {
                        if (schedule.Principal_Paid__c != null) {
                            if (principalBalance < schedule.Principal_Paid__c) {
                                // overpayment should not be reflected in principal balance
                                principalBalance = 0;
                            } else {
                                principalBalance -= schedule.Principal_Paid__c;
                            }
                        }
                    } else {
                        if (schedule.Principal_Paid__c != null) principalBalance -= schedule.Principal_Paid__c;
                    }

                    schedule.Principal_Balance__c = principalBalance;
                    repaymentSchedulesToUpdate.add(schedule);
                }
                */
                //---------------------------------------------------------------------------------------------------
            }

            Savepoint sp = database.setSavepoint();
            try {
                if (!transactionsToUpdate.isEmpty()) {
                    // we need to use updateAsSystem because we are writing to fields that normal users don't have access to (they should not be able to modify the fields themselves directly)

                    System.debug('transactionsToUpdate');
                    for (Transaction__c tr : transactionsToUpdate) {
                        System.debug('START ' + tr.Name);
                        System.debug(tr.Transaction_Date__c);
                        System.debug(tr.Amount__c);
                        System.debug(tr.Migration__c);
                        System.debug(tr.Type__c);
                        System.debug(tr.Investment__c);
                        System.debug(tr.Late_Repayment_Fee_Amount__c);
                        System.debug(tr.Interest_Amount__c);
                        System.debug(tr.Principal_Amount__c);
                        System.debug(tr.Fee_Amount__c);
                    }

                     DMLManager.updateAsSystem(transactionsToUpdate);
                }
                // we need to use updateAsSystem because we are writing to fields that normal users don't have access to (they should not be able to modify the fields themselves directly)
                // system.debug(repaymentSchedulesToUpdate.size());
                // system.debug(repaymentSchedulesToUpdate);


                System.debug('repaymentSchedulesToUpdate');
                for (Repayment_Schedule__c rs : repaymentSchedulesToUpdate) {
                    System.debug('START ' + rs.Name);
                    System.debug(rs.Loan__c);
                    System.debug(rs.Start_Date__c);
                    System.debug(rs.Due_Date__c);
                    System.debug(rs.Migration__c);
                    System.debug(rs.Fees_Expected__c);
                    System.debug(rs.Fees_Paid__c);
                    System.debug(rs.Fees_Written_Off__c);
                    System.debug(rs.Interest_Expected0__c);
                    System.debug(rs.Interest_Expected_On_Last_Paid_Date__c);
                    System.debug(rs.Interest_Paid__c);
                    System.debug(rs.Interest_Written_Off__c);
                    System.debug(rs.Late_Repayment_Fees_On_Last_Paid_Date__c);
                    System.debug(rs.Late_Repayment_Fees_Paid__c);
                    System.debug(rs.Late_Repayment_Fees_Written_Off__c);
                    System.debug(rs.Late_Repayment_Fixed_Fee__c);
                    System.debug(rs.Due_Date_with_Tolerance_Period__c);
                    System.debug(rs.Cancel_Late_Repayment_Fee__c);
                    System.debug(rs.Last_Action_Date__c);
                    System.debug(rs.Principal_Expected__c);
                    System.debug(rs.Principal_Paid__c);
                    System.debug(rs.Principal_Written_Off__c);
                }

                 DMLManager.updateAsSystem(repaymentSchedulesToUpdate);

                // perform Nightly batch to populate Late Repayment Fees Expected for standard loans on the Investment level
                List<Investment__c> investmentsToUpdate = new List<Investment__c>();
                for (Investment__c i : [
                        SELECT Late_Repayment_Fees_Expected0__c, (
                                SELECT Late_Repayment_Fees_Expected0__c
                                FROM Repayment_Schedules__r
                                WHERE Active__c = true AND Due_Date_with_Tolerance_Period__c <= TODAY
                        )
                        FROM Investment__c
                        WHERE Id IN :idToInvestment.keySet()
                ]) {
                    Decimal lateRepaymentFeesExpected = 0;
                    for (Repayment_Schedule__c rs : i.Repayment_Schedules__r) {
                        lateRepaymentFeesExpected += rs.Late_Repayment_Fees_Expected0__c;
                    }
                    if (i.Late_Repayment_Fees_Expected0__c != lateRepaymentFeesExpected) {
                        i.Late_Repayment_Fees_Expected0__c = lateRepaymentFeesExpected;
                        investmentsToUpdate.add(i);
                    }
                }
                if (!investmentsToUpdate.isEmpty()) {
                    DMLManager.updateAsSystem(investmentsToUpdate);
                }
            } catch (Exception e) {
                // rollback and re-throw exception so that it can be handled
                Database.rollback(sp);
                system.debug('processing error: ' + e.getMessage());
                throw new ApplicationException(e.getMessage());
            }

            Database.executeBatch(new CalculatePrincipalBalanceBatch2(idToInvestment.keySet()), 1);
        }
    }

}