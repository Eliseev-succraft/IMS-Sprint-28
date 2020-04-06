({
    doInit: function (cmp, event, helper) {
        helper['customRefresh'] = false;
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['debugLogStyle'] = 'background: green; color: white;';
        helper['defaultFieldValues'] = '';
        helper.begin('doInit');
        if (helper['isDebugLog'] === undefined) {
            cmp.find('message').showErrorMessage('The "isDebugLog" attribute was not found in the component markup.');
            helper.end();
            return;
        }
        helper['callBackObject'] = 'sfims__Investment__c';
        helper['setFirstDefaultValues'] = false;
        cmp.find('spinner').showSpinner('form');
        helper.getDefaultFieldValuesFromURL(cmp);
        helper['redefine'] = [{
            name: 'sfims__Disbursement_Date__c',
            attribute: 'v.input__disbursementDate',
            required: true
        }, {
            name: 'sfims__First_Repayment_Date__c',
            attribute: 'v.input__firstRepaymentDate',
            required: false
        }];
        helper.getFieldSets(cmp);
        helper.end();
    },

    handleCancel: function (cmp, event, helper) {
        helper.begin('handleCancel');
        helper.log(helper['callBackObject']);
        if (cmp.get('v.runWithActionPanel')) {
            cmp.set('v.runWithActionPanel', false);
            // cmp.find('navigation').navigateToSObject(cmp.get('v.recordId'));
        } else {
            cmp.find('navigation').navigateToObjectHome(helper['callBackObject']);
        }
        helper.end();
    },

    formLoad: function (cmp, event, helper) {
        if (!helper['setFirstDefaultValues']) {
            helper.begin('formLoad');
            helper.statusFieldControl(cmp, event);
            helper['setFirstDefaultValues'] = true;
            let payload = event.getParams();
            helper.log('loan', payload);
            helper['recordUi'] = payload;
            if (payload) {
                if (payload.hasOwnProperty('recordUi')) {
                    if (payload['recordUi'].hasOwnProperty('record')) {
                        if (payload['recordUi']['record'].hasOwnProperty('fields')) {
                            helper['fields'] = JSON.parse(JSON.stringify(payload['recordUi']['record']['fields']));
                            if (cmp.get('v.recordId')) {
                                if (helper['fields'].hasOwnProperty('Name')) {
                                    cmp.set('v.recordName', helper['fields']['Name']['value']);
                                }
                                if (helper['fields'].hasOwnProperty('sfims__Grace_Period_Type__c')) {
                                    cmp.find('sfims__Grace_Period_Type__c').set('v.value', helper['fields']['sfims__Grace_Period_Type__c']['value']);
                                }
                            }
                            helper['redefine'].forEach(function (field) {
                                if (helper['fields'].hasOwnProperty(field.name)) {
                                    if (helper['fields'][field.name].hasOwnProperty('value')) {
                                        cmp.set(field.attribute, helper['fields'][field.name].value);
                                    }
                                }
                            });
                            if (!helper['fields'].hasOwnProperty('sfims__Grace_Period_Type__c')) {
                                helper['fields']['sfims__Grace_Period_Type__c'] = {};
                            }
                        }
                    }
                    if (payload['recordUi'].hasOwnProperty('objectInfo')) {
                        if (payload['recordUi']['objectInfo'].hasOwnProperty('fields')) {
                            helper['objectInfo'] = JSON.parse(JSON.stringify(payload['recordUi']['objectInfo']['fields']));
                            helper['redefine'].forEach(function (field) {
                                if (helper['objectInfo'].hasOwnProperty(field.name)) {
                                    if (helper['fields'].hasOwnProperty(field.name)) {
                                        if (helper['fields'][field.name].hasOwnProperty('value')) {
                                            cmp.set(field.attribute + 'Label', helper['objectInfo'][field.name].label);
                                        }
                                    }
                                }
                            });
                        }
                    }
                }
            }
            helper.setDefaultValuesFromLoanProductSettings(cmp);
            cmp.find('spinner').hideSpinner('form');
        }
        helper.end();
    },

    handleChangeOpenEndedLoan: function (cmp, event, helper) {
        helper.begin('handleChangeOpenEndedLoan');
        helper.checkOpenEndedLoan(cmp);
        helper.end();
    },

    handleChangeSetupFeeChargingMethod: function (cmp, event, helper) {
        helper.begin('handleChangeSetupFeeChargingMethod');
        helper.checkSetupFeeChargingMethod(cmp);
        helper.end();
    },

    handleChangeSetupFee: function (cmp, event, helper) {
        helper.begin('handleChangeSetupFee');
        helper.checkSetupFeeFields(cmp);
        helper.end();
    },

    handleChangeGracePeriodType: function (cmp, event, helper) {
        helper.begin('handleChangeGracePeriodType');
        helper.checkGracePeriodType(cmp);
        helper.end();
    },

    handleChangeLateRepaymentCalculationMethod: function (cmp, event, helper) {
        helper.begin('handleChangeLateRepaymentCalculationMethod');
        helper.checkShowLateRepaymentFields(cmp);
        helper.end();
    },

    handleApplicationRecordUpdated: function (cmp, event, helper) {
        helper.begin('handleApplicationRecordUpdated');
        let params = event.getParams();
        helper.log('type', params['changeType']);
        if (params['changeType'] === 'LOADED') {
            let application = cmp.get('v.applicationRecordTargetFields');
            if (application) {
                cmp.find('sfims__Account__c').set('v.value', application['sfims__Organisation__c']);
                cmp.find('sfims__Loan_Fund__c').set('v.value', application['sfims__Fund__c']);
            }
        }
        else if (params['changeType'] === 'CHANGED') {
            let recordData = cmp.find('recordData');
            if (recordData) {
                recordData.reloadRecord(true);
            } else {
                cmp.find('message').showErrorMessage('RecordData has not been found.');
            }
        }
        else if (params['changeType'] === 'ERROR') {
            cmp.find('message').showErrorMessage('RecordData has not been loaded.');
        }
        cmp.find('spinner').hideSpinner('application');
        helper.end();
    },

    formError: function (cmp, event, helper) {
        helper.begin('formError');
        let errors = event.getParams();
        helper.log('Form errors', errors);
        let groupErr = {};
        if (errors) {
            let syncTable = {
                sfims__Fund__c: 'sfims__Loan_Fund__c',
                sfims__Amount__c: 'sfims__Default_Loan_Amount__c',
                sfims__Interest_Rate__c: 'sfims__Default_Interest_Rate__c',
                sfims__Variable_Interest_Spread__c: 'sfims__Default_Variable_Interest_Spread__c'
            };
            let redefineList = [];
            helper['redefine'].forEach(function (item) {
                redefineList.push(item.name);
            });
            if (errors.hasOwnProperty('output')) {
                if (errors.output.hasOwnProperty('fieldErrors')) {
                    helper['fieldErrors'] = errors.output.fieldErrors;
                    helper.log('fieldErrors', helper['fieldErrors']);
                    // control filled fields
                    if (helper['oldFieldErrors']) {
                        for (let key in helper['oldFieldErrors']) {
                            if (helper['oldFieldErrors'].hasOwnProperty(key)) {
                                if (!helper['fieldErrors'].hasOwnProperty(key)) {
                                    let fKey = key;
                                    if (syncTable.hasOwnProperty(key)) {
                                        fKey = syncTable[key];
                                    }
                                    let item = cmp.find(fKey);
                                    if (redefineList.indexOf(fKey) !== -1) {
                                        item = cmp.find('input__' + fKey);
                                    }
                                    helper.removeSpecialClass(cmp, item);
                                }
                            }
                        }
                    }
                    // END control filled fields
                    for (let key in errors.output.fieldErrors) {
                        if (errors.output.fieldErrors.hasOwnProperty(key)) {
                            // show validation errors on redefine values
                            if (redefineList.indexOf(key) !== -1) {
                                //  helper.elementValidationCustom(cmp, 'input__' + key);
                            }
                            // END show validation errors on redefine values
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
            if (cssMsgErr.length > 0) {
                helper.log('err', cssMsgErr);
                cmp.set('v.reloadCss', false);
                cmp.set('v.cssMsgErr', cssMsgErr);
                cmp.set('v.reloadCss', true);
                let validationFields = Object.keys(helper['fieldErrors']);
                validationFields.forEach(function (key) {
                    let fKey = key;
                    if (syncTable.hasOwnProperty(key)) {
                        fKey = syncTable[key];
                    }
                    if (redefineList.indexOf(key) !== -1) {
                        fKey = 'input__' + key;
                    }
                    let item = cmp.find(fKey);
                    if (item) {
                        $A.util.addClass(item, 'custom-required-' + key);
                        $A.util.addClass(item, 'error');
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
        cmp.find('spinner').hideSpinner('submit');
        cmp.find('spinner').hideSpinner('form');
        helper.end();
    },

    handleSubmit: function (cmp, event, helper) {
        helper.begin('handleSubmit');
        cmp.find('spinner').showSpinner('submit');
        // show validation errors on redefine values
        /*
        helper['redefine'].forEach(function (key) {
            let item = cmp.find('input__' + key.name);
            if (item) {
                $A.util.removeClass(item, 'error');
                $A.util.removeClass(item, 'slds-has-error');
            } else {
                cmp.find('message').showErrorMessage('The element "' + key.name + '" was not found.');
            }
        });*/
        // END show validation errors on redefine values
        helper.log('record fields', helper['fields']);
        let syncTable = {
            sfims__Fund__c: 'sfims__Loan_Fund__c',
            sfims__Amount__c: 'sfims__Default_Loan_Amount__c',
            sfims__Interest_Rate__c: 'sfims__Default_Interest_Rate__c',
            sfims__Variable_Interest_Spread__c: 'sfims__Default_Variable_Interest_Spread__c'
        };
        let fields = {};
        if (helper['fields']) {
            for (let key in helper['fields']) {
                if (helper['fields'].hasOwnProperty(key)) {
                    let foreignKey = key;
                    if (syncTable.hasOwnProperty(key)) {
                        foreignKey = syncTable[key];
                    }
                    let element = cmp.find(foreignKey);
                    if (element) {
                        if (!$A.util.isEmpty(element.get('v.value'))) {
                            fields[key] = element.get('v.value');
                        } else {
                            fields[key] = null;
                        }
                    }
                }
            }
        }
/*
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
*/
        if (!fields['RecordTypeId']) {
            fields['RecordTypeId'] = cmp.get('v.loanRecordTypeId');
        }
        if (!fields['sfims__Loan_Product__c']) {
            fields['sfims__Loan_Product__c'] = cmp.get('v.loanProductId');
        }
        fields['sfims__Grace_Period_Type__c'] = cmp.find('sfims__Grace_Period_Type__c').get('v.value');
        if (cmp.get('v.showVariableInterestRate')) {
            fields['sfims__Interest_Rate__c'] = '';
        } else {
            fields['sfims__Variable_Interest_Spread__c'] = '';
        }
        helper.log('fields', fields);
        cmp.find('formLoan').submit(fields);
        helper.end();
    },

    formSuccess: function (cmp, event, helper) {
        helper.begin('formSuccess');
        let record = event.getParams().response;
        if (!$A.util.isEmpty(record.id)) {
            // cmp.set('v.recordId', record.id);
            cmp.find('message').showSuccessMessage('The Loan was saved.');
            helper.navigateToSObject(record.id);
        } else {
            cmp.find('message').showErrorMessage('The Loan was not saved.');
            cmp.find('navigation').navigateToObjectHome(helper['callBackObject']);
        }
        cmp.find('spinner').hideSpinner('submit');
        helper.end();
    },

    handlePreview: function (cmp, event, helper) {
        helper.begin('handlePreview');
        // show validation errors on redefine values
        /*
          helper['redefine'].forEach(function (key) {
              let item = cmp.find('input__' + key.name);
              if (item) {
                  $A.util.removeClass(item, 'error');
                  $A.util.removeClass(item, 'slds-has-error');
              } else {
                  cmp.find('message').showErrorMessage('The element "' + key.name + '" was not found.');
              }
          });*/
        // END show validation errors on redefine values
        cmp.set('v.isPreview', false);
        helper['loan'] = {};
        let change = {
            sfims__Amount__c: 'sfims__Default_Loan_Amount__c',
            sfims__Interest_Rate__c: 'sfims__Default_Interest_Rate__c',
            sfims__Variable_Interest_Spread__c: 'sfims__Default_Variable_Interest_Spread__c'
        };
        if (helper['fields']) {
            for (let key in helper['fields']) {
                if (helper['fields'].hasOwnProperty(key)) {
                    let element = cmp.find(key);
                    if (element) {
                        if (!$A.util.isEmpty(element.get('v.value'))) {
                            helper['loan'][key] = element.get('v.value');
                        } else {
                            helper['loan'][key] = null;
                        }
                    } else {
                        if (change.hasOwnProperty(key)) {
                            let element = cmp.find(change[key]);
                            if (element) {
                                if (!$A.util.isEmpty(element.get('v.value'))) {
                                    helper['loan'][key] = element.get('v.value');
                                } else {
                                    helper['loan'][key] = null;
                                }
                            }
                        }
                    }
                }
            }
        }
        if (helper['loan']['sfims__Open_Ended_Loan__c']) {
            cmp.find('message').showErrorMessage('Not available for open-ended loans.');
        } else {
            if (!helper['loan']['sfims__Loan_Product__c']) {
                if (helper['fields']['sfims__Loan_Product__c']) helper['loan']['sfims__Loan_Product__c'] = helper['fields']['sfims__Loan_Product__c'].value;
                else helper['loan']['sfims__Loan_Product__c'] = cmp.get('v.loanProductId');
            }
            helper['loan']['sfims__Grace_Period_Type__c'] = cmp.find('sfims__Grace_Period_Type__c').get('v.value');

            helper.log(helper['loan']);
            cmp.find('spinner').showSpinner('submit');
            let action = cmp.get('c.generateSchedule');
            action.setParams({
                theLoanString: JSON.stringify(helper['loan']),
                preview: true
            });
            action.setCallback(this, function (response) {
                let state = response.getState();
                if (state === 'SUCCESS') {
                    helper.begin('generateSchedule-SUCCESS');
                    if (helper['fields']) {
                        for (let key in helper['fields']) {
                            if (helper['fields'].hasOwnProperty(key)) {
                                let element = cmp.find(key);
                                if (element) {
                                    if ($A.util.hasClass(element, 'error')) {
                                        $A.util.removeClass(element, 'error');
                                    }
                                    if ($A.util.hasClass(element, 'slds-has-error')) {
                                        $A.util.removeClass(element, 'slds-has-error');
                                    }
                                } else {
                                    if (change.hasOwnProperty(key)) {
                                        let element = cmp.find(change[key]);
                                        if (element) {
                                            if ($A.util.hasClass(element, 'error')) {
                                                $A.util.removeClass(element, 'error');
                                            }
                                            if ($A.util.hasClass(element, 'slds-has-error')) {
                                                $A.util.removeClass(element, 'slds-has-error');
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    let map = response.getReturnValue();
                    if (map.hasOwnProperty('error')) {
                        cmp.find('message').showErrorMessage(map['error']);
                    } else {
                        let previewRecords = JSON.parse(map['schedules']);

                        // console.log(JSON.parse(JSON.stringify(previewRecords)));
                        if (previewRecords) {
                            if (Array.isArray(previewRecords)) {
                                previewRecords.forEach(function (record) {
                                    record['sfims__Interest_Expected__c'] = Number(record['sfims__Interest_Expected_Standard_Loan__c']);
                                    record['sfims__Total_Expected__c'] = Number(record['sfims__Principal_Expected__c']) + Number(record['sfims__Interest_Expected_Standard_Loan__c']) + Number(record['sfims__Fees_Expected__c']);
                                });
                            }
                            if (map['variableInterest']) {
                                cmp.find('message').showWarningMessage(map['variableInterest']);
                            }
                            cmp.set('v.previewRecords', previewRecords);
                            cmp.set('v.isPreview', true);
                            cmp.set('v.previewColumns', [
                                {label: 'Due Date', fieldName: 'sfims__Due_Date__c', type: 'date-local'},
                                {
                                    label: 'Total Due',
                                    fieldName: 'sfims__Total_Expected__c',
                                    type: 'currency',
                                    typeAttributes: {minimumFractionDigits: '2'}
                                },
                                {
                                    label: 'Principal Due',
                                    fieldName: 'sfims__Principal_Expected__c',
                                    type: 'currency',
                                    typeAttributes: {minimumFractionDigits: '2'}
                                },
                                {
                                    label: 'Interest Due',
                                    fieldName: 'sfims__Interest_Expected__c',
                                    type: 'currency',
                                    typeAttributes: {minimumFractionDigits: '2'}
                                },
                                {
                                    label: 'Fees Due',
                                    fieldName: 'sfims__Fees_Expected__c',
                                    type: 'currency',
                                    typeAttributes: {minimumFractionDigits: '2'}
                                }
                            ]);
                            window.setTimeout(
                                $A.getCallback(function () {
                                    cmp.find('preview').getElement().scrollIntoView();
                                }), 100);
                            console.groupEnd();
                        } else {
                            cmp.find('message').showErrorMessage('There are no repayment schedules for the loan with specified parameters');
                        }
                    }
                    cmp.find('spinner').hideSpinner('submit');
                    helper.end();
                }
                else {
                    helper.begin('generateSchedule-ERROR');
                    cmp.find('formLoan').submit(helper['loan']);
                    // cmp.find('spinner').hideSpinner(spinner);
                    helper.end();
                }
            });
            $A.enqueueAction(action);
            helper.end();
        }
    },

    handleSaveAndGenerateSchedule: function (cmp, event, helper) {
        helper.begin('handleSaveAndGenerateSchedule');

        /*
        // show validation errors on redefine values
        helper['redefine'].forEach(function (key) {
            let item = cmp.find('input__' + key.name);
            if (item) {
                $A.util.removeClass(item, 'error');
                $A.util.removeClass(item, 'slds-has-error');
            } else {
                cmp.find('message').showErrorMessage('The element "' + key.name + '" was not found.');
            }
        });*/
        // END show validation errors on redefine values

        helper['loan'] = {};
        let change = {
            sfims__Amount__c: 'sfims__Default_Loan_Amount__c',
            sfims__Interest_Rate__c: 'sfims__Default_Interest_Rate__c',
            sfims__Variable_Interest_Spread__c: 'sfims__Default_Variable_Interest_Spread__c'
        };
        if (helper['fields']) {
            for (let key in helper['fields']) {
                if (helper['fields'].hasOwnProperty(key)) {
                    let element = cmp.find(key);
                    if (element) {
                        if (!$A.util.isEmpty(element.get('v.value'))) {
                            helper['loan'][key] = element.get('v.value');
                        } else {
                            helper['loan'][key] = null;
                        }
                    } else {
                        if (change.hasOwnProperty(key)) {
                            let element = cmp.find(change[key]);
                            if (element) {
                                if (!$A.util.isEmpty(element.get('v.value'))) {
                                    helper['loan'][key] = element.get('v.value');
                                } else {
                                    helper['loan'][key] = null;
                                }
                            }
                        }
                    }
                }
            }
        }
        let topFieldSet = cmp.find('topFieldSet');
        if (topFieldSet) {
            if (Array.isArray(topFieldSet)) {
                topFieldSet.forEach(function (element) {
                    if (element.get('v.fieldName')) {
                        helper['loan'][element.get('v.fieldName')] = element.get('v.value');
                    }
                });
            } else {
                if (topFieldSet.get('v.fieldName')) {
                    helper['loan'][topFieldSet.get('v.fieldName')] = topFieldSet.get('v.value');
                }
            }

        }
        let bottomFieldSet = cmp.find('bottomFieldSet');
        if (bottomFieldSet) {
            if (Array.isArray(bottomFieldSet)) {
                bottomFieldSet.forEach(function (element) {
                    if (element.get('v.fieldName')) {
                        helper['loan'][element.get('v.fieldName')] = element.get('v.value');
                    }
                });
            } else {
                if (bottomFieldSet.get('v.fieldName')) {
                    helper['loan'][bottomFieldSet.get('v.fieldName')] = bottomFieldSet.get('v.value');
                }
            }
        }

        if (helper['loan']['sfims__Status__c'] !== 'Inactive') {
            cmp.find('message').showErrorMessage('Available only for inactive loans.');
        } else {
            // let spinner = helper.showSpinner(cmp, 'v.isLoading');
            cmp.find('spinner').showSpinner('submit');
            if (!helper['loan']['sfims__Loan_Product__c']) {
                if (helper['fields']['sfims__Loan_Product__c'] && helper['fields']['sfims__Loan_Product__c'].value) helper['loan']['sfims__Loan_Product__c'] = helper['fields']['sfims__Loan_Product__c'].value;
                else helper['loan']['sfims__Loan_Product__c'] = cmp.get('v.loanProductId');
            }
            if (cmp.get('v.recordId')) helper['loan']['Id'] = cmp.get('v.recordId');
            helper['loan']['sfims__Grace_Period_Type__c'] = cmp.find('sfims__Grace_Period_Type__c').get('v.value');

            let action = cmp.get('c.generateSchedule');
            action.setParams({
                theLoanString: JSON.stringify(helper['loan']),
                preview: false
            });
            action.setCallback(this, function (response) {
                let state = response.getState();
                if (state === 'SUCCESS') {
                    helper.begin('generateSchedule-SUCCESS');
                    if (helper['fields']) {
                        for (let key in helper['fields']) {
                            if (helper['fields'].hasOwnProperty(key)) {
                                let element = cmp.find(key);
                                if (element) {
                                    if ($A.util.hasClass(element, 'error')) {
                                        $A.util.removeClass(element, 'error');
                                    }
                                    if ($A.util.hasClass(element, 'slds-has-error')) {
                                        $A.util.removeClass(element, 'slds-has-error');
                                    }
                                } else {
                                    if (change.hasOwnProperty(key)) {
                                        let element = cmp.find(change[key]);
                                        if (element) {
                                            if ($A.util.hasClass(element, 'error')) {
                                                $A.util.removeClass(element, 'error');
                                            }
                                            if ($A.util.hasClass(element, 'slds-has-error')) {
                                                $A.util.removeClass(element, 'slds-has-error');
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    let map = response.getReturnValue();
                    if (map.hasOwnProperty('error')) {
                        //  helper.hideSpinner(cmp, 'v.isLoading', spinner);
                        cmp.find('message').showErrorMessage(map['error']);
                    } else {
                        //   cmp.set('v.recordId', map['success']);
                        //    helper.hideSpinner(cmp, 'v.isLoading', spinner);

                        if (!$A.util.isEmpty(map['success'])) {
                            // cmp.set('v.recordId', record.id);
                            cmp.find('message').showSuccessMessage('The Loan has been saved and scheduled successfully.');
                            helper.navigateToSObject(map['success']);
                        } else {
                            cmp.find('message').showErrorMessage('The Loan was not saved.');
                            cmp.find('navigation').navigateToObjectHome(helper['callBackObject']);
                        }

                    }
                    cmp.find('spinner').hideSpinner('submit');
                    helper.end();
                }
                else {
                    helper.begin('generateSchedule-ERROR');
                    //helper.hideSpinner(cmp, 'v.isLoading', spinner);
                    cmp.find('formLoan').submit(helper['loan']);
                    helper.end();
                }
            });
            $A.enqueueAction(action);

        }
        helper.end();
    }
});