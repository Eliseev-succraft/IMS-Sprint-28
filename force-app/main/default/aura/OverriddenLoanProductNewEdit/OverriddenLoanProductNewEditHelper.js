({
    cancel: function (cmp) {
        this.begin('cancel');
        if (cmp.get('v.isRunning')) {
            cmp.set('v.isRunning', false);
        } else {
            if (!cmp.get('v.recordId')) {
                cmp.find('navigation').navigateToObjectHome(this['callBackObject']);
            } else {
                let navEvt = $A.get('e.force:navigateToSObject');
                navEvt.setParams({
                    recordId: cmp.get('v.recordId'),
                    isredirect: true
                });
                navEvt.fire();
            }
        }
        this.end();
    },

    isClone: function (cmp) {
        this.begin('isClone');
        this['defaultFieldValuesMap'] = {};
        let pageReference = cmp.get('v.pageReference');
        this.log('pageReference', pageReference);
        if (pageReference.hasOwnProperty('state')) {
            if (pageReference.state.hasOwnProperty('defaultFieldValues')) {
                this['defaultFieldValues'] = pageReference.state.defaultFieldValues;
                if (this['defaultFieldValues']) {
                    let defaultFieldValuesMap = {};
                    let params = this['defaultFieldValues'].split(',');
                    if (params.length > 0) {
                        params.forEach(function (pr) {
                            let elements = pr.split('=');
                            if (elements.length === 2) {
                                elements[0] = elements[0].trim();
                                elements[1] = elements[1].trim();
                                defaultFieldValuesMap[elements[0]] = elements[1];
                            }
                        });
                    }
                    this['defaultFieldValuesMap'] = defaultFieldValuesMap;
                }
            }
        }
        if (this['defaultFieldValuesMap'].hasOwnProperty('isClone')) {
            cmp.set('v.isClone', this['defaultFieldValuesMap']['isClone']);
        }
        this.end();
    },

    setDefaultValuesFromCustomSettings: function (cmp) {
        this.begin('setDefaultValuesFromCustomSettings');
        let that = this;
        let spinner = cmp.find('spinner').showSpinner();
        let action = cmp.get('c.getOrgSettings');
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.begin('setDefaultValuesFromCustomSettings-SUCCESS');
                that.log('default values', response.getReturnValue());
                let responseMap = response.getReturnValue();
                that['getAllDefaultValues'] = responseMap;
                // disabled component
                if (!responseMap['sfims__CBO_Repayment_Allocation_Order__c']) {
                    cmp.set('v.isDisabledRepaymentAllocationOrder', true);
                }
                if (responseMap.hasOwnProperty('sfims__CBO_Late_Repayment_Tolerance_Period__c')) {
                    if (!responseMap['sfims__CBO_Late_Repayment_Tolerance_Period__c']) {
                        cmp.find('sfims__Minimum_Arrears_Tolerance_Period__c').set('v.disabled', true);
                        cmp.find('sfims__Maximum_Arrears_Tolerance_Period_days__c').set('v.disabled', true);
                    }
                }
                if (responseMap.hasOwnProperty('sfims__CBO_Monitoring_Fee_Percentage__c')) {
                    if (!responseMap['sfims__CBO_Monitoring_Fee_Percentage__c']) {
                        cmp.find('sfims__Minimum_Monitoring_Fee_Percentage__c').set('v.disabled', true);
                        cmp.find('sfims__Maximum_Monitoring_Fee_Percentage__c').set('v.disabled', true);
                    }
                }
                let settingsMap = {};
                for (let key in responseMap) {
                    if (responseMap.hasOwnProperty(key)) {
                        let map = {};
                        let isCustomField = key.indexOf('__c');
                        if (isCustomField !== -1) {
                            if (key.indexOf('CBO') === -1) {
                                map['default'] = responseMap[key];
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
                            settingsMap[key] = map;
                        }
                    }
                }
                let syncTable = {
                    sfims__Monitoring_Fee_Percentage__c: 'sfims__Default_Monitoring_Fee_Percentage__c',
                    sfims__CBO_Monitoring_Fee_Percentage__c: 'sfims__CBO_Default_Monitoring_Fee_Percentage__c'
                };
                that.log(settingsMap);
                for (let key in settingsMap) {
                    if (settingsMap.hasOwnProperty(key)) {
                        let foreignKey = key;
                        if (syncTable.hasOwnProperty(key)) {
                            foreignKey = syncTable[key];
                        }
                        if (cmp.find(foreignKey)) {
                            if (!cmp.get('v.recordId') && settingsMap[key].hasOwnProperty('default')) {
                                cmp.find(foreignKey).set('v.value', settingsMap[key]['default']);
                            }
                            cmp.find(foreignKey).set('v.disabled', settingsMap[key]['disabled']);
                        }
                    }
                }
                that.checkInterestRateSource(cmp);
                that.checkGracePeriodType(cmp);
                that.checkChargingMethod(cmp);
                that.checkLateRepaymentCalculationMethod(cmp);
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
            else {
                that.begin('setDefaultValuesFromCustomSettings-ERROR');
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
                that.log(map);
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
        this.begin('getFieldSets');
        let that = this;
        this.log(fieldSets);
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
        this.log(newFields);
        this.end();
        return newFields;
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

    checkInterestRateSource: function (cmp) {
        this.begin('checkInterestRateSource');
        let interestRateSource = cmp.find('sfims__Interest_Rate_Source__c').get('v.value') || '';
        this.setFieldParameters(cmp, [
            {name: 'sfims__Minimum_Interest_Rate__c', setAttr: 'v.value', setValue: ''},
            {name: 'sfims__Maximum_Interest_Rate__c', setAttr: 'v.value', setValue: ''},
            {name: 'sfims__Default_Interest_Rate__c', setAttr: 'v.value', setValue: ''},
            {name: 'sfims__CBO_Default_Interest_Rate__c', setAttr: 'v.value', setValue: false},
        ], (interestRateSource !== '' && interestRateSource === 'Fixed Interest'));
        this.setFieldParameters(cmp, [
            {name: 'sfims__Interest_Reference_Rate__c', setAttr: 'v.value', setValue: ''},
            {name: 'sfims__Interest_Rate_Review_Frequency__c', setAttr: 'v.value', setValue: ''},
            {name: 'sfims__Minimum_Interest_Bandwidth__c', setAttr: 'v.value', setValue: ''},
            {name: 'sfims__Maximum_Interest_Bandwidth__c', setAttr: 'v.value', setValue: ''},
            {name: 'sfims__Default_Variable_Interest_Spread__c', setAttr: 'v.value', setValue: ''},
            {name: 'sfims__CBO_Default_Variable_Interest_Spread__c', setAttr: 'v.value', setValue: false}
        ], (interestRateSource !== '' && interestRateSource === 'Variable Interest'));
        this.end();
    },

    checkGracePeriodType: function (cmp) {
        this.begin('checkGracePeriodType');
        let gracePeriodType = cmp.find('sfims__Grace_Period_Types__c').get('v.value') || '';
        this.setFieldParameters(cmp, [
            {name: 'sfims__Minimum_Grace_Period__c', setAttr: 'v.value', setValue: ''},
            {name: 'sfims__Maximum_Grace_Period__c', setAttr: 'v.value', setValue: ''},
            {name: 'sfims__Default_Grace_Period__c', setAttr: 'v.value', setValue: ''}
        ], (gracePeriodType !== '' && gracePeriodType !== 'No Grace'));
        this.end();
    },

    setFieldDefaultValue: function (cmp, field) {
        this.begin('setFieldDefaultValue');
        if (!cmp.get('v.recordId')) {
            let cboField = '';
            let isCustomField = field.indexOf('__c');
            if (isCustomField !== -1) {
                if (field.indexOf('CBO') === -1) {
                    let isPrefix = field.indexOf('__');
                    if (isPrefix !== isCustomField) {
                        let prefix = field.substring(0, isPrefix + 2);
                        cboField = prefix + 'CBO_' + field.substring(isPrefix + 2);
                    } else {
                        cboField = 'CBO_' + field;
                    }
                }
            }
            let getAllDefaultValues = this['getAllDefaultValues'];
            if (getAllDefaultValues.hasOwnProperty(field)) {
                let element = cmp.find(field);
                if (element) {
                    element.set('v.value', getAllDefaultValues[field]);
                    if (getAllDefaultValues.hasOwnProperty(cboField)) {
                        element.set('v.disabled', !getAllDefaultValues[cboField]);
                        let element_cbo = cmp.find(cboField);
                        if (element_cbo) {
                            element_cbo.set('v.value', false);
                            element_cbo.set('v.disabled', !getAllDefaultValues[cboField]);
                        }
                    }
                }
            }
        }
        this.end();
    },

    checkChargingMethod: function (cmp) {
        this.begin('checkChargingMethod');
        if (!cmp.get('v.recordId')) {
            let sfims__Setup_Fee_Charging_Method__c = cmp.find('sfims__Setup_Fee_Charging_Method__c');
            let sfims__CBO_Setup_Fee_Charging_Method__c = cmp.find('sfims__CBO_Setup_Fee_Charging_Method__c');
            if (sfims__Setup_Fee_Charging_Method__c && sfims__CBO_Setup_Fee_Charging_Method__c) {
                if ((sfims__Setup_Fee_Charging_Method__c.get('v.value') === 'No Setup Fee' || sfims__Setup_Fee_Charging_Method__c.get('v.value') === '') && !sfims__CBO_Setup_Fee_Charging_Method__c.get('v.value')) {
                    let sfims__Setup_Fee__c = cmp.find('sfims__Setup_Fee__c');
                    if (sfims__Setup_Fee__c) {
                        sfims__Setup_Fee__c.set('v.disabled', true);
                        sfims__Setup_Fee__c.set('v.value', '');
                    }
                    ['sfims__Percent_Of_Disbursement_Amount__c', 'sfims__Flat_Amount__c', 'sfims__Setup_Fee_Cap__c'].forEach(function (field) {
                        let elm = cmp.find(field);
                        if (elm) {
                            elm.set('v.disabled', true);
                            elm.set('v.value', '');
                        }
                    });
                    ['sfims__CBO_Setup_Fee__c', 'sfims__CBO_Percent_Of_Disbursement_Amount__c', 'sfims__CBO_Flat_Amount__c', 'sfims__CBO_Setup_Fee_Cap__c'].forEach(function (field) {
                        let elm = cmp.find(field);
                        if (elm) {
                            elm.set('v.disabled', true);
                            elm.set('v.value', false);
                        }
                    });
                } else {
                    let sfims__Setup_Fee__c = cmp.find('sfims__Setup_Fee__c');
                    let sfims__CBO_Setup_Fee__c = cmp.find('sfims__CBO_Setup_Fee__c');
                    if (sfims__Setup_Fee__c && sfims__CBO_Setup_Fee__c) {
                        if (sfims__Setup_Fee__c.get('v.disabled') && sfims__Setup_Fee__c.get('v.value') === '') {
                            this.setFieldDefaultValue(cmp, 'sfims__Setup_Fee__c');
                        }
                        this.checkSetupFeeFields(cmp);
                    }
                }
            }
        }
        this.end();
    },

    checkSetupFeeFields: function (cmp) {
        this.begin('checkSetupFeeFields');
        if (!cmp.get('v.recordId')) {
            let that = this;
            let sfims__Setup_Fee__c = cmp.find('sfims__Setup_Fee__c');
            let sfims__CBO_Setup_Fee__c = cmp.find('sfims__CBO_Setup_Fee__c');
            if (sfims__Setup_Fee__c && sfims__CBO_Setup_Fee__c) {
                if (sfims__CBO_Setup_Fee__c.get('v.value')) { // Setup Fee - can override
                    ['sfims__Percent_Of_Disbursement_Amount__c', 'sfims__Flat_Amount__c'].forEach(function (field) {
                        that.setFieldDefaultValue(cmp, field);
                    });
                    let sfims__Setup_Fee_Cap__c = cmp.find('sfims__Setup_Fee_Cap__c');
                    let sfims__CBO_Setup_Fee_Cap__c = cmp.find('sfims__CBO_Setup_Fee_Cap__c');
                    if (sfims__Setup_Fee_Cap__c && sfims__CBO_Setup_Fee_Cap__c) {
                        sfims__Setup_Fee_Cap__c.set('v.disabled', false);
                        sfims__Setup_Fee_Cap__c.set('v.value', '');
                        sfims__CBO_Setup_Fee_Cap__c.set('v.disabled', false);
                        sfims__CBO_Setup_Fee_Cap__c.set('v.value', false);
                    }
                } else { // Setup Fee - can not override
                    if (sfims__Setup_Fee__c.get('v.value') !== '') {
                        if (sfims__Setup_Fee__c.get('v.value') === 'Flat Amount') {
                            that.setFieldDefaultValue(cmp, 'sfims__Flat_Amount__c');
                            let sfims__Percent_Of_Disbursement_Amount__c = cmp.find('sfims__Percent_Of_Disbursement_Amount__c');
                            if (sfims__Percent_Of_Disbursement_Amount__c) {
                                sfims__Percent_Of_Disbursement_Amount__c.set('v.disabled', true);
                                sfims__Percent_Of_Disbursement_Amount__c.set('v.value', '');
                            }
                            let sfims__CBO_Percent_Of_Disbursement_Amount__c = cmp.find('sfims__CBO_Percent_Of_Disbursement_Amount__c');
                            if (sfims__CBO_Percent_Of_Disbursement_Amount__c) {
                                sfims__CBO_Percent_Of_Disbursement_Amount__c.set('v.value', false);
                                sfims__CBO_Percent_Of_Disbursement_Amount__c.set('v.disabled', true);
                            }
                            let sfims__Setup_Fee_Cap__c = cmp.find('sfims__Setup_Fee_Cap__c');
                            let sfims__CBO_Setup_Fee_Cap__c = cmp.find('sfims__CBO_Setup_Fee_Cap__c');
                            if (sfims__Setup_Fee_Cap__c && sfims__CBO_Setup_Fee_Cap__c) {
                                sfims__Setup_Fee_Cap__c.set('v.value', '');
                                sfims__Setup_Fee_Cap__c.set('v.disabled', true);
                                sfims__CBO_Setup_Fee_Cap__c.set('v.value', false);
                                sfims__CBO_Setup_Fee_Cap__c.set('v.disabled', true);
                            }
                        } else {
                            if (sfims__Setup_Fee__c.get('v.value') === '% of Disbursement Amount') {
                                that.setFieldDefaultValue(cmp, 'sfims__Percent_Of_Disbursement_Amount__c');
                                let sfims__Flat_Amount__c = cmp.find('sfims__Flat_Amount__c');
                                if (sfims__Flat_Amount__c) {
                                    sfims__Flat_Amount__c.set('v.disabled', true);
                                    sfims__Flat_Amount__c.set('v.value', '');
                                }
                                let sfims__CBO_Flat_Amount__c = cmp.find('sfims__CBO_Flat_Amount__c');
                                if (sfims__CBO_Flat_Amount__c) {
                                    sfims__CBO_Flat_Amount__c.set('v.value', false);
                                    sfims__CBO_Flat_Amount__c.set('v.disabled', true);
                                }
                                let sfims__Setup_Fee_Cap__c = cmp.find('sfims__Setup_Fee_Cap__c');
                                let sfims__CBO_Setup_Fee_Cap__c = cmp.find('sfims__CBO_Setup_Fee_Cap__c');
                                if (sfims__Setup_Fee_Cap__c && sfims__CBO_Setup_Fee_Cap__c) {
                                    sfims__Setup_Fee_Cap__c.set('v.disabled', false);
                                    sfims__Setup_Fee_Cap__c.set('v.value', '');
                                    sfims__CBO_Setup_Fee_Cap__c.set('v.disabled', false);
                                    sfims__CBO_Setup_Fee_Cap__c.set('v.value', false);
                                }
                            }
                        }
                    } else { // Setup Fee = --None--
                        ['sfims__Percent_Of_Disbursement_Amount__c', 'sfims__Flat_Amount__c', 'sfims__Setup_Fee_Cap__c'].forEach(function (field) {
                            let elm = cmp.find(field);
                            if (elm) {
                                elm.set('v.disabled', true);
                                elm.set('v.value', '');
                            }
                        });
                        ['sfims__CBO_Percent_Of_Disbursement_Amount__c', 'sfims__CBO_Flat_Amount__c', 'sfims__CBO_Setup_Fee_Cap__c'].forEach(function (field) {
                            let elm = cmp.find(field);
                            if (elm) {
                                elm.set('v.disabled', true);
                                elm.set('v.value', false);
                            }
                        });
                    }
                }
            }
        }
        this.end();
    },

    checkLateRepaymentCalculationMethod: function (cmp) {
        this.begin('checkLateRepaymentCalculationMethod');
        if (!cmp.get('v.recordId')) {
            let that = this;
            let sfims__Late_Repayment_Calculation_Method__c = cmp.find('sfims__Late_Repayment_Calculation_Method__c');
            let sfims__CBO_Late_Repayment_Calculation_Method__c = cmp.find('sfims__CBO_Late_Repayment_Calculation_Method__c');
            switch (sfims__Late_Repayment_Calculation_Method__c.get('v.value')) {
                case '':
                case 'No Penalty':
                    if (!sfims__CBO_Late_Repayment_Calculation_Method__c.get('v.value')) {
                        ['sfims__Late_Repayment_Interest_Rate__c', 'sfims__Late_Repayment_Fixed_Fee__c', 'sfims__Late_Repayment_Tolerance_Period__c', 'sfims__Minimum_Arrears_Tolerance_Period__c', 'sfims__Maximum_Arrears_Tolerance_Period_days__c'].forEach(function (field) {
                            let elm = cmp.find(field);
                            if (elm) {
                                elm.set('v.disabled', true);
                                elm.set('v.value', '');
                            }
                        });
                        ['sfims__CBO_Late_Repayment_Interest_Rate__c', 'sfims__CBO_Late_Repayment_Fixed_Fee__c', 'sfims__CBO_Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                            let elm = cmp.find(field);
                            if (elm) {
                                elm.set('v.value', false);
                                elm.set('v.disabled', true);
                            }
                        });
                    } else {
                        ['sfims__Late_Repayment_Interest_Rate__c', 'sfims__Late_Repayment_Fixed_Fee__c', 'sfims__Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                            that.setFieldDefaultValue(cmp, field);
                        });
                        ['sfims__Minimum_Arrears_Tolerance_Period__c', 'sfims__Maximum_Arrears_Tolerance_Period_days__c'].forEach(function (field) {
                            let elm = cmp.find(field);
                            if (elm) {
                                elm.set('v.disabled', cmp.find('sfims__Late_Repayment_Tolerance_Period__c').get('v.disabled'));
                            }
                        });
                    }
                    break;
                case 'Fixed Fee':
                    if (!sfims__CBO_Late_Repayment_Calculation_Method__c.get('v.value')) {
                        let sfims__Late_Repayment_Interest_Rate__c = cmp.find('sfims__Late_Repayment_Interest_Rate__c');
                        if (sfims__Late_Repayment_Interest_Rate__c) {
                            sfims__Late_Repayment_Interest_Rate__c.set('v.disabled', true);
                            sfims__Late_Repayment_Interest_Rate__c.set('v.value', '');
                        }
                        let sfims__CBO_Late_Repayment_Interest_Rate__c = cmp.find('sfims__CBO_Late_Repayment_Interest_Rate__c');
                        if (sfims__CBO_Late_Repayment_Interest_Rate__c) {
                            sfims__CBO_Late_Repayment_Interest_Rate__c.set('v.value', false);
                            sfims__CBO_Late_Repayment_Interest_Rate__c.set('v.disabled', true);
                        }
                        ['sfims__Late_Repayment_Fixed_Fee__c', 'sfims__Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                            that.setFieldDefaultValue(cmp, field);
                        });
                        ['sfims__Minimum_Arrears_Tolerance_Period__c', 'sfims__Maximum_Arrears_Tolerance_Period_days__c'].forEach(function (field) {
                            let elm = cmp.find(field);
                            if (elm) {
                                elm.set('v.disabled', cmp.find('sfims__Late_Repayment_Tolerance_Period__c').get('v.disabled'));
                            }
                        });
                    } else {
                        ['sfims__Late_Repayment_Interest_Rate__c', 'sfims__Late_Repayment_Fixed_Fee__c', 'sfims__Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                            that.setFieldDefaultValue(cmp, field);
                        });
                        ['sfims__Minimum_Arrears_Tolerance_Period__c', 'sfims__Maximum_Arrears_Tolerance_Period_days__c'].forEach(function (field) {
                            let elm = cmp.find(field);
                            if (elm) {
                                elm.set('v.disabled', cmp.find('sfims__Late_Repayment_Tolerance_Period__c').get('v.disabled'));
                            }
                        });
                    }
                    break;
                default:
                    if (sfims__Late_Repayment_Calculation_Method__c.get('v.value') !== '') { // Overdue
                        if (!sfims__CBO_Late_Repayment_Calculation_Method__c.get('v.value')) {
                            let sfims__Late_Repayment_Fixed_Fee__c = cmp.find('sfims__Late_Repayment_Fixed_Fee__c');
                            if (sfims__Late_Repayment_Fixed_Fee__c) {
                                sfims__Late_Repayment_Fixed_Fee__c.set('v.disabled', true);
                                sfims__Late_Repayment_Fixed_Fee__c.set('v.value', '');
                            }
                            let sfims__CBO_Late_Repayment_Fixed_Fee__c = cmp.find('sfims__CBO_Late_Repayment_Fixed_Fee__c');
                            if (sfims__CBO_Late_Repayment_Fixed_Fee__c) {
                                sfims__CBO_Late_Repayment_Fixed_Fee__c.set('v.value', false);
                                sfims__CBO_Late_Repayment_Fixed_Fee__c.set('v.disabled', true);
                            }
                            ['sfims__Late_Repayment_Interest_Rate__c', 'sfims__Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                                that.setFieldDefaultValue(cmp, field);
                            });
                            ['sfims__Minimum_Arrears_Tolerance_Period__c', 'sfims__Maximum_Arrears_Tolerance_Period_days__c'].forEach(function (field) {
                                let elm = cmp.find(field);
                                if (elm) {
                                    elm.set('v.disabled', cmp.find('sfims__Late_Repayment_Tolerance_Period__c').get('v.disabled'));
                                }
                            });
                        } else {
                            ['sfims__Late_Repayment_Interest_Rate__c', 'sfims__Late_Repayment_Fixed_Fee__c', 'sfims__Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                                that.setFieldDefaultValue(cmp, field);
                            });
                            ['sfims__Minimum_Arrears_Tolerance_Period__c', 'sfims__Maximum_Arrears_Tolerance_Period_days__c'].forEach(function (field) {
                                let elm = cmp.find(field);
                                if (elm) {
                                    elm.set('v.disabled', cmp.find('sfims__Late_Repayment_Tolerance_Period__c').get('v.disabled'));
                                }
                            });
                        }
                    }
                    break;
            }
        }
        this.end();
    },

    setFieldParameters: function (cmp, fields, logic) {
        let that = this;
        if (logic) {
            fields.forEach(function (field) {
                let item = cmp.find(field.name);
                if (item) {
                    that.removeSpecialClass(item);
                    item.set('v.disabled', false);
                } else {
                    cmp.find('message').showErrorMessage('Field "' + field.name + '" was not found.');
                }
            });
        }
        else {
            fields.forEach(function (field) {
                let elm = cmp.find(field.name);
                if (elm) {
                    that.removeSpecialClass(elm);
                    elm.set('v.disabled', true);
                    elm.set(field.setAttr, field.setValue);
                } else {
                    cmp.find('message').showErrorMessage('Field "' + field.name + '" was not found.');
                }
            });
        }
    },

    removeSpecialClass: function (element) {
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