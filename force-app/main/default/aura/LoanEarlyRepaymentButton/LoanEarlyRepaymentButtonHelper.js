({
    reloadRecordData: function (cmp) {
        this.begin('reloadRecordData');
        cmp.find('spinner').showSpinner('loadingRecordData');
        let recordData = cmp.find('recordData');
        if (recordData) {
            recordData.reloadRecord(true);
        } else {
            cmp.find('message').showErrorMessage('RecordData has not been found.');
        }
        this.end();
    },

    payOff: function (cmp, dataMap) {
        this.begin('payOff');
        let that = this;
        if ($A.util.isEmpty(dataMap)) {
            cmp.find('message').showErrorMessage('DataMap was not received.');
            that.end();
            return;
        }
        let spinner = cmp.find('spinner').showSpinner();
        let action = cmp.get('c.loanPayOff');
        action.setParams({
            dataMap: dataMap
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.begin('loanPayOff-SUCCESS');
                let result = response.getReturnValue();
                that.log(result);
                cmp.find('message').showSuccessMessage('Paying Off completed.');
                cmp.find('spinner').hideSpinner(spinner);
                $A.get('e.force:refreshView').fire();
                cmp.find('overlayLib').notifyClose();
                that.end();
            }
            else {
                that.begin('loanPayOff-ERROR');
                cmp.find('message').showErrorMessage(cmp.find('system').getAuraErrorsFromRequest(response.getError()));
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
        });
        $A.enqueueAction(action);
        this.end();
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