({
    doInit: function (cmp, event, helper) {
        console.log('%s, time: %f', 'doInit', helper.timeStamp());
        let simpleRecord = cmp.get('v.simpleRecord');
        let maxAmountToDisburse = Number(cmp.get('v.maxAmountToDisburse'));
        let disbursementAmount = Number(cmp.get('v.disbursementAmount'));
        if (simpleRecord['sfims__Disbursement_Method__c'] === 'Full disbursement at start') {
            cmp.set('v.label', $A.get("$Label.sfims.aura_label_104"));
        } else {
            cmp.set('v.label', $A.get("$Label.sfims.aura_label_104") + ' (' + $A.get("$Label.sfims.aura_label_111") + ': ' + (maxAmountToDisburse - disbursementAmount) + ')');
        }
    },

    validateAmount: function (cmp, event, helper) {
        console.group('%s, time: %f', 'validateAmount', helper.timeStamp());
        let disbursementAmount = Number(cmp.get('v.disbursementAmount'));
        let amount = Number(cmp.get('v.amount'));
        let loan = cmp.get('v.simpleRecord');
        if (disbursementAmount + amount > Number(loan.sfims__Amount__c)) {
            cmp.set('v.validationAmountError', true);
        } else {
            cmp.set('v.validationAmountError', false);
        }
        console.groupEnd();
    },

    validation: function (cmp, event, helper) {
        console.log('%s, time: %f', 'validation', helper.timeStamp());
        return helper.isValidForm(cmp);
    },
});