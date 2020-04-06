({
    doInit: function (cmp, event, helper) {
        console.group('%s, time: %f', 'doInit', helper.timeStamp());
        helper.showSpinner(cmp, 'v.isLoading', 40000, 'doInit');
        console.groupEnd();
    },

    handleCancel: function (cmp, event, helper) {
        console.log('%s, time: %f', 'handleCancel', helper.timeStamp());
        helper.cancel(cmp);
    },

    handleRecordUpdated: function (cmp, event, helper) {
        console.group('%s, time: %f', 'handleRecordUpdated', helper.timeStamp());
        let eventParams = event.getParams();
        helper.hideSpinner(cmp, 'v.isLoading', 'doInit');
        if (eventParams.changeType === 'LOADED') {
            helper.hideSpinner(cmp, 'v.isLoading', 'doInit');
            let simpleRecord = cmp.get('v.simpleRecord');
            helper.log('Record', simpleRecord);
            if (!simpleRecord.hasOwnProperty('sfims__Open_Ended_Loan__c')) {
                helper.showErrMessage('The parameter "sfims__Open_Ended_Loan__c" not found.');
                helper.close(cmp);
            }
            helper.showModal(cmp, 'v.mainForm');
        }
        else if (eventParams.changeType === 'CHANGED') {
            console.log('CHANGED');
        } else if (eventParams.changeType === 'ERROR') {
            helper.showErrMessage('Data not loaded.');
            helper.cancel(cmp);
        }
        console.groupEnd();
    },

    handleRecalculate: function (cmp, event, helper) {
        console.group('%s, time: %f', 'handleRecalculate', helper.timeStamp());
        let spinner = helper.showSpinner(cmp, 'v.isLoading');
        let simpleRecord = cmp.get('v.simpleRecord');
        if (simpleRecord['sfims__Open_Ended_Loan__c']) {
            let action = cmp.get('c.recalculateOpenEndedLoan');
            action.setParams({
                loanId: cmp.get('v.recordId')
            });
            action.setCallback(this, function (response) {
                helper.hideSpinner(cmp, 'v.isLoading', spinner);
                let state = response.getState();
                if (state === 'SUCCESS') {
                    console.group('%s, time: %f', 'fetchData-SUCCESS', helper.timeStamp());
                    helper.showSuccessMessage('Recalculation completed.');
                    helper.cancel(cmp);
                    console.groupEnd();
                }
                else {
                    let errors = response.getError();
                    let message = 'Unknown error';
                    if (errors && Array.isArray(errors) && errors.length > 0) {
                        message = errors[0].message;
                    }
                    helper.showErrMessage(message);
                    helper.cancel(cmp);
                }
            });
            $A.enqueueAction(action);
        } else { // standard loan
            let action = cmp.get('c.getLoanData');
            action.setParams({
                loanId: cmp.get('v.recordId')
            });
            action.setCallback(this, function (response) {
                helper.hideSpinner(cmp, 'v.isLoading', spinner);
                let state = response.getState();
                if (state === 'SUCCESS') {
                    console.group('%s, time: %f', 'fetchData-SUCCESS', helper.timeStamp());
                    let map = response.getReturnValue();
                    helper.log('getLoanData', map);
                    if (map) {
                        if (map.hasOwnProperty('loan')) {
                            let loan = JSON.parse(map['loan']);
                            if (loan.hasOwnProperty('attributes')) {
                                delete loan['attributes'];
                                delete loan['sfims__Loan_Product__r'];
                            }
                            helper['loanJSON'] = map['loan'];
                            helper.log('Loan', loan);
                            if (map.hasOwnProperty('loanEvents')) {
                                let loanEvents = JSON.parse(map['loanEvents']);
                                helper.log('loanEvents', loanEvents);
                                helper['loanEvents'] = loanEvents;
                                helper['toggleStep'] = Math.ceil(100/loanEvents.length);
                                cmp.set('v.progress', 0);
                                cmp.set('v.isProgressBar', true);
                                helper.recalculateWithLoanEvents(cmp);
                            } else { // Without LoanEvents
                                helper.recalculateWithoutLoanEvents(cmp);
                            }
                        } else {
                            helper.showErrMessage('The loan not found.');
                            helper.cancel(cmp);
                        }
                    } else {
                        helper.showErrMessage('The loan not found.');
                        helper.cancel(cmp);
                    }
                    console.groupEnd();
                }
                else {
                    let errors = response.getError();
                    let message = 'Unknown error';
                    if (errors && Array.isArray(errors) && errors.length > 0) {
                        message = errors[0].message;
                    }
                    helper.showErrMessage(message);
                    helper.cancel(cmp);
                }
            });
            $A.enqueueAction(action);
        }
        console.groupEnd();
    }
});