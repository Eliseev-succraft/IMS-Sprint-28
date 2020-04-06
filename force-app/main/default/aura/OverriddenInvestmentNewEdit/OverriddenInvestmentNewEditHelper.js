({
    fetchData: function (cmp) {
        this.begin('fetchData');
        let that = this;
        let action = cmp.get('c.apexGetRecordTypeInfo');
        action.setParams({
            objectName: 'sfims__Investment__c'
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.begin('fetchData-SUCCESS');
                let recordTypes = response.getReturnValue();
                that.log('apexGetRecordTypeInfo', recordTypes);
                if (recordTypes) {
                    that['recordTypes'] = recordTypes;
                    let options = [];
                    for (let key in recordTypes) {
                        if (recordTypes.hasOwnProperty(key)) {
                            if (recordTypes[key] === 'Loan') {
                                cmp.set('v.loanRecordTypeId', key);
                            }
                            options.push({label: recordTypes[key], value: key});
                        }
                    }
                    options.reverse();
                    if (options.length > 0) {
                        cmp.set('v.selectedRecordTypeId', options[0].value);
                    }
                    cmp.set('v.options', options);
                    if (cmp.get('v.pageReference').attributes.actionName === 'new' && that['selectedRecordTypeIdFromURL'] === '') {
                        let modal = cmp.find('section');
                        if (modal) {
                            $A.util.addClass(modal, 'slds-fade-in-open');
                        }
                    }
                    if (that['pageReference'].attributes.actionName === 'edit' || (cmp.get('v.loanRecordTypeId') === that['selectedRecordTypeIdFromURL'] && that['selectedRecordTypeIdFromURL']) || (options.length === 1)) {
                        let action = cmp.get('c.handleNext');
                        action.setParams({cmp: cmp, event: event, helper: that});
                        cmp.find('mainSpinner').hideSpinner('init');
                        $A.enqueueAction(action);
                    }
                } else {
                    cmp.find('message').showErrorMessage('Record types were not received.');
                }
                cmp.find('mainSpinner').hideSpinner('init');
                that.end();
            }
            else {
                that.begin('fetchData-ERROR');
                cmp.find('message').showErrorMessage(cmp.find('system').getAuraErrorsFromRequest(response.getError()));
                cmp.find('mainSpinner').hideSpinner('init');
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
                console.log(values);
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