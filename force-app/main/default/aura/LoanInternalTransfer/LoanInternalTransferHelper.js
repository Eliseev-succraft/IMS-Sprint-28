({
    createTransferTransactions: function (cmp) {
        this.begin('createTransferTransactions');
        let that = this;
        if ($A.util.isEmpty(cmp.get('v.amount')) || $A.util.isEmpty(cmp.get('v.transactionDate')) || $A.util.isEmpty(that['fromLoanId']) || $A.util.isEmpty(that['toLoanId'])) {
            cmp.find('message').showErrorMessage('Required parameters were not received.');
            that.end();
            return;
        }
        let spinner = cmp.find('spinner').showSpinner();
        let action = cmp.get('c.createTransferTransactions');
        action.setParams({
            amount: cmp.get('v.amount'),
            transactionDate: cmp.get('v.transactionDate'),
            fromLoanId: that['fromLoanId'],
            toLoanId: that['toLoanId']
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.begin('createTransferTransactions-SUCCESS');
                cmp.find('message').showSuccessMessage('Internal Transfer was completed.');
                $A.get('e.force:refreshView').fire();
                that.cancelFromOverlayLib(cmp);
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
            else {
                that.begin('createTransferTransactions-ERROR');
                cmp.find('message').showErrorMessage(cmp.find('system').getAuraErrorsFromRequest(response.getError()));
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
        });
        $A.enqueueAction(action);
        this.end();
    },

    cancelFromOverlayLib: function (cmp) {
        this.begin('cancelFromOverlayLib');
        let overlayLib = cmp.find('overlayLib');
        if (overlayLib) {
            overlayLib.notifyClose();
        }
        this.end();
    },

    elementValidationStandard: function (cmp, element, label) {
        this.begin('elementValidationStandard');
        this.log('element: ' + element + ', label: ' + label);
        let response = false;
        let item = cmp.find(element);
        if (item) {
            item.showHelpMessageIfInvalid();
            response = item.get('v.validity').valid;
            if (response) {
                if ($A.util.isEmpty(item.get('v.value'))) {
                    response = false;
                }
            }
            if (!response) {
                this['errFields'].push(label);
            }
        } else {
            cmp.find('message').showErrorMessage('The element "' + element + '" was not found in the component markup.');
        }
        this.end();
        return response;
    },

    elementValidationCustom: function (cmp, element, label) {
        this.begin('elementValidationCustom');
        this.log('element: ' + element + ', label: ' + label);
        let response = false;
        let item = cmp.find(element);
        if (!$A.util.isEmpty(item)) {
            if ($A.util.isEmpty(item.get('v.value'))) {
                $A.util.addClass(item, 'error');
                $A.util.addClass(item, 'slds-has-error');
                if (label) {
                    this['errFields'].push({label: label, name: element});
                }
            } else {
                response = true;
                $A.util.removeClass(item, 'error');
                $A.util.removeClass(item, 'slds-has-error');
            }
        } else {
            cmp.find('message').showErrorMessage('The element "' + element + '" was not found in the component markup.');
        }
        this.end();
        return response;
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