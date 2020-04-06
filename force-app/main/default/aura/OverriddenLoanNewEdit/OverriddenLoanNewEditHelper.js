({
    navigateToSObject: function (recordId) {
        this.begin('navigateToSObject');
        let navEvt = $A.get('e.force:navigateToSObject');
        navEvt.setParams({
            recordId: recordId,
            isredirect: true
        });
        navEvt.fire();
        this.end();
    },

    statusFieldControl: function (cmp, event) {
        this.begin('statusFieldControl');
        let that = this;
        let spinner = cmp.find('spinner').showSpinner();
        let action = cmp.get('c.checkDisableValidationRules');
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.begin('checkDisableValidationRules-SUCCESS');
                let isAllValues = response.getReturnValue();
                let payload = event.getParams();
                if (payload) {
                    let statusOptions = [];
                    if (payload.hasOwnProperty('picklistValues')) {
                        if (payload.hasOwnProperty('recordUi')) {
                            if (payload['recordUi'].hasOwnProperty('record')) {
                                if (payload['recordUi']['record'].hasOwnProperty('fields')) {
                                    if (payload['recordUi']['record'].fields.hasOwnProperty('sfims__Status__c')) {
                                        let fields = payload['recordUi']['record'].fields;
                                        if (fields.sfims__Status__c.value) {
                                            cmp.set('v.selectedStatus', fields.sfims__Status__c.value);
                                        }
                                    }
                                }
                            }
                        }
                        let allowOptions = [];
                        if (isAllValues) {
                            statusOptions = cmp.get('v.statusOptions'); // get -- none --
                        } else {
                            if (!cmp.get('v.recordId')) { // new
                                allowOptions = ['Inactive'];
                            } else { // edit
                                switch (cmp.get('v.selectedStatus')) {
                                    case 'Active': {
                                        allowOptions = ['Active', 'Closed'];
                                        break;
                                    }
                                    case 'Inactive': {
                                        allowOptions = ['Inactive', 'Cancelled'];
                                        break;
                                    }
                                    default:
                                        allowOptions.push(cmp.get('v.selectedStatus'));
                                }
                            }
                            this.log(allowOptions);
                        }
                        if (payload.picklistValues.hasOwnProperty('sfims__Status__c')) {
                            // this['sfims__Status__c'] = payload.picklistValues.sfims__Status__c.values;
                            payload.picklistValues.sfims__Status__c.values.forEach(function (v) {
                                if (allowOptions.indexOf(v.value) !== -1 || isAllValues) {
                                    statusOptions.push({
                                        label: v.label,
                                        value: v.value
                                    });
                                }
                            });
                        }
                    }
                    if (statusOptions.length > 0) {
                        if (statusOptions.indexOf(cmp.get('v.selectedStatus')) !== -1) {
                            cmp.find('message').showErrorMessage('The "' + cmp.get('v.selectedStatus') + '" status was not found.');
                        }
                        cmp.set('v.statusOptions', statusOptions);
                    }
                }

                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
            else {
                that.begin('checkDisableValidationRules-ERROR');
                cmp.find('message').showErrorMessage(cmp.find('system').getAuraErrorsFromRequest(response.getError()));
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
        });
        $A.enqueueAction(action);
        this.end();
    },

    getFieldSets: function (cmp) {
        this.begin('getFieldSets');
        let that = this;
        let spinner = cmp.find('spinner').showSpinner();
        let action = cmp.get('c.getFieldSets');
        if (cmp.get('v.recordId')) {
            action.setParams({mode: 'edit'});
        }
        else {
            action.setParams({mode: 'new'});
        }
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.begin('getFieldSets-SUCCESS');
                let map = JSON.parse(response.getReturnValue());
                that.log('getFieldSets', map);
                if (map.hasOwnProperty('top')) {
                    cmp.set('v.topSections', that.formFieldSets(map['top']));
                }
                if (map.hasOwnProperty('bottom')) {
                    cmp.set('v.bottomSections', that.formFieldSets(map['bottom']));
                }
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
            else {
                that.begin('getFieldSets-ERROR');
                cmp.find('message').showErrorMessage(cmp.find('system').getAuraErrorsFromRequest(response.getError()));
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
        });
        $A.enqueueAction(action);
        this.end();
    },

    formFieldSets: function (fieldSets) {
        this.begin('formFieldSets');
        let that = this;
        let sections = [];
        fieldSets.forEach(function (fieldSet) {
            if (fieldSet.hasOwnProperty('Fields') && fieldSet['Fields'].length > 0) {
                let section = {};
                section['FieldSet'] = that.structureFields(fieldSet['Fields']);
                section['Label'] = fieldSet['Label'];
                sections.push(section);
            }
        });
        this.end();
        return sections;
    },

    structureFields: function (fields) {
        this.begin('structureFields');
        let newFields = [];
        let size = fields.length;
        for (let i = 0; i < size; i += 2) {
            let arr = [];
            if (fields[i + 1]) {
                arr = [fields[i], fields[i + 1]];
            } else {
                arr = [fields[i]];
            }
            newFields.push(arr);
        }
        this.end();
        return newFields;
    },

    getDefaultFieldValuesFromURL: function (cmp) {
        this.begin('getDefaultFieldValuesFromURL');
        let defaultFieldValues = cmp.get('v.defaultFieldValues');
        this['defaultFieldValuesMap'] = {};
        this.log('default field values', defaultFieldValues);
        if (defaultFieldValues) {
            let defaultFieldValuesMap = {};
            let params = defaultFieldValues.split(',');
            if (params.length > 0) {
                params.forEach(function (pr) {
                    let elements = pr.split('=');
                    if (elements.length === 2) {
                        elements[0] = elements[0].trim();
                        elements[1] = elements[1].trim();
                        if (elements[0] !== 'sfims__Loan_Product__c') {
                            defaultFieldValuesMap[elements[0]] = elements[1];
                            if (elements[0] === 'sfims__Application__c') {
                                cmp.find('spinner').showSpinner('application');
                                cmp.set('v.setApplicationId', elements[1]);
                            }
                        }
                    }
                });
            }
            this['defaultFieldValuesMap'] = defaultFieldValuesMap;
            if (defaultFieldValuesMap.hasOwnProperty('objectApiName')) {
                this['callBackObject'] = defaultFieldValuesMap['objectApiName'];
            }
        }
        this.end();
    },

    setDefaultFieldValuesFromURL: function (cmp) {
        this.begin('setDefaultFieldValuesFromURL');
        let that = this;
        let redefineList = [];
        that['redefine'].forEach(function (item) {
            redefineList.push(item.name);
        });
        let defaultValues = cmp.get('v.defaultValues');
        let syncTable = {
            sfims__Fund__c: 'sfims__Loan_Fund__c',
            sfims__Amount__c: 'sfims__Default_Loan_Amount__c',
            sfims__Interest_Rate__c: 'sfims__Default_Interest_Rate__c',
            sfims__Variable_Interest_Spread__c: 'sfims__Default_Variable_Interest_Spread__c'
        };
        that.log(that['defaultFieldValuesMap']);
        if (that['defaultFieldValuesMap']) {
            for (let key in that['defaultFieldValuesMap']) {
                if (that['defaultFieldValuesMap'].hasOwnProperty(key)) {
                    let fKey = key;
                    if (syncTable.hasOwnProperty(key)) {
                        fKey = syncTable[key];
                    }
                    let flagReplaceValue = true;
                    if (defaultValues.hasOwnProperty(fKey)) {
                        if (defaultValues[fKey].hasOwnProperty('disabled')) {
                            if (defaultValues[fKey]['disabled']) {
                                flagReplaceValue = false;
                                cmp.find('message').showWarningMessage('The \'' + key + '\' field was not replaced.');
                            }
                        }
                        if (flagReplaceValue) {
                            defaultValues[fKey]['default'] = that['defaultFieldValuesMap'][key];
                        }
                    } else {
                        let element = cmp.find(fKey);
                        if (element) {
                            element.set('v.value', that['defaultFieldValuesMap'][key]);
                        }
                    }
                    let topFieldSet = cmp.find('topFieldSet');
                    if (topFieldSet) {
                        if (Array.isArray(topFieldSet)) {
                            topFieldSet.forEach(function (element) {
                                if (element.get('v.fieldName') === key) {
                                    element.set('v.value', that['defaultFieldValuesMap'][key]);
                                }
                            });
                        } else {
                            if (topFieldSet.get('v.fieldName') === key) {
                                topFieldSet.set('v.value', that['defaultFieldValuesMap'][key]);
                            }
                        }
                    }
                    let bottomFieldSet = cmp.find('bottomFieldSet');
                    if (bottomFieldSet) {
                        if (Array.isArray(bottomFieldSet)) {
                            bottomFieldSet.forEach(function (element) {
                                if (element.get('v.fieldName') === key) {
                                    element.set('v.value', that['defaultFieldValuesMap'][key]);
                                }
                            });
                        } else {
                            if (bottomFieldSet.get('v.fieldName') === key) {
                                bottomFieldSet.set('v.value', that['defaultFieldValuesMap'][key]);
                            }
                        }
                    }
                }
            }
            cmp.set('v.defaultValues', defaultValues);
        }
        this.end();
    },

    setDefaultValuesFromLoanProductSettings: function (cmp) {
        this.begin('setDefaultValuesFromLoanProductSettings');
        let that = this;
        let spinner = cmp.find('spinner').showSpinner();
        let action = cmp.get('c.getLoanProductSettings');
        action.setParams({
            loanProductId: cmp.get('v.loanProductId'),
            loanId: cmp.get('v.recordId')
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.begin('getLoanProductSettings-SUCCESS');
                let responseMap = JSON.parse(response.getReturnValue());
                that.log('loan settings', responseMap);

                let gracePeriodsFromLoanProduct = [];
                if (responseMap['sfims__Grace_Period_Types__c']) {
                    let options = responseMap['sfims__Grace_Period_Types__c'].split(';');
                    that.log('grace periods', options);
                    gracePeriodsFromLoanProduct = [{
                        label: '--None--',
                        value: ''
                    }];
                    options.forEach(function (elm) {
                        let value = elm;
                        switch (elm) {
                            case 'No Grace':
                                value = 'None';
                                break;
                            case 'Pay Admin Fees Only':
                                value = 'Admin';
                                break;
                            case 'Pay Interest Only':
                                value = 'Interest';
                                break;
                            case 'Interest Rollup':
                                value = 'Interest Rollup';
                                break;
                            case 'Full Grace':
                                value = 'Full';
                                break;
                        }
                        gracePeriodsFromLoanProduct.push({
                            label: elm,
                            value: value
                        })
                    });
                    cmp.set('v.gracePeriodsFromLoanProduct', gracePeriodsFromLoanProduct);
                }
                if (responseMap['sfims__Late_Repayment_Calculation_Method__c']) {
                    switch (responseMap['sfims__Late_Repayment_Calculation_Method__c']) {
                        case 'No Penalty':
                            responseMap['sfims__Late_Repayment_Calculation_Method__c'] = 'No Penalty';
                            break;
                        case 'Fixed Fee':
                            responseMap['sfims__Late_Repayment_Calculation_Method__c'] = 'Fixed Fee';
                            break;
                        case 'Overdue Principal * # of Late Days * Penalty Rate':
                            responseMap['sfims__Late_Repayment_Calculation_Method__c'] = 'Principal';
                            break;
                        case '(Overdue Principal + Overdue Interest) * # of Late Days * Penalty Rate':
                            responseMap['sfims__Late_Repayment_Calculation_Method__c'] = 'Principal+Interest';
                            break;
                    }
                }
                if (responseMap['sfims__Early_Payment_Method__c']) {
                    switch (responseMap['sfims__Early_Payment_Method__c']) {
                        case 'Only Interest Due To Date Charged':
                            responseMap['sfims__Early_Payment_Method__c'] = 'interestDueToDate';
                            break;
                        case 'Full Interest For Scheduled Periods Charged':
                            responseMap['sfims__Early_Payment_Method__c'] = 'interestFullSchedule';
                            break;
                    }
                }
                let settingsMap = {};
                for (let key in responseMap) {
                    if (responseMap.hasOwnProperty(key)) {
                        let map = {};
                        let isCustomField = key.indexOf('__c');
                        if (isCustomField !== -1) {
                            if (responseMap[key] === null) {
                                responseMap[key] = '';
                            }
                            map['default'] = responseMap[key];
                            if (key.indexOf('CBO') === -1) {
                                let isPrefix = key.indexOf('__');
                                if (isPrefix !== isCustomField) {
                                    let prefix = key.substring(0, isPrefix + 2);
                                    let isKey = prefix + 'CBO_' + key.substring(isPrefix + 2);
                                    if (responseMap.hasOwnProperty(isKey)) {
                                        map['disabled'] = !responseMap[isKey];
                                    }
                                } else {
                                    let isKey = 'CBO_' + key;
                                    if (responseMap.hasOwnProperty(isKey)) {
                                        map['disabled'] = !responseMap[isKey];
                                    }
                                }
                            } else {
                                map['disabled'] = !responseMap[key];
                            }
                            if (key.indexOf('Default') !== -1) {
                                let str = key;
                                let minKey = str.replace('Default', 'Minimum');
                                if (responseMap.hasOwnProperty(minKey) && responseMap[minKey] !== '') {
                                    map['min'] = responseMap[minKey];
                                }
                                let maxKey = str.replace('Default', 'Maximum');
                                if (responseMap.hasOwnProperty(maxKey) && responseMap[maxKey] !== '') {
                                    map['max'] = responseMap[maxKey];
                                }
                            }
                            settingsMap[key] = map;
                        }
                    }
                }
                if (responseMap['sfims__Open_Ended_Loan__c'] === true) {
                    cmp.set('v.isOpenEndedLoan', true);
                }
                if (responseMap['sfims__Interest_Rate_Source__c'] === 'Variable Interest') {
                    cmp.set('v.showVariableInterestRate', true);
                }
                let defGracePeriod = '';
                if (!cmp.get('v.recordId')) {
                    if (gracePeriodsFromLoanProduct.length === 2) {
                        cmp.find('sfims__Grace_Period_Type__c').set('v.value', gracePeriodsFromLoanProduct[1].value);
                        defGracePeriod = gracePeriodsFromLoanProduct[1].value;
                    }
                }
                settingsMap['sfims__First_Repayment_Date__c'] = {
                    default: null,
                    disabled: false
                };
                settingsMap['input__sfims__First_Repayment_Date__c'] = {
                    default: null,
                    disabled: false
                };
                settingsMap['sfims__Grace_Period_Type__c'] = {
                    default: defGracePeriod,
                    disabled: false
                };
                settingsMap['sfims__Number_of_Grace_Periods__c'] = {
                    default: responseMap['sfims__Default_Grace_Period__c'],
                    disabled: false
                };
                settingsMap['sfims__Late_Repayment_Tolerance_Period__c'] = {
                    default: responseMap['sfims__Default_Arrears_Tolerance_Period_days__c'],
                    disabled: !responseMap['sfims__CBO_Late_Repayment_Tolerance_Period__c']
                };
                settingsMap['sfims__Number_of_Instalments__c'] = {
                    default: responseMap['sfims__Default_number_of_installments__c'],
                    disabled: !responseMap['sfims__CBO_Default_number_of_installments__c']
                };
                settingsMap['sfims__Monitoring_Fee_Percentage__c'] = {
                    default: responseMap['sfims__Default_Monitoring_Fee_Percentage__c'],
                    disabled: !responseMap['sfims__CBO_Default_Monitoring_Fee_Percentage__c']
                };
                if (settingsMap.hasOwnProperty('sfims__Percent_Of_Disbursement_Amount__c')) {
                    let tmp = settingsMap['sfims__Percent_Of_Disbursement_Amount__c'];
                    delete settingsMap['sfims__Percent_Of_Disbursement_Amount__c'];
                    settingsMap['sfims__Percent_of_Disbursement_Amount__c'] = tmp;
                }

                that.log('settings', settingsMap);
                cmp.set('v.defaultValues', settingsMap);
                that.setDefaultFieldValuesFromURL(cmp);
                // let ownerId = this['ownerId'] || '';
                for (let key in settingsMap) {
                    if (settingsMap.hasOwnProperty(key)) {
                        if (cmp.find(key)) {
                            if (!cmp.get('v.recordId') && settingsMap[key]['default']) cmp.find(key).set('v.value', settingsMap[key]['default']);
                            cmp.find(key).set('v.disabled', settingsMap[key]['disabled']);
                            //---------- OLD VERSION ----------
                            // if (!cmp.get('v.recordId')) { // new, owner
                            //     cmp.find(key).set('v.value', settingsMap[key]['default']);
                            // } else {
                            //     if (!(this['profile']['Name'] === 'System Administrator' || this['user']['Id'] === ownerId['value'])) {
                            //         cmp.find(key).set('v.disabled', settingsMap[key]['disabled']);
                            //     }
                            // }
                            // --------------------------------
                        }
                    }
                }
                that.checkOpenEndedLoan(cmp);
                that.checkSetupFeeChargingMethod(cmp);
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
            else {
                that.begin('getLoanProductSettings-ERROR');
                cmp.find('message').showErrorMessage(cmp.find('system').getAuraErrorsFromRequest(response.getError()));
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
        });
        $A.enqueueAction(action);
        this.end();
    },

    getUserProfileInfo: function (cmp) {
        this.begin('getUserProfileInfo');
        let that = this;
        let spinner = cmp.find('spinner').showSpinner();
        let action = cmp.get('c.getUserProfileInfo');
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.begin('getUserProfileInfo-SUCCESS');
                let map = response.getReturnValue();
                that.log('user', map['user']);
                that.log('profile', map['profile']);
                that['user'] = map['user'];
                that['profile'] = map['profile'];
                that.getAllDefaultValues(cmp);
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
            else {
                that.begin('getUserProfileInfo-ERROR');
                cmp.find('message').showErrorMessage(cmp.find('system').getAuraErrorsFromRequest(response.getError()));
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
        });
        $A.enqueueAction(action);
        this.end();
    },

    removeSpecialClass: function (cmp, element) {
        this.begin('removeSpecialClass');
        if ($A.util.hasClass(element, 'custom-required-' + element)) {
            $A.util.removeClass(element, 'custom-required-' + element);
        }
        if ($A.util.hasClass(element, 'error')) {
            $A.util.removeClass(element, 'error');
        }
        if ($A.util.hasClass(element, 'slds-has-error')) {
            $A.util.removeClass(element, 'slds-has-error');
        }
        this.end();
    },

    setFieldParameters: function (cmp, fields, logic) {
        this.begin('setFieldParameters');
        let defaultValues = cmp.get('v.defaultValues');
        let that = this;
        if (logic) {
            fields.forEach(function (field) {
                let isSetDisabled = false;
                let isSetValue = false;
                if (defaultValues.hasOwnProperty(field)) {
                    if (defaultValues[field].hasOwnProperty('disabled')) {
                        if (!defaultValues[field]['disabled']) {
                            if (cmp.find(field)) {
                                cmp.find(field).set('v.disabled', false);
                                isSetDisabled = true;
                            } else {
                                that.log('field not found in markup - ' + field);
                            }
                        }
                    } else {
                        that.log('properties not found - ' + field);
                    }
                    if (defaultValues[field].hasOwnProperty('default')) {
                        if (cmp.find(field)) {
                            if (defaultValues[field]['default'] === null) {
                                defaultValues[field]['default'] = '';
                            }
                            if (!cmp.get('v.recordId')) {
                                cmp.find(field).set('v.value', defaultValues[field]['default']);
                            } else {
                                if (cmp.find(field).get('v.value') === '') {
                                    cmp.find(field).set('v.value', defaultValues[field]['default']);
                                }
                            }
                            that.log('set ' + field + ' ' + cmp.find(field).get('v.value'));
                            isSetValue = true;
                        } else {
                            that.log('field not found in markup - ' + field);
                        }
                    }
                } else {
                    that.log('field not found - ' + field);
                }
                if (!isSetDisabled) {
                    let elm = cmp.find(field);
                    if (elm) {
                        that.removeSpecialClass(cmp, elm);
                        elm.set('v.disabled', true);
                    }
                }
                if (!isSetValue) {
                    if (cmp.find(field)) {
                        that.log('set empty - ' + field);
                        cmp.find(field).set('v.value', '');
                    }
                }
            });
        }
        else {
            fields.forEach(function (field) {
                let elm = cmp.find(field);
                if (elm) {
                    that.removeSpecialClass(cmp, elm);
                    cmp.find(field).set('v.disabled', true);
                    cmp.find(field).set('v.value', '');
                }
            });
        }
        this.end();
    },

    checkSetupFeeChargingMethod: function (cmp) {
        this.begin('checkSetupFeeChargingMethod');
        let setupFeeChargingMethod__c = cmp.find('sfims__Setup_Fee_Charging_Method__c').get('v.value');
        this.setFieldParameters(cmp, ['sfims__Setup_Fee__c'], (setupFeeChargingMethod__c !== '' && setupFeeChargingMethod__c !== 'No Setup Fee'));
        this.checkSetupFeeFields(cmp);
        this.end();
    },

    checkShowLateRepaymentFields: function (cmp) {
        this.begin('checkShowLateRepaymentFields');
        let lateRepaymentCalculationMethod = cmp.find('sfims__Late_Repayment_Calculation_Method__c').get('v.value');
        switch (lateRepaymentCalculationMethod) {
            case 'No Penalty':
                this.setFieldParameters(cmp, [
                    'sfims__Late_Repayment_Fixed_Fee__c',
                    'sfims__Late_Repayment_Interest_Rate__c',
                    'sfims__Late_Repayment_Tolerance_Period__c'
                ], false);
                break;
            case 'Fixed Fee':
                this.setFieldParameters(cmp, ['sfims__Late_Repayment_Fixed_Fee__c', 'sfims__Late_Repayment_Tolerance_Period__c'], true);
                this.setFieldParameters(cmp, ['sfims__Late_Repayment_Interest_Rate__c'], false);
                break;
            case 'Principal':
            case 'Principal+Interest':
                this.setFieldParameters(cmp, ['sfims__Late_Repayment_Interest_Rate__c', 'sfims__Late_Repayment_Tolerance_Period__c'], true);
                this.setFieldParameters(cmp, ['sfims__Late_Repayment_Fixed_Fee__c'], false);
                break;
        }
        this.end();
    },

    checkSetupFeeFields: function (cmp) {
        this.begin('checkSetupFeeFields');
        let setupFee = cmp.find('sfims__Setup_Fee__c').get('v.value');
        this.setFieldParameters(cmp, ['sfims__Percent_of_Disbursement_Amount__c', 'sfims__Setup_Fee_Cap__c'], setupFee === '% of Disbursement Amount');
        this.setFieldParameters(cmp, ['sfims__Flat_Amount__c'], setupFee === 'Flat Amount');
        this.end();
    },

    checkGracePeriodType: function (cmp) {
        this.begin('checkGracePeriodType');
        let gracePeriodType = cmp.find('sfims__Grace_Period_Type__c').get('v.value');
        this.setFieldParameters(cmp, ['sfims__Number_of_Grace_Periods__c'], (gracePeriodType !== '' && gracePeriodType !== 'None'));
        this.end();
    },

    checkOpenEndedLoan: function (cmp) {
        this.begin('checkOpenEndedLoan');
        let fields = [
            'sfims__First_Repayment_Date__c',
            'input__sfims__First_Repayment_Date__c',
            'sfims__Number_of_Instalments__c',
            'sfims__Late_Repayment_Calculation_Method__c',
            'sfims__Late_Repayment_Fixed_Fee__c',
            'sfims__Late_Repayment_Interest_Rate__c',
            'sfims__Late_Repayment_Tolerance_Period__c',
            'sfims__Repayment_Frequency__c',
            'sfims__Repayment_Frequency_Unit__c',
            'sfims__Grace_Period_Type__c',
            'sfims__Early_Payment_Method__c',
            'sfims__Number_of_Grace_Periods__c',
            'sfims__Non_Working_Days_Rescheduling__c',
            'sfims__Monitoring_Fee_Percentage__c'
        ];
        if (cmp.find('sfims__Open_Ended_Loan__c').get('v.value')) {
            let that = this;
            cmp.set('v.isOpenEndedLoan', true);
            fields.forEach(function (field) {
                let elm = cmp.find(field);
                if (elm) {
                    that.removeSpecialClass(cmp, elm);
                    elm.set('v.disabled', true);
                    elm.set('v.value', null);
                }
            });
        } else {
            cmp.set('v.isOpenEndedLoan', false);
            this.setFieldParameters(cmp, fields, !cmp.find('sfims__Open_Ended_Loan__c').get('v.value'));
            this.checkGracePeriodType(cmp);
            this.checkShowLateRepaymentFields(cmp);
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

    formValidation: function (cmp, fields) {
        this.begin('formValidation');
        this.log('fields', fields);
        this['errFields'] = [];
        let response = true;
        let that = this;
        fields.forEach(function (field) {
            console.log(field);
            if (!that.elementValidationCustom(cmp, field.name, field.label)) {
                response = false;
            }
        });
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