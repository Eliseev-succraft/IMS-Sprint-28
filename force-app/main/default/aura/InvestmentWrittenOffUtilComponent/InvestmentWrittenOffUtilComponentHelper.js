({
    calculateAmount: function (cmp) {
        this.begin('calculateAmount');
        let principalWrittenOff = 0,
            interestWrittenOff = 0,
            feesWrittenOff = 0,
            penaltiesWrittenOff = 0;
        if (cmp.get('v.totalPrincipalWrittenOff') && cmp.get('v.totalPrincipalWrittenOff') !== '') {
            principalWrittenOff = Number(cmp.get('v.totalPrincipalWrittenOff'));
        }
        if (cmp.get('v.totalInterestWrittenOff') && cmp.get('v.totalInterestWrittenOff') !== '') {
            interestWrittenOff = Number(cmp.get('v.totalInterestWrittenOff'));
        }
        if (cmp.get('v.totalFeesWrittenOff') && cmp.get('v.totalFeesWrittenOff') !== '') {
            feesWrittenOff = Number(cmp.get('v.totalFeesWrittenOff'));
        }
        if (cmp.get('v.totalPenaltiesWrittenOff') && cmp.get('v.totalPenaltiesWrittenOff') !== '') {
            penaltiesWrittenOff = Number(cmp.get('v.totalPenaltiesWrittenOff'));
        }
        let rec = cmp.get('v.simpleRecord');

        let interestAmount = 0,
            penaltiesAmount = 0;
        if (cmp.get('v.earlyRepayment')) {
            interestAmount = rec['sfims__Interest_Remaining__c'] - interestWrittenOff;
            penaltiesAmount = rec['sfims__Late_Repayment_Fees_Remaining__c'] - penaltiesWrittenOff;
        }
        let amount = rec['sfims__Principal_Remaining__c'] - principalWrittenOff + interestAmount + rec['sfims__Fees_Remaining__c'] - feesWrittenOff + penaltiesAmount;
        this.log('amount', amount);
        this.end();
        return amount;
    },

    begin: function (name) {
        if (this['isDebugLog']) {
            console.group('%s, time: %f', name, this.timeStamp());
        }
    },

    end: function () {
        if (this['isDebugLog']) {
            console.groupEnd();
        }
    },

    log: function (label, values, style) {
        if (this['isDebugLog']) {
            style = style || this['debugLogStyle'];
            if (values === undefined) {
                values = label;
                label = null;
            }
            if (Array.isArray(values)) {
                if (label !== null) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else if (typeof values === 'object') {
                if (label !== null) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else {
                if (label !== null) {
                    console.log('%c' + label + ' - ' + values, style);
                } else {
                    console.log('%c' + values, style);
                }
            }
        }
    },

    timeStamp: function () {
        return performance.now() / 1000;
    }
});