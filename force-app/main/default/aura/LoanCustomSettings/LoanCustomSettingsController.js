({
    doInit: function (cmp, event, helper) {
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        if (helper['isDebugLog'] === undefined) {
            helper.run(helper.showErrMessage, ['The attribute: isDebugLog was not found.']);
            return;
        }
        helper['logSettings'] = {
            style1: {
                value: 'background: blue; color: white;'
            },
            defaultLogStyle: {
                value: 'background: green; color: white;'
            }
        };
        helper.group('doInit');
        helper.log('initialization');
        helper['fields'] = [
            'sfims__Day_Count_Convention__c',
            'sfims__CBO_Day_Count_Convention__c',
            'sfims__Early_Payment_Method__c',
            'sfims__CBO_Early_Payment_Method__c',
            'sfims__Flat_Amount__c',
            'sfims__CBO_Flat_Amount__c',
            'sfims__Late_Repayment_Calculation_Method__c',
            'sfims__CBO_Late_Repayment_Calculation_Method__c',
            'sfims__Late_Repayment_Fixed_Fee__c',
            'sfims__CBO_Late_Repayment_Fixed_Fee__c',
            'sfims__Late_Repayment_Interest_Rate__c',
            'sfims__CBO_Late_Repayment_Interest_Rate__c',
            'sfims__Late_Repayment_Tolerance_Period__c',
            'sfims__CBO_Late_Repayment_Tolerance_Period__c',
            'sfims__Non_Working_Days_Rescheduling__c',
            'sfims__CBO_Non_Working_Days_Rescheduling__c',
            'sfims__Percent_Of_Disbursement_Amount__c',
            'sfims__CBO_Percent_Of_Disbursement_Amount__c',
            'sfims__Repayment_Frequency_Unit__c',
            'sfims__CBO_Repayment_Frequency_Unit__c',
            'sfims__Repayment_Frequency__c',
            'sfims__CBO_Repayment_Frequency__c',
            'sfims__Setup_Fee_Charging_Method__c',
            'sfims__CBO_Setup_Fee_Charging_Method__c',
            'sfims__Setup_Fee__c',
            'sfims__CBO_Setup_Fee__c',
            'sfims__Repayment_Allocation_Type__c',
            'sfims__CBO_Repayment_Allocation_Type__c',
            'sfims__Repayment_Allocation_Order__c',
            'sfims__CBO_Repayment_Allocation_Order__c',
            'sfims__Monitoring_Fee_Percentage__c',
            'sfims__CBO_Monitoring_Fee_Percentage__c',
            'sfims__Late_Repayment_Fees_Charging__c'
        ];
        helper['validation'] = [
            'sfims__Day_Count_Convention__c',
            'sfims__Early_Payment_Method__c',
            'sfims__Flat_Amount__c',
            'sfims__Late_Repayment_Calculation_Method__c',
            'sfims__Late_Repayment_Fixed_Fee__c',
            'sfims__Late_Repayment_Interest_Rate__c',
            'sfims__Late_Repayment_Tolerance_Period__c',
            'sfims__Non_Working_Days_Rescheduling__c',
            'sfims__Percent_Of_Disbursement_Amount__c',
            'sfims__Repayment_Frequency_Unit__c',
            'sfims__Repayment_Frequency__c',
            'sfims__Setup_Fee_Charging_Method__c',
            'sfims__Setup_Fee__c',
            'sfims__Repayment_Allocation_Type__c',
            'sfims__Monitoring_Fee_Percentage__c'
        ];
        helper.run(helper.fetchData, [cmp]);
        helper.groupEnd();
    },

    handleChangeOrder: function (cmp, event, helper) {
        helper.group('handleChangeOrder');
        helper.checkForChanges(cmp);
        helper.groupEnd();
    },

    handleChange: function (cmp, event, helper) {
        helper.group('handleChange');
        let element = event.getSource();
        if (element) {
            let checkAmountAccess = false;
            let elementId = element.getLocalId();
            if (elementId === 'sfims__Late_Repayment_Calculation_Method__c' || elementId === 'sfims__CBO_Late_Repayment_Calculation_Method__c') {
                let sfims__Late_Repayment_Calculation_Method__c = cmp.find('sfims__Late_Repayment_Calculation_Method__c').get('v.value');
                let sfims__CBO_Late_Repayment_Calculation_Method__c = cmp.find('sfims__CBO_Late_Repayment_Calculation_Method__c').get('v.checked');
                helper.log('sfims__Late_Repayment_Calculation_Method__c', sfims__Late_Repayment_Calculation_Method__c);
                helper.log('sfims__CBO_Late_Repayment_Calculation_Method__c', sfims__CBO_Late_Repayment_Calculation_Method__c);
                switch (sfims__Late_Repayment_Calculation_Method__c) {
                    case 'No Penalty':
                        if (!sfims__CBO_Late_Repayment_Calculation_Method__c) {
                            ['sfims__Late_Repayment_Interest_Rate__c', 'sfims__Late_Repayment_Fixed_Fee__c', 'sfims__Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                                let elm = cmp.find(field);
                                if (elm) {
                                    elm.set('v.disabled', true);
                                    elm.set('v.value', 0);
                                    elm.setCustomValidity('');
                                    elm.reportValidity();
                                }
                            });
                            ['sfims__CBO_Late_Repayment_Interest_Rate__c', 'sfims__CBO_Late_Repayment_Fixed_Fee__c', 'sfims__CBO_Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                                let elm = cmp.find(field);
                                if (elm) {
                                    elm.set('v.checked', false);
                                    elm.set('v.disabled', true);
                                }
                            });
                        } else {
                            ['sfims__Late_Repayment_Interest_Rate__c', 'sfims__CBO_Late_Repayment_Interest_Rate__c', 'sfims__Late_Repayment_Fixed_Fee__c', 'sfims__CBO_Late_Repayment_Fixed_Fee__c', 'sfims__Late_Repayment_Tolerance_Period__c', 'sfims__CBO_Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                                let elm = cmp.find(field);
                                if (elm) {
                                    elm.set('v.disabled', false);
                                }
                            });
                        }
                        break;
                    case 'Fixed Fee':
                        if (!sfims__CBO_Late_Repayment_Calculation_Method__c) {
                            let sfims__Late_Repayment_Interest_Rate__c = cmp.find('sfims__Late_Repayment_Interest_Rate__c');
                            if (sfims__Late_Repayment_Interest_Rate__c) {
                                sfims__Late_Repayment_Interest_Rate__c.set('v.disabled', true);
                                sfims__Late_Repayment_Interest_Rate__c.set('v.value', 0);
                                sfims__Late_Repayment_Interest_Rate__c.setCustomValidity('');
                                sfims__Late_Repayment_Interest_Rate__c.reportValidity();
                            }
                            let sfims__CBO_Late_Repayment_Interest_Rate__c = cmp.find('sfims__CBO_Late_Repayment_Interest_Rate__c');
                            if (sfims__CBO_Late_Repayment_Interest_Rate__c) {
                                sfims__CBO_Late_Repayment_Interest_Rate__c.set('v.checked', false);
                                sfims__CBO_Late_Repayment_Interest_Rate__c.set('v.disabled', true);
                            }
                            ['sfims__Late_Repayment_Fixed_Fee__c', 'sfims__CBO_Late_Repayment_Fixed_Fee__c', 'sfims__Late_Repayment_Tolerance_Period__c', 'sfims__CBO_Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                                let elm = cmp.find(field);
                                if (elm) {
                                    elm.set('v.disabled', false);
                                }
                            });
                        } else {
                            ['sfims__Late_Repayment_Interest_Rate__c', 'sfims__CBO_Late_Repayment_Interest_Rate__c', 'sfims__Late_Repayment_Fixed_Fee__c', 'sfims__CBO_Late_Repayment_Fixed_Fee__c', 'sfims__Late_Repayment_Tolerance_Period__c', 'sfims__CBO_Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                                let elm = cmp.find(field);
                                if (elm) {
                                    elm.set('v.disabled', false);
                                }
                            });
                        }
                        break;
                    default:
                        if (sfims__Late_Repayment_Calculation_Method__c !== '') { // Overdue
                            if (!sfims__CBO_Late_Repayment_Calculation_Method__c) {
                                let sfims__Late_Repayment_Fixed_Fee__c = cmp.find('sfims__Late_Repayment_Fixed_Fee__c');
                                if (sfims__Late_Repayment_Fixed_Fee__c) {
                                    sfims__Late_Repayment_Fixed_Fee__c.set('v.disabled', true);
                                    sfims__Late_Repayment_Fixed_Fee__c.set('v.value', 0);
                                    sfims__Late_Repayment_Fixed_Fee__c.setCustomValidity('');
                                    sfims__Late_Repayment_Fixed_Fee__c.reportValidity();
                                }
                                let sfims__CBO_Late_Repayment_Fixed_Fee__c = cmp.find('sfims__CBO_Late_Repayment_Fixed_Fee__c');
                                if (sfims__CBO_Late_Repayment_Fixed_Fee__c) {
                                    sfims__CBO_Late_Repayment_Fixed_Fee__c.set('v.checked', false);
                                    sfims__CBO_Late_Repayment_Fixed_Fee__c.set('v.disabled', true);
                                }
                                ['sfims__Late_Repayment_Interest_Rate__c', 'sfims__CBO_Late_Repayment_Interest_Rate__c', 'sfims__Late_Repayment_Tolerance_Period__c', 'sfims__CBO_Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                                    let elm = cmp.find(field);
                                    if (elm) {
                                        elm.set('v.disabled', false);
                                    }
                                });
                            } else {
                                ['sfims__Late_Repayment_Interest_Rate__c', 'sfims__CBO_Late_Repayment_Interest_Rate__c', 'sfims__Late_Repayment_Fixed_Fee__c', 'sfims__CBO_Late_Repayment_Fixed_Fee__c', 'sfims__Late_Repayment_Tolerance_Period__c', 'sfims__CBO_Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                                    let elm = cmp.find(field);
                                    if (elm) {
                                        elm.set('v.disabled', false);
                                    }
                                });
                            }
                        }
                        break;
                }
            }
            if (elementId === 'sfims__Setup_Fee_Charging_Method__c' || elementId === 'sfims__CBO_Setup_Fee_Charging_Method__c') {
                let sfims__Setup_Fee_Charging_Method__c = cmp.find('sfims__Setup_Fee_Charging_Method__c').get('v.value');
                let sfims__CBO_Setup_Fee_Charging_Method__c = cmp.find('sfims__CBO_Setup_Fee_Charging_Method__c').get('v.checked');
                helper.log('sfims__Setup_Fee_Charging_Method__c', sfims__Setup_Fee_Charging_Method__c);
                helper.log('sfims__CBO_Setup_Fee_Charging_Method__c', sfims__CBO_Setup_Fee_Charging_Method__c);
                if (sfims__Setup_Fee_Charging_Method__c === 'No Setup Fee' && !sfims__CBO_Setup_Fee_Charging_Method__c) {
                    let sfims__Setup_Fee__c = cmp.find('sfims__Setup_Fee__c');
                    if (sfims__Setup_Fee__c) {
                        sfims__Setup_Fee__c.set('v.disabled', true);
                        sfims__Setup_Fee__c.set('v.value', '');
                        sfims__Setup_Fee__c.setCustomValidity('');
                        sfims__Setup_Fee__c.reportValidity();
                    }
                    ['sfims__Percent_Of_Disbursement_Amount__c', 'sfims__Flat_Amount__c'].forEach(function (field) {
                        let elm = cmp.find(field);
                        if (elm) {
                            elm.set('v.disabled', true);
                            elm.set('v.value', 0);
                            elm.setCustomValidity('');
                            elm.reportValidity();
                        }
                    });
                    ['sfims__CBO_Setup_Fee__c', 'sfims__CBO_Percent_Of_Disbursement_Amount__c', 'sfims__CBO_Flat_Amount__c'].forEach(function (field) {
                        let elm = cmp.find(field);
                        if (elm) {
                            elm.set('v.checked', false);
                            elm.set('v.disabled', true);
                        }
                    });
                } else {
                    ['sfims__Setup_Fee__c', 'sfims__CBO_Setup_Fee__c', 'sfims__Percent_Of_Disbursement_Amount__c', 'sfims__CBO_Percent_Of_Disbursement_Amount__c', 'sfims__Flat_Amount__c', 'sfims__CBO_Flat_Amount__c'].forEach(function (field) {
                        let elm = cmp.find(field);
                        if (elm) {
                            elm.set('v.disabled', false);
                            checkAmountAccess = true;
                        }
                    });
                }
            }
            if (elementId === 'sfims__Setup_Fee__c' || elementId === 'sfims__CBO_Setup_Fee__c' || checkAmountAccess) {
                let sfims__Setup_Fee__c = cmp.find('sfims__Setup_Fee__c').get('v.value');
                let sfims__CBO_Setup_Fee__c = cmp.find('sfims__CBO_Setup_Fee__c').get('v.checked');
                helper.log('sfims__Setup_Fee__c', sfims__Setup_Fee__c);
                helper.log('sfims__CBO_Setup_Fee__c', sfims__CBO_Setup_Fee__c);
                if (sfims__Setup_Fee__c !== '' && !sfims__CBO_Setup_Fee__c) {
                    if (sfims__Setup_Fee__c === 'Flat Amount') {
                        let sfims__Percent_Of_Disbursement_Amount__c = cmp.find('sfims__Percent_Of_Disbursement_Amount__c');
                        if (sfims__Percent_Of_Disbursement_Amount__c) {
                            sfims__Percent_Of_Disbursement_Amount__c.set('v.disabled', true);
                            sfims__Percent_Of_Disbursement_Amount__c.set('v.value', 0);
                            sfims__Percent_Of_Disbursement_Amount__c.setCustomValidity('');
                            sfims__Percent_Of_Disbursement_Amount__c.reportValidity();
                        }
                        let sfims__CBO_Percent_Of_Disbursement_Amount__c = cmp.find('sfims__CBO_Percent_Of_Disbursement_Amount__c');
                        if (sfims__CBO_Percent_Of_Disbursement_Amount__c) {
                            sfims__CBO_Percent_Of_Disbursement_Amount__c.set('v.disabled', true);
                            sfims__CBO_Percent_Of_Disbursement_Amount__c.set('v.checked', false);
                        }
                        let sfims__Flat_Amount__c = cmp.find('sfims__Flat_Amount__c');
                        if (sfims__Flat_Amount__c) {
                            sfims__Flat_Amount__c.set('v.disabled', false);
                        }
                        let sfims__CBO_Flat_Amount__c = cmp.find('sfims__CBO_Flat_Amount__c');
                        if (sfims__CBO_Flat_Amount__c) {
                            sfims__Flat_Amount__c.set('v.value', 0);
                            sfims__CBO_Flat_Amount__c.set('v.disabled', false);
                        }
                    } else {
                        if (sfims__Setup_Fee__c === '% of Disbursement Amount') {
                            let sfims__Flat_Amount__c = cmp.find('sfims__Flat_Amount__c');
                            if (sfims__Flat_Amount__c) {
                                sfims__Flat_Amount__c.set('v.disabled', true);
                                sfims__Flat_Amount__c.set('v.value', 0);
                                sfims__Flat_Amount__c.setCustomValidity('');
                                sfims__Flat_Amount__c.reportValidity();
                            }
                            let sfims__CBO_Flat_Amount__c = cmp.find('sfims__CBO_Flat_Amount__c');
                            if (sfims__CBO_Flat_Amount__c) {
                                sfims__CBO_Flat_Amount__c.set('v.disabled', true);
                                sfims__CBO_Flat_Amount__c.set('v.checked', false);
                            }
                            let sfims__Percent_Of_Disbursement_Amount__c = cmp.find('sfims__Percent_Of_Disbursement_Amount__c');
                            if (sfims__Percent_Of_Disbursement_Amount__c) {
                                sfims__Percent_Of_Disbursement_Amount__c.set('v.disabled', false);
                            }
                            let sfims__CBO_Percent_Of_Disbursement_Amount__c = cmp.find('sfims__CBO_Percent_Of_Disbursement_Amount__c');
                            if (sfims__CBO_Percent_Of_Disbursement_Amount__c) {
                                sfims__Percent_Of_Disbursement_Amount__c.set('v.value', 0);
                                sfims__CBO_Percent_Of_Disbursement_Amount__c.set('v.disabled', false);
                            }
                        }
                    }
                } else {
                    ['sfims__Flat_Amount__c', 'sfims__Percent_Of_Disbursement_Amount__c'].forEach(function (field) {
                        let elm = cmp.find(field);
                        if (elm) {
                            elm.set('v.disabled', false);
                        }
                    });
                    ['sfims__CBO_Flat_Amount__c', 'sfims__CBO_Percent_Of_Disbursement_Amount__c'].forEach(function (field) {
                        let elm = cmp.find(field);
                        if (elm) {
                            elm.set('v.disabled', false);
                        }
                    });
                }
            }
        }
        helper.run(helper.resetValidation, [cmp]);
        helper['validation'].forEach(function (field) {
            helper.run(helper.emptyValidation, [cmp, field]);
            helper.run(helper.negativeValidation, [cmp, field]);
        });
        helper.checkForChanges(cmp);
        helper.groupEnd();
    },

    handleCancel: function (cmp, event, helper) {
        helper.group('handleCancel');
        helper.run(helper.setDefaultValues, [cmp]);
        cmp.set('v.isEdit', false);
        helper.groupEnd();
    },

    handleSave: function (cmp, event, helper) {
        helper.group('handleSave');
        let spinner = helper.run(helper.showSpinner, [cmp, 'v.isLoading']);
        helper.run(helper.resetValidation, [cmp]);
        if (helper['fields']) {
            let fieldValues = {};
            helper['fields'].forEach(function (field) {
                let element = cmp.find(field);
                if (element) {
                    if (element.get('v.type') !== 'toggle') {
                        if (helper['defaultValues'].hasOwnProperty(field)) {
                            fieldValues[field] = element.get('v.value').toString();
                        }
                    } else {
                        if (helper['defaultValues'].hasOwnProperty(field)) {
                            fieldValues[field] = element.get('v.checked').toString();
                        }
                    }
                }
            });
            helper.log('save data', fieldValues);
            if (fieldValues) {
                let isValid = true;
                let fields = helper['validation'];
                let msg = '';
                fields.forEach(function (field) {
                    if (!helper.run(helper.negativeValidation, [cmp, field]) || !helper.run(helper.emptyValidation, [cmp, field])) {
                        isValid = false;
                        msg += '- ' + cmp.find(field).get('v.label') + '\n';
                    }
                });
                if (isValid) {
                    helper.run(helper.saveCustomSettings, [cmp, fieldValues]);
                    cmp.set('v.isEdit', false);
                } else {
                    helper.run(helper.showErrMessage, ['Check the fields' + ': \n' + msg]);
                }
                helper.run(helper.hideSpinner, [cmp, 'v.isLoading', spinner]);
            } else {
                helper.run(helper.showErrMessage, ['Runtime error']);
            }
        } else {
            helper.run(helper.showErrMessage, ['Runtime error']);
        }
        helper.groupEnd();
    },

    handleSectionClick: function (cmp, event, helper) {
        helper.group('handleSectionClick');
        if (event.currentTarget.id) {
            cmp.set('v.sections.' + event.currentTarget.id, !cmp.get('v.sections')[event.currentTarget.id]);
        }
        helper.groupEnd();
    }
});