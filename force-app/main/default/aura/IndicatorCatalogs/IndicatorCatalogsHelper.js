({
    fetchData: function (cmp) {
        this.startMethod(cmp, 'fetchData');
        let that = this;
        let spinner = this.showSpinner(cmp, 'v.isLoading');
        /*
        if (this['isRefresh']) {
            spinner = this.showSpinner(cmp, 'v.isLoadingLocal');
            this['isRefresh'] = false;
        } else {
            spinner = this.showSpinner(cmp, 'v.isLoading');
        }*/
        let action = cmp.get('c.getIndicatorCatalogsData');
        action.setParams({
            selectedRecordTypes: cmp.get('v.selectedLibraries')
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.startMethod(cmp, 'fetchData-SUCCESS');
                let results = response.getReturnValue();
                if (!results) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner(cmp, 'v.isLoading', spinner);
                    return;
                }
                let values = JSON.parse(results);
                that.log('indicators', values);
                if (!values.hasOwnProperty('allIndicators')) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner(cmp, 'v.isLoading', spinner);
                    return;
                }
                if (!values.hasOwnProperty('allFields') || !values['allFields']) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner(cmp, 'v.isLoading', spinner);
                    return;
                }
                if (!values.hasOwnProperty('availableFields') || !values['availableFields']) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner(cmp, 'v.isLoading', spinner);
                    return;
                }
                if (!values.hasOwnProperty('allRecordTypes') || !values['allRecordTypes']) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner(cmp, 'v.isLoading', spinner);
                    return;
                }
                let selectedLibraries = cmp.get('v.selectedLibraries');
                that.log(selectedLibraries);
                let newColumns = [];
                let allFieldsSize = values.allFields.length;
                for (let t = 0; t < allFieldsSize; t++) {
                    let availableFieldsSize = values.availableFields.length;
                    for (let f = 0; f < availableFieldsSize; f++) {
                        if (values.availableFields[f].value === values.allFields[t]) {
                            newColumns.push({
                                'label': values.availableFields[f].label,
                                'fieldName': values.allFields[t],
                                'type': 'text'
                            })
                        }
                    }
                }
                that.log('new columns', newColumns, that['logSettings']['style1'].value);
                cmp.set('v.columns', newColumns);
                let newColumnsSize = newColumns.length;
                let indicatorSize = values.allIndicators.length;
                let selectedIndicatorsIds = [];
                cmp.get('v.selectedIndicators').forEach(function (indicator) {
                    selectedIndicatorsIds.push(indicator.Id);
                });
                let recordTypes = {};
                values.allRecordTypes.forEach(function (item) {
                    recordTypes[item.value] = item.label;
                });
                for (let i = 0; i < indicatorSize; i++) {
                    values.allIndicators[i]['display'] = (selectedIndicatorsIds.indexOf(values.allIndicators[i]['Id']) === -1);
                    let rowValues = [];
                    for (let c = 0; c < newColumnsSize; c++) {
                        let type = 'text';
                        let typeAttributes = {};
                        if (values.allIndicators[i].hasOwnProperty(newColumns[c].fieldName)) {
                            switch (newColumns[c].fieldName) {
                                case 'sfims__Indicator_Name__c':
                                    type = 'url';
                                    typeAttributes['Id'] = values.allIndicators[i]['Id'];
                                    break;
                                case 'RecordTypeId':
                                    if (recordTypes[values.allIndicators[i]['RecordTypeId']]) {
                                        values.allIndicators[i][newColumns[c].fieldName] = recordTypes[values.allIndicators[i]['RecordTypeId']];
                                    }
                                    break;
                            }
                            rowValues.push({
                                value: values.allIndicators[i][newColumns[c].fieldName],
                                type: type,
                                typeAttributes: typeAttributes
                            })
                        } else {
                            rowValues.push({
                                value: '',
                                type: type,
                                typeAttributes: typeAttributes
                            })
                        }
                    }
                    values.allIndicators[i]['values'] = rowValues;
                }
                cmp.set('v.data', values.allIndicators);
                cmp.set('v.originalData', values.allIndicators);
                that.log('indicator catalog', values, that['logSettings']['style1'].value);
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

    showHideMoreFilters: function (cmp) {
        this.startMethod(cmp, 'showHideMoreFilters');
        let flagShow = cmp.get('v.isShowMoreFilters');
        flagShow = !flagShow;
        cmp.set('v.isShowMoreFilters', flagShow);
        this.stopMethod(cmp);
    },

    addSelected: function (cmp, event) {
        this.startMethod(cmp, 'addSelected');
        let index = event.getSource().get('v.value');
        if (index !== undefined) {
            let rows = cmp.get('v.data');
            if (!rows[index]) {
                this.showErrMessage('Indicator was not received.');
                return;
            }
            this.log(rows[index]);
            // Start
            let convertRow = JSON.parse(JSON.stringify(rows[index]));
            let rowValues = [];
            ['sfims__Indicator_Name__c', 'sfims__Indicator_Type__c', 'RecordTypeId', 'sfims__Standard_Custom__c', 'sfims__Definition__c', 'sfims__Outcome_Area__c'].forEach(function (field) {
                let type = 'text';
                let typeAttributes = {};
                if (convertRow.hasOwnProperty(field)) {
                    switch (field) {
                        case 'sfims__Indicator_Name__c':
                            type = 'url';
                            typeAttributes['Id'] = convertRow.Id;
                            break;
                    }
                    rowValues.push({
                        value: convertRow[field],
                        type: type,
                        typeAttributes: typeAttributes
                    });
                } else {
                    rowValues.push({
                        value: '',
                        type: type,
                        typeAttributes: typeAttributes
                    })
                }
            });
            convertRow.values = rowValues;
            cmp.set('v.selectedIndicatorsOriginal', cmp.get('v.selectedIndicatorsOriginal').concat(convertRow));
            cmp.set('v.selectedIndicators', cmp.get('v.selectedIndicators').concat(convertRow));
            this.log(cmp.get('v.selectedIndicators'));
            rows[index].display = false;
            // rows.splice(index, 1);
            cmp.set('v.data', rows);
            let originalData = cmp.get('v.originalData');
            let originalDataIndex = originalData.findIndex(function (row) {
                return row.Id === rows[index].Id
            });
            if (originalDataIndex === -1) {
                this.showErrMessage('Indicator was not received.');
                return;
            }
            originalData[originalDataIndex].display = false;
            cmp.set('v.originalData', originalData);
            this.hideSpinner(cmp, 'v.isLoading', 'handleAddSelected');
            let appEvent = $A.get('e.c:addSelectedIndicatorsEvent');
            if (appEvent) {
                appEvent.setParams({'indicators': []});
                appEvent.fire();
            }
        }
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