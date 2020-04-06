({
    setActiveSections: function (cmp, event) {
        this.startMethod(cmp, 'setActiveSections');
        let respObject = event.getParam('value');
        let activeSections = [];
        let size = respObject.length;
        for (let i = 0; i < size; i++) {
            activeSections.push('section_' + respObject[i].fieldName);
        }
        setTimeout($A.getCallback(() => cmp.set('v.activeSections', activeSections)), 0);
        this.stopMethod(cmp);
    },

    fetchData: function (cmp) {
        this.startMethod(cmp, 'fetchData');
        cmp.set('v.searchValue', '');
        let that = this;
        let spinner = this.showSpinner(cmp, 'v.isLoading');
        let action = cmp.get('c.getIndicatorCatalogsFiltersPicklistData');
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.startMethod(cmp, 'fetchData-SUCCESS');
                let picklistValuesByRecordType = cmp.get('v.picklistValuesByRecordType');
                that.log('picklistValuesByRecordType', picklistValuesByRecordType);
                let optionsCheckboxGroup = JSON.parse(response.getReturnValue());
                that.log('optionsCheckboxGroup', optionsCheckboxGroup);
                let selectedLibraries = cmp.get('v.selectedLibraries');
                that.log('selectedLibraries', selectedLibraries);
                let checkboxGroup = {};
                let size = selectedLibraries.length;
                for (let l = 0; l < size; l++) {
                    let recordTypeId = selectedLibraries[l];
                    if (recordTypeId !== '0') {
                        if (optionsCheckboxGroup.hasOwnProperty(recordTypeId)) {
                            optionsCheckboxGroup[recordTypeId].forEach(function (field) {
                                if (picklistValuesByRecordType[recordTypeId]['picklistFieldValues']) {
                                    if (picklistValuesByRecordType[recordTypeId]['picklistFieldValues'][field['fieldName']]) {
                                        let valuesSize = picklistValuesByRecordType[recordTypeId]['picklistFieldValues'][field['fieldName']]['values'].length;
                                        let items = [];
                                        for (let h = 0; h < valuesSize; h++) {
                                            let value = picklistValuesByRecordType[recordTypeId]['picklistFieldValues'][field['fieldName']]['values'][h]['value'];
                                            if (checkboxGroup[field['fieldName']]) {
                                                if (checkboxGroup[field['fieldName']].indexOf(value) === -1) {
                                                    items.push(value);
                                                }
                                            } else {
                                                items.push(value);
                                            }
                                        }
                                        let itemsSize = items.length;
                                        if (itemsSize > 0) {
                                            if (!checkboxGroup[field['fieldName']]) {
                                                checkboxGroup[field['fieldName']] = items;

                                            } else {
                                                checkboxGroup[field['fieldName']] = checkboxGroup[field['fieldName']].concat(items);
                                            }
                                        }
                                    }
                                }

                            });
                        }
                    }
                }
                that.log('checkboxGroup', checkboxGroup);
                let newOptionsCheckBoxGroup = [];
                let newOptionsCheckBoxGroup2 = [];
                for (let l = 0; l < size; l++) {
                    let recordTypeId = selectedLibraries[l];
                    if (recordTypeId !== '0') {
                        if (optionsCheckboxGroup.hasOwnProperty(recordTypeId)) {
                            optionsCheckboxGroup[recordTypeId].forEach(function (option) {
                                if (checkboxGroup.hasOwnProperty(option.fieldName)) {
                                    let newItems = [];
                                    checkboxGroup[option.fieldName].forEach(function (item) {
                                        newItems.push({
                                            value: item,
                                            label: item
                                        })
                                    });
                                    if (newItems.length > 0) option['checkboxGroup'] = newItems;
                                }
                                if (newOptionsCheckBoxGroup2.indexOf(option.fieldName) === -1) {
                                    newOptionsCheckBoxGroup.push(option);
                                    newOptionsCheckBoxGroup2.push(option.fieldName);
                                }
                            });
                        }
                    }
                }
                that.log('newOptionsCheckBoxGroup', newOptionsCheckBoxGroup);
                cmp.set('v.optionsCheckboxGroup', newOptionsCheckBoxGroup);
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

    refreshView: function (cmp) {
        this.startMethod(cmp, 'refreshView');
        let data = cmp.get('v.originalData');
        let size = data.length;
        let newData = [];
        if (size > 0) {
            let pickListFields = [];
            let optionsCheckboxGroup = cmp.get('v.optionsCheckboxGroup');
            this.log('optionsCheckboxGroup', optionsCheckboxGroup);
            optionsCheckboxGroup.forEach(function (item) {
                pickListFields.push({
                    fieldName: item.fieldName,
                    fieldValue: item.fieldValue
                })
            });
            console.log(pickListFields);
            let pickListFieldsSize = pickListFields.length;
            // search check
            let isSearch = false;
            let searchValue = this.trim(cmp.get('v.searchValue'), cmp);
            if (searchValue.length > 0) {
                isSearch = true;
                searchValue = searchValue.toLowerCase();
            }
            // loop by original data for new data to display
            for (let i = 0; i < size; i++) {
                let isContinue = false;
                // if the text fields does not contain search value go to the next iteration
                if (isSearch) {
                    let strToLowerCase = data[i]['sfims__Indicator_Name__c'].toLowerCase();
                    if (strToLowerCase.indexOf(searchValue) === -1) {
                        continue;
                    }
                }
                // if the pickList fields does not contain selected options go to the next iteration
                if (pickListFieldsSize > 0) {
                    for (let j = 0; j < pickListFieldsSize; j++) {
                        if (pickListFields[j]['fieldValue'].length > 0) {
                            if (pickListFields[j]['fieldValue'].indexOf(data[i][pickListFields[j]['fieldName']]) === -1) {
                                isContinue = true;
                                break;
                            }
                        }
                    }
                }
                // flag go to the next iteration
                if (isContinue) {
                    continue;
                }
                // if the row matches the filter list - add it to the new list for display
                newData.push(data[i]);
            }
            cmp.set('v.data', newData);
        }
        this.hideSpinner(cmp, 'v.isLoading', 'handleRefreshView');
        this.stopMethod(cmp);
    },

    resetFilters: function (cmp) {
        this.startMethod(cmp, 'resetFilters');
        this.refreshView(cmp);
        /*
        let optionsCheckboxGroup = cmp.get('v.optionsCheckboxGroup');
        optionsCheckboxGroup.forEach(function (item) {
            item.fieldValue = [];
        });
        cmp.set('v.optionsCheckboxGroup', optionsCheckboxGroup);
        cmp.set('v.searchValue', '');
        */
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