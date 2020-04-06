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
        let messages = [];
        if (Number(cmp.get('v.totalPrincipalWrittenOff')) > Number(cmp.get('v.simpleRecord').sfims__Principal_Remaining__c)) {
            messages.push($A.get('$Label.c.aura_label_27'));
        }
        if (cmp.get('v.rescheduleLoan')) {
            if (Number(cmp.get('v.totalInterestWrittenOff')) > Number(cmp.get('v.simpleRecord').sfims__Interest_Overdue__c)) {
                messages.push($A.get('$Label.c.aura_label_29'));
            }
        }
        if (cmp.get('v.writeOff') || cmp.get('v.earlyRepayment')) {
            if (Number(cmp.get('v.totalInterestWrittenOff')) > Number(cmp.get('v.simpleRecord').sfims__Interest_Remaining__c)) {
                messages.push($A.get('$Label.c.aura_label_30'));
            }
        }
        if (Number(cmp.get('v.totalFeesWrittenOff')) > Number(cmp.get('v.simpleRecord').sfims__Fees_Remaining__c)) {
            messages.push($A.get('$Label.c.aura_label_33'));
        }
        if (Number(cmp.get('v.totalPenaltiesWrittenOff')) > Number(cmp.get('v.simpleRecord').sfims__Late_Repayment_Fees_Remaining__c)) {
            messages.push($A.get('$Label.c.aura_label_35'));
        }
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