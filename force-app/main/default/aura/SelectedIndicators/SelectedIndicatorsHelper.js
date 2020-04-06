({
    fetchData: function (cmp) {
        this.startMethod(cmp, 'fetchData');
        let that = this;
        let spinner = this.showSpinner(cmp, 'v.isLoading');
        let action = cmp.get('c.loadSelectedIndicators');
        action.setParams({
            templateId: cmp.get('v.recordId')
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
                if (!values.hasOwnProperty('allRecordTypes') || !values['allRecordTypes']) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner(cmp, 'v.isLoading', spinner);
                    return;
                }
                let columns = cmp.get('v.columns');
                let columnsSize = columns.length;
                let indicatorSize = values.allIndicators.length;
                let recordTypes = {};
                values.allRecordTypes.forEach(function (item) {
                    recordTypes[item.value] = item.label;
                });
                for (let i = 0; i < indicatorSize; i++) {
                    let rowValues = [];
                    for (let c = 0; c < columnsSize; c++) {
                        let type = 'text';
                        let typeAttributes = {};
                        if (values.allIndicators[i].hasOwnProperty(columns[c].fieldName)) {
                            switch (columns[c].fieldName) {
                                case 'sfims__Indicator_Name__c':
                                    type = 'url';
                                    typeAttributes['Id'] = values.allIndicators[i]['Id'];
                                    break;
                                case 'RecordTypeId':
                                    if (recordTypes[values.allIndicators[i]['RecordTypeId']]) {
                                        values.allIndicators[i][columns[c].fieldName] = recordTypes[values.allIndicators[i]['RecordTypeId']];
                                    }
                                    break;
                            }
                            rowValues.push({
                                value: values.allIndicators[i][columns[c].fieldName],
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
                that.log('indicators', values);
                /*
                results.forEach(function (row) {
                    let values = [];
                    cmp.get('v.columns').forEach(function (field) {
                        if (row.hasOwnProperty(field.fieldName)) {
                            values.push(row[field.fieldName]);
                        } else {
                            values.push('');
                        }
                    });
                    row.values = values;
                });*/
                let str = JSON.stringify(values.allIndicators);
                cmp.set('v.data', JSON.parse(str));
                cmp.set('v.originalData', JSON.parse(str));
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

    deleteSelected: function (cmp, event) {
        this.startMethod(cmp, 'deleteSelected');
        let index = event.getSource().get('v.value');
        if (index !== undefined) {
            let rows = cmp.get('v.data');
            if (!rows[index]) {
                this.showErrMessage('Indicator was not received.');
                return;
            }
            let indicatorCatalogsData = cmp.get('v.indicatorCatalogsData');
            let indicatorIndex = indicatorCatalogsData.findIndex(function (row) {
                return row.Id === rows[index].Id
            });
            if (indicatorIndex !== -1) {
                indicatorCatalogsData[indicatorIndex].display = true;
                cmp.set('v.indicatorCatalogsData', indicatorCatalogsData);
            }
            let indicatorCatalogsOriginal = cmp.get('v.indicatorCatalogsOriginal');
            let indicatorIndexOriginal = indicatorCatalogsOriginal.findIndex(function (row) {
                return row.Id === rows[index].Id
            });
            if (indicatorIndexOriginal !== -1) {
                indicatorCatalogsOriginal[indicatorIndexOriginal].display = true;
                cmp.set('v.indicatorCatalogsOriginal', indicatorCatalogsOriginal);
            }
            let originalData = cmp.get('v.originalData');
            let originalIndex = originalData.findIndex(function (row) {
                return row.Id === rows[index].Id
            });
            if (originalIndex === -1) {
                this.showErrMessage('Indicator was not received.2');
                return;
            }
            originalData.splice(originalIndex, 1);
            cmp.set('v.originalData', originalData);
            rows.splice(index, 1);
            cmp.set('v.data', rows);
            this.hideSpinner(cmp, 'v.isLoading', 'handleDeleteSelected');
            let appEvent = $A.get('e.c:addSelectedIndicatorsEvent');
            if (appEvent) {
                appEvent.setParams({'indicators': []});
                appEvent.fire();
            }
        }
        this.stopMethod(cmp);
    },

    unique: function (id, cData) {
        this.log('unique');
        let size = cData.length;
        for (let i = 0; i < size; i++) {
            if (cData[i].Id === id) {
                return false;
            }
        }
        return true;
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

    navigateToHome: function () {
        this.log('navigateToHome');
        let homeEvt = $A.get('e.force:navigateHome');
        homeEvt.fire();
    },

    navigateToObjectHome: function () {
        this.log('navigateToObjectHome');
        let homeEvent = $A.get('e.force:navigateToObjectHome');
        homeEvent.setParams({
            'scope': 'sfims__Report_Template__c'
        });
        homeEvent.fire();
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