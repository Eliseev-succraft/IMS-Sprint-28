({
    fetchData: function (cmp) {
        this.startMethod(cmp, 'fetchData');
        let that = this;
        let requiredFields = [];
        let defaultFields = cmp.get('v.defaultFields');
        defaultFields.forEach(function (field) {
            requiredFields.push(field.value);
        });
        let spinner = this.showSpinner(cmp, 'v.isLoading');
        let action = cmp.get('c.getSettingsData');
        action.setCallback(this, function (resp) {
            let state = resp.getState();
            if (state === 'SUCCESS') {
                that.startMethod(cmp, 'fetchData-SUCCESS');
                let response = JSON.parse(resp.getReturnValue());
                that.log('settings data', response);
                if (!response.hasOwnProperty('allRecordTypes')) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner(cmp, 'v.isLoading', spinner);
                    return;
                }
                if (!response.hasOwnProperty('savedSettings')) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner(cmp, 'v.isLoading', spinner);
                    return;
                }
                let recordTypes = [{
                    label: 'All Libraries',
                    value: '0',
                    active: false
                }];
                recordTypes = recordTypes.concat(response.allRecordTypes);
                that['recordTypes'] = {};
                recordTypes.forEach(function (recordType) {
                    that['recordTypes'][recordType.value] = recordType.label;
                });
                let currentAvailableFields = [];
                that['objRecordType'].availableFields = response.availableFields;
                that['objRecordType'].availableFields.forEach(function (field) {
                    currentAvailableFields.push(field.value);
                });
                cmp.set('v.requiredFields', requiredFields);
                cmp.set('v.options', that['objRecordType'].availableFields);
                let activeCount = 0;
                recordTypes.forEach(function (recordType) {
                    if (recordType['value'] !== '0') {
                        if (response.savedSettings[recordType.value] != null) {
                            let selectedFields = [];
                            response.savedSettings[recordType.value].fields.forEach(function (field) {
                                if (currentAvailableFields.indexOf(field) !== -1) {
                                    selectedFields.push(field);
                                }
                            });
                            that['objRecordType'].recordTypes[recordType.value] = {
                                'selectedFields': selectedFields,
                                'active': response.savedSettings[recordType.value].active
                            };
                            recordType['active'] = response.savedSettings[recordType.value].active;
                            recordType['disabled'] = false;
                        } else {
                            that['objRecordType'].recordTypes[recordType.value] = {
                                'selectedFields': requiredFields,
                                'active': true
                            };
                            recordType['active'] = true;
                            recordType['disabled'] = false;
                        }
                        if (recordType['active']) {
                            activeCount++;
                        }
                    } else {
                        that['objRecordType'].recordTypes[recordType.value] = {};
                    }
                });
                if (activeCount === recordTypes.length - 1) {
                    recordTypes.forEach(function (recordType) {
                        if (recordType.value !== '0') {
                            recordType.disabled = true;
                        }
                    });
                    recordTypes[0].active = true;
                }
                cmp.set('v.allRecordTypes', recordTypes);
                that.log(cmp.get('v.allRecordTypes'));
                that.log('config', that['objRecordType']);
                cmp.set('v.selectedRecordType', recordTypes[1].value);
                that.refreshViewConfigure(cmp);
                that.stopMethod(cmp);
            }
            else {
                let errors = resp.getError();
                that.log('errors', errors);
                that.showErrMessage(that.getErrMessage(errors));
            }
            that.hideSpinner(cmp, 'v.isLoading', spinner);
        });
        $A.enqueueAction(action);
        this.stopMethod(cmp);
    },

    refreshViewConfigure: function (cmp) {
        this.startMethod(cmp, 'refreshViewConfigure');
        let selectedRecordType = cmp.get('v.selectedRecordType');
        cmp.set('v.values', this['objRecordType'].recordTypes[selectedRecordType].selectedFields);
        cmp.set('v.selectedLibraryName', this['recordTypes'][selectedRecordType]);
        this.stopMethod(cmp);
    },

    saveConfigures: function (cmp) {
        this.startMethod(cmp, 'saveConfigures');
        let flag = false;
        for (let key in this['objRecordType'].recordTypes) {
            if (this['objRecordType'].recordTypes.hasOwnProperty(key)) {
                if (this['objRecordType'].recordTypes[key].active) {
                    flag = true;
                    break;
                }
            }
        }
        if (!flag) {
            this.showErrMessage('Please select at least one active Record Type.');
            return;
        }
        let that = this;
        let spinner = this.showSpinner(cmp, 'v.isLoading');
        let action = cmp.get('c.saveAllConfigures');
        action.setParams({
            objRecordType: JSON.stringify(this['objRecordType'].recordTypes)
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.startMethod(cmp, 'fetchData-SUCCESS');
                if (response.getReturnValue()) {
                    that.showSuccessMessage('Columns settings were saved.');
                    cmp.set('v.isRefresh', true);
                } else {
                    that.showErrMessage('Columns settings were not saved.');
                }
                this.closeModal(cmp, 'v.isShowConfigureColumns');
                that.stopMethod(cmp);
            }
            else {
                let errors = response.getError();
                that.log('errors', errors);
                that.showErrMessage(that.getErrMessage(errors));
            }
            that.hideSpinner(cmp, 'v.isLoading', spinner);
        });
        $A.enqueueAction(action);
        this.stopMethod(cmp);
    },

    saveViewConfigure: function (cmp, event) {
        this.startMethod(cmp, 'saveViewConfigure');
        let selectedRecordType = cmp.get('v.selectedRecordType');
        this['objRecordType'].recordTypes[selectedRecordType].selectedFields = event.getParam('value');
        this.stopMethod(cmp);
    },

    startMethod: function (cmp, name) {
        if (this['isDebugLog']) {
            console.group('%s, time: %f', name, this.timeStamp());
        }
    },

    stopMethod: function (cmp) {
        if (this['isDebugLog']) {
            console.groupEnd();
        }
    },

    log: function (label, values, style) {
        if (this['isDebugLog']) {
            style = style || '';
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
        this.log('showSpinner' + ', attribute: ' + attribute + ', timeStamp: ' + timeStamp);
        delay = delay || 10000; // time for local spinner
        let delayOneSpinner = 10000; // time for one spinner
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
                        that.hideSpinner(cmp, attribute, timeStamp);
                    }), delay);
                cmp.set(attribute, true);
                cmp.set('v.qSpinners', qSpinners);
            }
        }
        return timeStamp;
    },

    hideSpinner: function (cmp, attribute, timeStamp) {
        this.log('hideSpinner' + ', attribute: ' + attribute);
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
        this.log('getErrMessage');
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

    cancel: function (cmp, isRedirect) {
        this.startMethod(cmp, 'cancel');
        isRedirect = isRedirect || false;
        if (isRedirect) {
            if (!cmp.get('v.recordId')) {
                this.navigateToObjectHome(cmp);
            } else {
                this.navigateToSObject(cmp, cmp.get('v.recordId'));
            }
        } else {
            if (cmp.get('v.isRunning')) {
                this.closeModal(cmp, 'v.isRunning');
            } else {
                this.closeQuickAction();
                this.closeOverlayLib(cmp);
                $A.get('e.force:refreshView').fire();
            }
        }
        this.stopMethod(cmp);
    },

    navigateToSObject: function (cmp, recordId) {
        this.log('navigateToSObject');
        let record = recordId || cmp.get('v.recordId');
        let navEvt = $A.get('e.force:navigateToSObject');
        navEvt.setParams({
            'recordId': record
        });
        navEvt.fire();
    },

    navigateToObjectHome: function () {
        this.log('navigateToObjectHome');
        let homeEvt = $A.get('e.force:navigateHome');
        homeEvt.fire();
    },

    elementValidationStandard: function (cmp, element, label) {
        this.log('elementValidationStandard' + ', element: ' + element);
        let item = cmp.find(element);
        item.showHelpMessageIfInvalid();
        let isValid = item.get('v.validity').valid;
        if (!isValid) {
            this['errFields'].push(label);
        }
        return isValid;
    },

    elementValidation: function (cmp, element, label) {
        this.log('elementValidation' + ', element: ' + element);
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
            this.showErrMessage('The element "' + element + '" was not found.')
        }
        return response;
    },

    formValidation: function (cmp, fields) {
        this.startMethod(cmp, 'formValidation');
        let response = true;
        let that = this;
        fields.forEach(function (field) {
            if (!that.elementValidation(cmp, field.name, field.label)) {
                response = false;
            }
        });
        this.stopMethod(cmp);
        return response;
    },

    trim: function (str) {
        return str.replace(/^\s+|\s+$/g, '');
    },

    showModal: function (cmp, attribute) {
        this.log('showModal');
        cmp.set(attribute, true);
    },

    closeModal: function (cmp, attribute) {
        this.log('closeModal');
        cmp.set(attribute, false);
    },

    closeQuickAction: function () {
        this.log('closeQuickAction');
        $A.get('e.force:closeQuickAction').fire();
    },

    closeOverlayLib: function (cmp) {
        this.log('closeOverlayLib');
        let overlayLib = cmp.find('overlayLib');
        if (overlayLib) {
            overlayLib.notifyClose();
        } else {
            this.showErrMessage('The "overlayLib" was not found.')
        }
    },

    timeStamp: function () {
        return performance.now() / 1000;
    },

    showErrMessage: function (message, title) {
        this.log('showErrMessage');
        this.showMessage(title, message, 'error', 10000);
    },

    showSuccessMessage: function (message, title) {
        this.log('showSuccessMessage');
        this.showMessage(title, message, 'success');
    },

    showWarningMessage: function (message, title) {
        this.log('showWarningMessage');
        this.showMessage(title, message, 'warning');
    },

    showMessage: function (title, message, type, duration, mode) {
        this.log('showMessage');
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