({
    doInit: function (cmp, event, helper) {
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['debugLogStyle'] = 'background: green; color: white;';
        helper['callBackObject'] = 'sfims__Loan_Product__c';
        helper.begin('doInit');
        helper.log('initialization');
        helper.end();
    },

    afterLoadingLibraries: function (cmp, event, helper) {
        helper.begin('afterLoadingLibraries');
        helper['customRefresh'] = false;
        if (helper['isDebugLog'] === undefined) {
            cmp.find('message').showErrorMessage('The "isDebugLog" attribute was not found in the component markup.');
            helper.end();
            return;
        }
        cmp.find('spinner').showSpinner('form');
        helper.getFieldSets(cmp);
        helper.end();
    },

    customRefresh: function (cmp, event, helper) {
        if (!helper['customRefresh']) {
            helper.begin('customRefresh');
            helper['customRefresh'] = true;
            $A.get('e.force:refreshView').fire();
            helper.end();
        }
    },

    handleStartSpinner: function (cmp, event, helper) {
        helper.begin('handleStartSpinner');
        cmp.set('v.isLoading', true);
        helper.end();
    },

    handleStopSpinner: function (cmp, event, helper) {
        helper.begin('handleStopSpinner');
        cmp.set('v.isLoading', false);
        helper.end();
    },

    handleCancel: function (cmp, event, helper) {
        helper.begin('handleCancel');
        helper.cancel(cmp);
        helper.end();
    },

    formLoad: function (cmp, event, helper) {
        helper.begin('formLoad');
        let payload = event.getParams();
        helper.setDefaultValuesFromCustomSettings(cmp);
        helper.log('product', payload);
        helper['recordUi'] = payload;
        if (payload) {
            if (payload.hasOwnProperty('recordUi')) {
                if (payload['recordUi'].hasOwnProperty('record')) {
                    if (payload['recordUi']['record'].hasOwnProperty('fields')) {
                        let simpleRecord = JSON.parse(JSON.stringify(payload['recordUi']['record']['fields']));
                        helper.log('simpleRecord', simpleRecord);
                        if (simpleRecord.hasOwnProperty('Name') && cmp.get('v.recordId')) {
                            cmp.set('v.loanProductName', simpleRecord['Name']['value']);
                        }
                        helper.isClone(cmp);
                    }
                }
            }
        }
        let currentOrder = cmp.find('sfims__Repayment_Allocation_Order__c').get('v.value');
        if (currentOrder) {
            cmp.set('v.oldRepaymentAllocationOrder', currentOrder);
        }
        cmp.find('spinner').hideSpinner('form');
        helper.end();
    },

    formError: function (cmp, event, helper) {
        helper.begin('formError');
        let errors = event.getParams();
        helper.log('errors', errors);
        let groupErr = {};
        if (errors) {
            if (errors.hasOwnProperty('output')) {
                if (errors.output.hasOwnProperty('fieldErrors')) {
                    helper['fieldErrors'] = errors.output.fieldErrors;
                    // control filled fields
                    if (helper['oldFieldErrors']) {
                        for (let key in helper['oldFieldErrors']) {
                            if (helper['oldFieldErrors'].hasOwnProperty(key)) {
                                if (!helper['fieldErrors'].hasOwnProperty(key)) {
                                    let item = cmp.find(key);
                                    helper.removeSpecialClass(item);
                                }
                            }
                        }
                    }
                    // END control filled fields
                    for (let key in errors.output.fieldErrors) {
                        if (errors.output.fieldErrors.hasOwnProperty(key)) {
                            for (let i = 0; i < errors.output.fieldErrors[key].length; i++) {
                                if (errors.output.fieldErrors[key][i].hasOwnProperty('message')) {
                                    if (!groupErr.hasOwnProperty(errors.output.fieldErrors[key][i]['message'])) {
                                        groupErr[errors.output.fieldErrors[key][i]['message']] = [];
                                    }
                                    groupErr[errors.output.fieldErrors[key][i]['message']].push({
                                        label: errors.output.fieldErrors[key][i]['fieldLabel'],
                                        name: key
                                    });
                                }
                            }
                        }
                    }
                    helper['oldFieldErrors'] = errors.output.fieldErrors;
                }
            }
            let msg = '';
            helper.log('groupErr', groupErr);
            let cssMsgErr = [];
            for (let key in groupErr) {
                if (groupErr.hasOwnProperty(key)) {
                    let size = groupErr[key].length;
                    let points = '';
                    if (size > 0) {
                        for (let i = 0; i < size; i++) {
                            points += '- ' + groupErr[key][i]['label'] + '\n';
                            cssMsgErr.push({
                                name: groupErr[key][i]['name'],
                                message: key
                            });
                        }
                    }
                    if (points !== '') {
                        // msg += key + '\n' + points;
                        msg += key + '\n';
                    }
                }
            }
            if (cssMsgErr) {
                console.log(cssMsgErr);
                cmp.set('v.reloadCss', false);
                cmp.set('v.cssMsgErr', cssMsgErr);
                cmp.set('v.reloadCss', true);
                let validationFields = Object.keys(helper['fieldErrors']);
                validationFields.forEach(function (element) {
                    let item = cmp.find(element);
                    console.log('custom-required-' + element);
                    if (!$A.util.hasClass(item, 'custom-required-' + element)) {
                        $A.util.addClass(item, 'custom-required-' + element);
                    }
                    if (!$A.util.hasClass(item, 'error')) {
                        $A.util.addClass(item, 'error');
                    }
                    if (!$A.util.hasClass(item, 'slds-has-error')) {
                        $A.util.addClass(item, 'slds-has-error');
                    }
                });
            }
            if (msg !== '') {
                cmp.find('message').showErrorMessage(msg);
            } else if (errors['detail']) {
                cmp.find('message').showErrorMessage(errors['detail']);
            } else if (errors['message']) {
                cmp.find('message').showErrorMessage(errors['message']);
            }
        }
        cmp.find('spinner').hideSpinner('form');
        helper.end();
    },


    formSubmit: function (cmp, event, helper) {
        helper.begin('formSubmit');
        helper['fieldErrors'] = [];
        event.preventDefault();
        cmp.find('spinner').showSpinner('form');
/*
        let validationFields = [
            {name: 'Name'},
            {name: 'sfims__Interest_Rate_Source__c'},
            {name: 'sfims__Grace_Period_Types__c'},
            {name: 'sfims__Repayment_Allocation_Type__c'}
        ];

        let recordUiFields = {};
        if (helper['recordUi']) {
            if (helper['recordUi'].hasOwnProperty('recordUi')) {
                if (helper['recordUi']['recordUi'].hasOwnProperty('objectInfo')) {
                    if (helper['recordUi']['recordUi']['objectInfo'].hasOwnProperty('fields')) {
                        recordUiFields = helper['recordUi']['recordUi']['objectInfo']['fields'];
                    }
                }
            }
        }

        validationFields.forEach(function (item) {
            if (!item.hasOwnProperty('label')) {
                item['label'] = '';
            }
            if (recordUiFields.hasOwnProperty(item.name)) {
                if (recordUiFields[item.name].hasOwnProperty('label')) {
                    item['label'] = recordUiFields[item.name].label;
                }
            }
        });


        if (!helper.formValidation(cmp, validationFields)) {
            cmp.find('spinner').hideSpinner('form');
            if (helper['errFields']) {
                let size = helper['errFields'].length;
                let msg = '';
                if (size > 0) {
                    for (let i = 0; i < size; i++) {
                        msg += '- ' + helper['errFields'][i].label + '\n';
                    }
                }
                if (msg !== '') {
                    cmp.find('message').showErrorMessage('Please check and fill in the required fields' + ': \n' + msg);
                }
            } else {
                cmp.find('message').showErrorMessage('Please check and fill in the required fields.');
            }
        } else {*/
            let fields = event.getParam('fields');
            if (cmp.get('v.isClone')) {
                cmp.set('v.recordId', null);
            }
            fields['sfims__Repayment_Allocation_Order__c'] = cmp.get('v.newRepaymentAllocationOrder');

            let topFieldSet = cmp.find('topFieldSet');
            if (topFieldSet) {
                if (Array.isArray(topFieldSet)) {
                    topFieldSet.forEach(function (element) {
                        if (element.get('v.fieldName')) {
                            fields[element.get('v.fieldName')] = element.get('v.value');
                        }
                    });
                } else {
                    if (topFieldSet.get('v.fieldName')) {
                        fields[topFieldSet.get('v.fieldName')] = topFieldSet.get('v.value');
                    }
                }
            }
            let bottomFieldSet = cmp.find('bottomFieldSet');
            if (bottomFieldSet) {
                if (Array.isArray(bottomFieldSet)) {
                    bottomFieldSet.forEach(function (element) {
                        if (element.get('v.fieldName')) {
                            fields[element.get('v.fieldName')] = element.get('v.value');
                        }
                    });
                } else {
                    if (bottomFieldSet.get('v.fieldName')) {
                        fields[bottomFieldSet.get('v.fieldName')] = bottomFieldSet.get('v.value');
                    }
                }
            }

            helper.log('save', fields);
            cmp.find('formLoanProduct').submit(fields);
       // }
        helper.end();
    },

    formSuccess: function (cmp, event, helper) {
        helper.begin('formSuccess');
        let record = event.getParams().response;
        if (!$A.util.isEmpty(record.id)) {
            cmp.set('v.recordId', record.id);
            cmp.find('message').showSuccessMessage('The Loan Product was saved.');
        } else {
            cmp.find('message').showErrorMessage('The Loan Product was not saved.');
        }
        helper.cancel(cmp);
        helper.end();
    },

    onChangeInterestRateSource: function (cmp, event, helper) {
        helper.begin('onChangeInterestRateSource');
        helper.checkInterestRateSource(cmp);
        helper.end();
    },

    onChangeGracePeriodTypes: function (cmp, event, helper) {
        helper.begin('onChangeGracePeriodTypes');
        helper.checkGracePeriodType(cmp);
        helper.end();
    },

    onChangeLateRepaymentCalculationMethod: function (cmp, event, helper) {
        helper.begin('onChangeLateRepaymentCalculationMethod');
        helper.checkLateRepaymentCalculationMethod(cmp);
        helper.end();
    },

    onChangeSetupFeeChargingMethod: function (cmp, event, helper) {
        helper.begin('onChangeSetupFeeChargingMethod');
        helper.checkChargingMethod(cmp);
        helper.end();
    },

    onChangeSetupFee: function (cmp, event, helper) {
        helper.begin('onChangeSetupFee');
        helper.checkSetupFeeFields(cmp);
        helper.end();
    }
});