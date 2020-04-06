({
    fetchData: function (cmp) {
        let that = this;
        let spinner = that.run(that.showSpinner, [cmp, 'v.isLoading']);
        let action = cmp.get('c.apexGetObjectFields');
        action.setParams({
            objectName: 'sfims__Loan_Product__c'
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.group('fetchData-SUCCESS');
                let map = response.getReturnValue();
                that['objectFields'] = JSON.parse(map['getObjectFields']);
                that.log('sfims__Loan_Product__c fields', that['objectFields']);
                // that['profile'] = JSON.parse(map['getProfileInfo']);
                // that.log('profile', that['profile']);
                that['customSettings'] = JSON.parse(map['getCustomSettings']);
                that.log('custom settings', that['customSettings']);
                
                // if (that['customSettings'] && that['objectFields'] && that['profile']) {
                if (that['customSettings'] && that['objectFields'] && map.hasOwnProperty('hasPermission')) {    
                    that['hasPermission'] = (map['hasPermission'] === 'true');
                    if (!that['hasPermission']) {
                        that.run(that.showMessage, [null, $A.get("$Label.sfims.error_message_67"), 'info', 6000]);
                        cmp.set('v.isDisabledRepaymentAllocationOrder', true);
                    }
                    that.run(that.setDefaultValues, [cmp]);
                } else {
                    that.run(that.showErrMessage, ['Runtime error']);
                }
                that.run(that.hideSpinner, [cmp, 'v.isLoading', spinner]);
                that.groupEnd();
            }
            else {
                that.group('fetchData-ERROR');
                let errors = response.getError();
                that.log('errors', errors);
                that.run(that.showErrMessage, [that.run(that.getErrMessage, [errors])]);
                that.run(that.hideSpinner, [cmp, 'v.isLoading', spinner]);
                that.groupEnd();
            }
        });
        $A.enqueueAction(action);
    },

    checkForChanges: function (cmp) {
        this.group('checkForChanges');
        let that = this;
        if (this['defaultValues']) {
            let flag = false;
            if (this['fields']) {
                this['fields'].forEach(function (field) {
                    let element = cmp.find(field);
                    if (element) {
                        if (element.get('v.type') !== 'toggle') {
                            if (that['defaultValues'].hasOwnProperty(field)) {
                                if (element.get('v.value').toString() !== that['defaultValues'][field].toString()) {
                                    flag = true;
                                }
                            }
                        } else {
                            /*
                            if (!helper['defaultValues'].hasOwnProperty(field)) {
                                alert(field);
                            }
                            console.log(helper['defaultValues']);
                            */
                            if (that['defaultValues'].hasOwnProperty(field)) {
                                if (element.get('v.checked').toString() !== that['defaultValues'][field].toString()) {
                                    flag = true;
                                }
                            }
                        }
                    }
                });
                cmp.set('v.isEdit', flag);
            } else {
                this.run(this.showErrMessage, ['Runtime error']);
            }
        }
        this.groupEnd();
    },

    resetValidation: function (cmp) {
        let fields = this['validation'];
        fields.forEach(function (field) {
            let element = cmp.find(field);
            if (element) {
                element.setCustomValidity('');
                element.reportValidity();
            }
        });
    },

    negativeValidation: function (cmp, name) {
        // this.log('negativeValidation' + ', element: ' + name);
        let flag = true;
        let element = cmp.find(name);
        if (element) {
            if (Number(element.get('v.value')) < 0 && !element.get('v.disabled')) {
                element.setCustomValidity('Negative values not allowed');
                element.reportValidity();
                flag = false;
            }
        }
        return flag;
    },

    emptyValidation: function (cmp, name) {
        this.log('emptyValidation' + ', element: ' + name);
        let element = cmp.find(name);
        let flag = true;
        if (element) {
            if ($A.util.isEmpty(element.get('v.value'))) {
                let CBO = name.replace('sfims__', 'sfims__CBO_');
                if (!cmp.find(CBO).get('v.checked') && !element.get('v.disabled')) {
                    element.setCustomValidity('Complete this field or check Can be overridden');
                    element.reportValidity();
                    flag = false;
                }
            }
        }
        return flag;
    },

    saveCustomSettings: function (cmp, values) {
        let that = this;
        that.log('values', values);
        let spinner = that.run(that.showSpinner, [cmp, 'v.isLoading']);
        let action = cmp.get('c.apexSaveCustomSettings');
        action.setParams({
            settingValues: values
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.group('saveCustomSettings-SUCCESS');
                if (response.getReturnValue()) {
                    that.run(that.showSuccessMessage, ['Loan custom settings were saved.']);
                } else {
                    that.run(that.showErrMessage, ['Loan custom settings were not saved.']);
                }
                that.run(that.fetchData, [cmp]);
                that.run(that.hideSpinner, [cmp, 'v.isLoading', spinner]);
                that.groupEnd();
            }
            else {
                that.group('saveCustomSettings-ERROR');
                let errors = response.getError();
                that.log('errors', errors);
                that.run(that.showErrMessage, [that.run(that.getErrMessage, [errors])]);
                that.run(that.hideSpinner, [cmp, 'v.isLoading', spinner]);
                that.groupEnd();
            }
        });
        $A.enqueueAction(action);
    },

    setDefaultValues: function (cmp) {
        this.run(this.resetValidation, [cmp]);
        let that = this;
        if (this['objectFields']) {
            if (that['customSettings'].hasOwnProperty('sfims__Setup_Fee_Charging_Method__c') && that['customSettings'].hasOwnProperty('sfims__CBO_Setup_Fee_Charging_Method__c')) {
                that.log('sfims__Setup_Fee_Charging_Method__c', that['customSettings']['sfims__Setup_Fee_Charging_Method__c']);
                that.log('sfims__CBO_Setup_Fee_Charging_Method__c', that['customSettings']['sfims__CBO_Setup_Fee_Charging_Method__c']);
                if (that['customSettings']['sfims__Setup_Fee_Charging_Method__c'] === 'No Setup Fee' && !that['customSettings']['sfims__CBO_Setup_Fee_Charging_Method__c']) {
                    ['sfims__CBO_Setup_Fee__c', 'sfims__CBO_Percent_Of_Disbursement_Amount__c', 'sfims__CBO_Flat_Amount__c', 'sfims__Setup_Fee__c', 'sfims__Percent_Of_Disbursement_Amount__c', 'sfims__Flat_Amount__c'].forEach(function (field) {
                        let elm = cmp.find(field);
                        if (elm) {
                            elm.set('v.disabled', true);
                        }
                    });
                } else {
                    if (that['customSettings'].hasOwnProperty('sfims__Setup_Fee__c') && that['customSettings'].hasOwnProperty('sfims__CBO_Setup_Fee__c')) {
                        that.log('sfims__Setup_Fee__c', that['customSettings']['sfims__Setup_Fee__c']);
                        that.log('sfims__CBO_Setup_Fee__c', that['customSettings']['sfims__CBO_Setup_Fee__c']);
                        if (that['customSettings']['sfims__Setup_Fee__c'] !== '' && !that['customSettings']['sfims__CBO_Setup_Fee__c']) {
                            if (that['customSettings']['sfims__Setup_Fee__c'] === 'Flat Amount') {
                                ['sfims__Percent_Of_Disbursement_Amount__c', 'sfims__CBO_Percent_Of_Disbursement_Amount__c'].forEach(function (field) {
                                    let elm = cmp.find(field);
                                    if (elm) {
                                        elm.set('v.disabled', true);
                                    }
                                });
                                ['sfims__Flat_Amount__c', 'sfims__CBO_Flat_Amount__c'].forEach(function (field) {
                                    let elm = cmp.find(field);
                                    if (elm) {
                                        elm.set('v.disabled', false);
                                    }
                                });
                            } else {
                                if (that['customSettings']['sfims__Setup_Fee__c'] === '% of Disbursement Amount') {
                                    ['sfims__Flat_Amount__c', 'sfims__CBO_Flat_Amount__c'].forEach(function (field) {
                                        let elm = cmp.find(field);
                                        if (elm) {
                                            elm.set('v.disabled', true);
                                        }
                                    });
                                    ['sfims__Percent_Of_Disbursement_Amount__c', 'sfims__CBO_Percent_Of_Disbursement_Amount__c'].forEach(function (field) {
                                        let elm = cmp.find(field);
                                        if (elm) {
                                            elm.set('v.disabled', false);
                                        }
                                    });
                                }
                            }
                        }
                    }
                }
            }
            if (that['customSettings'].hasOwnProperty('sfims__Late_Repayment_Calculation_Method__c') && that['customSettings'].hasOwnProperty('sfims__CBO_Late_Repayment_Calculation_Method__c')) {
                that.log('sfims__Late_Repayment_Calculation_Method__c', that['customSettings']['sfims__Late_Repayment_Calculation_Method__c']);
                that.log('sfims__CBO_Late_Repayment_Calculation_Method__c', that['customSettings']['sfims__CBO_Late_Repayment_Calculation_Method__c']);
                if (that['customSettings']['sfims__Late_Repayment_Calculation_Method__c'] === 'No Penalty' && !that['customSettings']['sfims__CBO_Late_Repayment_Calculation_Method__c']) {
                    ['sfims__Late_Repayment_Interest_Rate__c', 'sfims__Late_Repayment_Fixed_Fee__c', 'sfims__Late_Repayment_Tolerance_Period__c', 'sfims__CBO_Late_Repayment_Interest_Rate__c', 'sfims__CBO_Late_Repayment_Fixed_Fee__c', 'sfims__CBO_Late_Repayment_Tolerance_Period__c'].forEach(function (field) {
                        let elm = cmp.find(field);
                        if (elm) {
                            elm.set('v.disabled', true);
                        }
                    });
                }
            }
            let map = this['objectFields'];
            // list of fields that do not fill in loan
            map['sfims__CBO_Repayment_Allocation_Type__c'] = {type: 'Boolean'};
            map['sfims__CBO_Repayment_Allocation_Order__c'] = {type: 'Boolean'};
            map['sfims__CBO_Monitoring_Fee_Percentage__c'] = {type: 'Boolean'};
            let options = {};
            this['defaultValues'] = {};
            this['fields'].forEach(function (field) {
                if (map.hasOwnProperty(field) || field === 'sfims__Late_Repayment_Tolerance_Period__c' || field === 'sfims__Monitoring_Fee_Percentage__c' || ignore.indexOf(field) !== -1) {
                    if (map.hasOwnProperty(field) && map[field]['type'] === 'Picklist') {
                        options[field] = [{
                            label: '--None--',
                            value: ''
                        }].concat(map[field]['options']);
                    }
                    let element = cmp.find(field);
                    if (element) {
                        let defValue = '';
                        if (that['customSettings']) {
                            if (that['customSettings'].hasOwnProperty(field)) {
                                defValue = that['customSettings'][field];
                            }
                        }
                        if (map.hasOwnProperty(field) && map[field]['type'] === 'Boolean') {
                            element.set('v.checked', defValue);
                        } else {
                            element.set('v.value', defValue);
                        }
                        // if (that['profile']['Name'] !== 'System Administrator') {
                        //     element.set('v.disabled', true);
                        // }
                        if (!that['hasPermission']) {
                            element.set('v.disabled', true);
                        }
                        that['defaultValues'][field] = defValue;
                        that.log('set ' + field + ' = ' + defValue);
                    } else {
                        that.run(that.showErrMessage, ['Field \'' + field + '\' has not been found in the component markup.']);
                    }
                } else {
                    that.run(that.showErrMessage, ['Field \'' + field + '\' has not been found on the object.']);
                }
            });
            that.log('defaultValues', that['defaultValues']);
            if (options) {
                cmp.set('v.options', options);
            }
            that.log('picklist options', options);
        } else {
            that.run(that.showErrMessage, ['Runtime error']);
        }
    },

    run: function (func, arg) {
        let response;
        this.group(func.name);
        try {
            response = func.apply(this, arg);
        } catch (e) {
            console.log(e);
            this.showErrMessage('An error occurred during the execution of JavaScript.');
            if (e instanceof TypeError) {
            } else if (e instanceof RangeError) {
            } else if (e instanceof EvalError) {
            } else {
            }
        }
        this.groupEnd();
        return response;
    },

    group: function (name) {
        if (this['isDebugLog']) {
            console.group('%s, time: %f', name, this.timeStamp());
        }
    },

    groupEnd: function () {
        if (this['isDebugLog']) {
            console.groupEnd();
        }
    },

    log: function (label, values, style) {
        if (this['isDebugLog']) {
            style = style || this['logSettings']['defaultLogStyle']['value'];
            if (!values) {
                values = label;
                label = '';
            }
            if (Array.isArray(values)) {
                if (label) {
                    console.log('%c' + label, style);
                }
                console.log(values);
            } else if (typeof values === 'object') {
                if (label) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else {
                if (label) {
                    console.log('%c' + label + ' - ' + values, style);
                } else {
                    console.log(values);
                }
            }
        }
    },

    showSpinner: function (cmp, attribute, delay, timeStamp, isOneSpinner) {
        timeStamp = timeStamp || new Date().getTime();
        this.log('attribute: ' + attribute + ', timeStamp: ' + timeStamp);
        delay = delay || 20000; // time for local spinner
        let delayOneSpinner = 20000; // time for one spinner
        isOneSpinner = isOneSpinner || true;
        let qSpinners = cmp.get('v.qSpinners');
        if (!qSpinners.hasOwnProperty(attribute)) {
            qSpinners[attribute] = [];
        }
        if (qSpinners[attribute].indexOf(timeStamp) === -1) {
            qSpinners[attribute].push(timeStamp);
            if (isOneSpinner) {
                let cmpSpinner = cmp.get('v.cmpSpinner');
                if (!cmpSpinner.hasOwnProperty(attribute)) {
                    cmpSpinner[attribute] = timeStamp;
                    cmp.set('v.cmpSpinner', cmpSpinner);
                    cmp.set(attribute, true);
                    let that = this;
                    window.setTimeout(
                        $A.getCallback(function () {
                            that.log('getCallback hideCmpSpinner' + ', attribute: ' + attribute + ', timeStamp: ' + timeStamp);
                            if (cmpSpinner.hasOwnProperty(attribute)) {
                                if (cmpSpinner[attribute] === timeStamp) {
                                    delete cmpSpinner[attribute];
                                    cmp.set(attribute, false);
                                    cmp.set('v.qSpinners', {});
                                }
                            }
                        }), delayOneSpinner);
                }
            } else {
                let that = this;
                window.setTimeout(
                    $A.getCallback(function () {
                        that.run(that.hideSpinner, [cmp, attribute, timeStamp]);
                    }), delay);
                cmp.set(attribute, true);
                cmp.set('v.qSpinners', qSpinners);
            }
        }
        return timeStamp;
    },

    hideSpinner: function (cmp, attribute, timeStamp) {
        this.log('attribute: ' + attribute + ', timeStamp: ' + timeStamp);
        let qSpinners = cmp.get('v.qSpinners');
        if (qSpinners.hasOwnProperty(attribute)) {
            let index = qSpinners[attribute].indexOf(timeStamp);
            if (index !== -1) {
                if (qSpinners[attribute].length === 1) {
                    let cmpSpinner = cmp.get('v.cmpSpinner');
                    if (cmpSpinner.hasOwnProperty(attribute)) {
                        delete cmpSpinner[attribute];
                    }
                    delete qSpinners[attribute];
                    cmp.set(attribute, false);
                } else {
                    qSpinners[attribute].splice(index, 1);
                }
                cmp.set('v.qSpinners', qSpinners);
            }
        }
    },

    getErrMessage: function (errors) {
        let message = 'Unknown error';
        if (errors && Array.isArray(errors) && errors.length > 0) {
            let msgErrors = '';
            errors.forEach(function (err) {
                if (err.hasOwnProperty('message')) {
                    msgErrors += err.message + '\n';
                }
                if (err.hasOwnProperty('pageErrors')) {
                    if (Array.isArray(err.pageErrors) && err.pageErrors.length > 0) {
                        err.pageErrors.forEach(function (pageErrors) {
                            if (pageErrors.hasOwnProperty('message')) {
                                msgErrors += pageErrors.message + '\n';
                            }
                        });
                    }
                }
                if (err.hasOwnProperty('fieldErrors')) {
                    if (Array.isArray(err.fieldErrors) && err.fieldErrors.length > 0) {
                        err.fieldErrors.forEach(function (fieldErrors) {
                            if (fieldErrors.hasOwnProperty('message')) {
                                msgErrors += fieldErrors.message + '\n';
                            }
                        });
                    }
                }
            });
            if (msgErrors) {
                message = msgErrors;
            }
        }
        return message;
    },

    cancel: function (cmp, isRedirect, sObject) {
        isRedirect = isRedirect || false;
        if (isRedirect) {
            if (!cmp.get('v.recordId')) {
                this.run(this.navigateToObjectHome, [cmp, sObject]);
            } else {
                this.run(this.navigateToSObject, [cmp, cmp.get('v.recordId')]);
            }
        } else {
            if (cmp.get('v.isRunning')) {
                this.run(this.closeModal, [cmp, 'v.isRunning']);
            } else {
                if (cmp.find('overlayLib')) {
                    this.run(this.closeOverlayLib, [cmp]);
                } else {
                    this.run(this.closeQuickAction, [cmp]);
                }
            }
        }
    },

    closeQuickAction: function () {
        $A.get('e.force:closeQuickAction').fire();
    },

    closeOverlayLib: function (cmp) {
        let overlayLib = cmp.find('overlayLib');
        if (overlayLib) {
            overlayLib.notifyClose();
        }
    },

    forceRefreshView: function (cmp) {
        $A.get('e.force:refreshView').fire();
    },

    navigateToSObject: function (cmp, recordId) {
        let record = recordId || cmp.get('v.recordId');
        let navEvt = $A.get('e.force:navigateToSObject');
        navEvt.setParams({
            'recordId': record
        });
        navEvt.fire();
    },

    navigateToHome: function (cmp) {
        let homeEvt = $A.get('e.force:navigateHome');
        homeEvt.fire();
    },

    navigateToObjectHome: function (cmp, sObject) {
        let homeEvent = $A.get('e.force:navigateToObjectHome');
        homeEvent.setParams({
            'scope': sObject
        });
        homeEvent.fire();
    },

    elementValidationStandard: function (cmp, element, label) {
        this.log('elementValidationStandard' + ', element: ' + element + ', label: ' + label);
        let item = cmp.find(element);
        if (item) {
            item.showHelpMessageIfInvalid();
            let isValid = item.get('v.validity').valid;
            if (!isValid) {
                this['errFields'].push(label);
            }
            return isValid;
        }
        return false;
    },

    elementValidation: function (cmp, element, label) {
        this.log('elementValidation' + ', element: ' + element + ', label: ' + label);
        let response = true;
        let item = cmp.find(element);
        if (!$A.util.isEmpty(item)) {
            if ($A.util.isEmpty(item.get('v.value'))) {
                $A.util.addClass(item, 'error');
                $A.util.addClass(item, 'slds-has-error');
                if (label) {
                    this['errFields'].push(label);
                }
                response = false;
            } else {
                $A.util.removeClass(item, 'error');
                $A.util.removeClass(item, 'slds-has-error');
            }
        } else {
            this.run(this.showErrMessage, ['The element "' + element + '" was not found.']);
        }
        return response;
    },

    formValidation: function (cmp, fields) {
        let response = true;
        let that = this;
        fields.forEach(function (field) {
            if (!that.run(that.elementValidation, [cmp, field.name, field.label])) {
                response = false;
            }
        });
        return response;
    },

    trim: function (str) {
        return str.replace(/^\s+|\s+$/g, '');
    },

    startTimer: function (name) {
        if (this['isDebugLog']) {
            console.time(name);
        }
    },

    stopTimer: function (name) {
        if (this['isDebugLog']) {
            console.timeEnd(name);
        }
    },

    showModal: function (cmp, attribute) {
        cmp.set(attribute, true);
    },

    closeModal: function (cmp, attribute) {
        cmp.set(attribute, false);
    },

    timeStamp: function () {
        return performance.now() / 1000;
    },

    showErrMessage: function (message, title) {
        this.run(this.showMessage, [title, message, 'error', 20000]);
    },

    showSuccessMessage: function (message, title) {
        this.run(this.showMessage, [title, message, 'success']);
    },

    showWarningMessage: function (message, title) {
        this.run(this.showMessage, [title, message, 'warning']);
    },

    showMessage: function (title, message, type, duration, mode) {
        duration = duration || (type === 'error') ? 6000 : 3000;
        mode = mode || 'disptable';
        switch (type) {
            case 'error':
                console.error(message);
                break;
            case 'warning':
                console.warn(message);
                break;
            default:
                console.log(type + ' ' + message);
        }
        let toast = $A.get('e.force:showToast');
        if (toast !== undefined) {
            toast.setParams({
                'title': title,
                'message': message,
                'type': type,
                'mode': mode,
                'duration': duration
            });
            toast.fire();
        }
        else {
            alert(message);
        }
    }
});