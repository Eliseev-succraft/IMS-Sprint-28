({
    doInit: function (cmp, event, helper) {
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['debugLogStyle'] = 'background: green; color: white;';
        helper.begin('doInit');
        cmp.set('v.totalPrincipalWrittenOff', 0);
        cmp.set('v.totalInterestWrittenOff', 0);
        helper['isRecordUpdated'] = false;
        let simpleRecord = cmp.get('v.simpleRecord');
        helper.log(simpleRecord);
        cmp.set('v.totalFeesWrittenOff', simpleRecord['sfims__Fees_Remaining__c']);
        cmp.set('v.totalPenaltiesWrittenOff', simpleRecord['sfims__Late_Repayment_Fees_Remaining__c']);
        if (cmp.get('v.rescheduleLoan')) {
            cmp.set('v.totalInterestWrittenOff', simpleRecord['sfims__Interest_Overdue__c']);
        }
        if (cmp.get('v.earlyRepayment')) {
            cmp.set('v.totalInterestWrittenOff', simpleRecord['sfims__Interest_Remaining__c']);
        }
        if (cmp.get('v.writeOff')) {
            cmp.set('v.totalPrincipalWrittenOff', simpleRecord['sfims__Principal_Remaining__c']);
            cmp.set('v.totalInterestWrittenOff', simpleRecord['sfims__Interest_Remaining__c']);
            cmp.set('v.totalAmountWrittenOff', simpleRecord['sfims__Total_Remaining__c']);
        }
        if (cmp.get('v.rescheduleLoan') || cmp.get('v.earlyRepayment')) {
            let action = cmp.get('c.onChangeWrittenOffAmount');
            action.setParams({cmp: cmp, event: event, helper: helper});
            $A.enqueueAction(action);
        }
        helper.end();
    },

    showSpinner: function (cmp, event, helper) {
        helper.begin('showSpinner');
        // there won't be two spinners
        if ((cmp.get('v.earlyRepayment') || cmp.get('v.writeOff')) && !helper['isRecordUpdated']) {
            cmp.find('spinner').showSpinner('loading');
        }
        helper.end();
    },

    formLoad: function (cmp, event, helper) {
        helper.begin('formLoad');
        helper['isRecordUpdated'] = true;
        cmp.find('spinner').hideSpinner('loading');
        helper.end();
    },

    handleValidation: function (cmp, event, helper) {
        helper.begin('handleValidation');
        let isValid = true;
        if (cmp.get('v.isInternalTransfer')) {
            let transactionDate = cmp.find('transactionDate');
            if (transactionDate) {
                if ($A.util.isEmpty(transactionDate.get('v.value'))) {
                    transactionDate.setCustomValidity('Complete this field.');
                    transactionDate.reportValidity();
                    isValid = false;
                } else {
                    transactionDate.setCustomValidity('');
                    transactionDate.reportValidity();
                }
            }
            let internalTransferAmount = cmp.find('internalTransferAmount');
            if (internalTransferAmount) {
                if ($A.util.isEmpty(internalTransferAmount.get('v.value'))) {
                    internalTransferAmount.setCustomValidity('Complete this field.');
                    internalTransferAmount.reportValidity();
                    isValid = false;
                } else {
                    internalTransferAmount.setCustomValidity('');
                    internalTransferAmount.reportValidity();
                    internalTransferAmount.showHelpMessageIfInvalid();
                    if (isValid) {
                        isValid = internalTransferAmount.get('v.validity').valid
                    }
                }
            }
        }
        let messages = [];
        if (Number(cmp.get('v.totalPrincipalWrittenOff')) > Number(cmp.get('v.simpleRecord').sfims__Principal_Remaining__c)) {
            messages.push($A.get('$Label.c.aura_label_27'));
            isValid = false;
        }
        if (cmp.get('v.rescheduleLoan')) {
            if (Number(cmp.get('v.totalInterestWrittenOff')) > Number(cmp.get('v.simpleRecord').sfims__Interest_Overdue__c)) {
                messages.push($A.get('$Label.c.aura_label_29'));
                isValid = false;
            }
        }
        if (cmp.get('v.writeOff') || cmp.get('v.earlyRepayment')) {
            if (Number(cmp.get('v.totalInterestWrittenOff')) > Number(cmp.get('v.simpleRecord').sfims__Interest_Remaining__c)) {
                messages.push($A.get('$Label.c.aura_label_30'));
                isValid = false;
            }
            if (cmp.get('v.isInternalTransfer')) {
                if (Number(cmp.get('v.internalTransferAmount')) > Number(cmp.get('v.totalEarlyRepaymentAmount'))) {
                    messages.push('Amount cannot be more ' + Number(cmp.get('v.totalEarlyRepaymentAmount')) + '.');
                    isValid = false;
                }
            }
        }
        if (Number(cmp.get('v.totalFeesWrittenOff')) > Number(cmp.get('v.simpleRecord').sfims__Fees_Remaining__c)) {
            messages.push($A.get('$Label.c.aura_label_33'));
            isValid = false;
        }
        if (Number(cmp.get('v.totalPenaltiesWrittenOff')) > Number(cmp.get('v.simpleRecord').sfims__Late_Repayment_Fees_Remaining__c)) {
            messages.push($A.get('$Label.c.aura_label_35'));
            isValid = false;
        }
        cmp.set('v.isValid', isValid);
        helper.log('messages', messages);
        if (messages.length > 0) {
            let message = '';
            messages.forEach(function (msg) {
                message += msg + '\n'
            });
            cmp.find('message').showErrorMessage(message);
        }
        helper.end();
    },

    onChangeWrittenOffAmount: function (cmp, event, helper) {
        helper.begin('onChangeWrittenOffAmount');
        if (cmp.get('v.rescheduleLoan')) {
            cmp.set('v.rescheduleAmount', helper.calculateAmount(cmp));
        } else if (cmp.get('v.earlyRepayment')) {
            cmp.set('v.totalEarlyRepaymentAmount', helper.calculateAmount(cmp));
        }
        helper.end();
    },

    skipRemainingAmounts: function changeState(cmp, event, helper) {
        helper.begin('skipRemainingAmounts');
        cmp.set('v.isExpandedRemainingAmounts', !cmp.get('v.isExpandedRemainingAmounts'));
        helper.end();
    },

    skipWrittenOffAmounts: function changeState(cmp, event, helper) {
        helper.begin('skipWrittenOffAmounts');
        cmp.set('v.isExpandedWrittenOffAmounts', !cmp.get('v.isExpandedWrittenOffAmounts'));
        helper.end();
    }
});