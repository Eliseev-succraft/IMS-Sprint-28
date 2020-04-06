({
    recalculateWithLoanEvents: function (cmp) {
        console.group('%s, time: %f', 'recalculateWithLoanEvents', this.timeStamp());
        let that = this;
        let spinner = this.showSpinner(cmp, 'v.isLoading');
        let action = cmp.get('c.runRecalculationScheduler');
        console.log(that['loanJSON']);
        action.setParams({
            loanString: that['loanJSON']
        });
        action.setCallback(this, function (response) {
            that.hideSpinner(cmp, 'v.isLoading', spinner);
            let state = response.getState();
            if (state === 'SUCCESS') {
                let jobId = response.getReturnValue();
                if (jobId) {
                    that['jobId'] = jobId;
                } else {
                    that.showErrMessage('The job not scheduled');
                    that.cancel(cmp);
                }
                console.group('%s, time: %f', 'fetchData-SUCCESS', that.timeStamp());
                that['eventCounter'] = 0;
                that['eventDate'] = null;
                that['index'] = 0;
                that.runProcessLoadEvents(cmp);
                console.groupEnd();
            }
            else {
                let errors = response.getError();
                that.log('errors', errors);
                that.showErrMessage(that.getErrMessage(errors));
                that.cancel(cmp);
            }
        });
        $A.enqueueAction(action);
        console.groupEnd();
    },

    runProcessLoadEvents: function (cmp) {
        console.group('%s, time: %f', 'runProcessLoadEvents', this.timeStamp());
        this.toggleProgress(cmp);
        let that = this;
        let spinner = this.showSpinner(cmp, 'v.isLoading');
        let action = cmp.get('c.processLoanEvent');
        action.setParams({
            loanString: that['loanJSON'],
            loanEventsString: JSON.stringify(that['loanEvents']),
            eventDate: that['eventDate'],
            eventNumber: that['eventCounter'],
            index: that['index'],
            jobID: that['jobId']
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                console.group('%s, time: %f', 'fetchData-SUCCESS', that.timeStamp());
                let map = response.getReturnValue();
                that.log('processLoanEvent', map);
                if (map) {
                    if (map.hasOwnProperty('eventDate')) {
                        that['eventDate'] = map['eventDate'];
                        if (map.hasOwnProperty('index')) {
                            that['index'] = map['index'];
                        }
                        //that.toggleProgress(cmp);
                        if (that['loanEvents'].length > that['eventCounter'] + 1) {
                            that['eventCounter']++;
                            that.runProcessLoadEvents(cmp);
                        } else {
                            that.showSuccessMessage('Recalculation completed.');
                            that.cancel(cmp);
                        }
                        that.hideSpinner(cmp, 'v.isLoading', spinner);
                    } else {
                        that.showErrMessage('The eventDate or index was not received from processLoanEvent.');
                        that.cancel(cmp);
                    }
                } else {
                    that.showErrMessage('No data was received from processLoanEvent.');
                    that.cancel(cmp);
                }
                console.groupEnd();
            }
            else {
                let errors = response.getError();
                that.log('errors', errors);
                that.showErrMessage(that.getErrMessage(errors));
                that.cancel(cmp);
            }
        });
        $A.enqueueAction(action);
        console.groupEnd();
    },

    recalculateWithoutLoanEvents: function (cmp) {
        console.group('%s, time: %f', 'recalculateWithoutLoanEvents', this.timeStamp());
        let that = this;
        let spinner = this.showSpinner(cmp, 'v.isLoading');
        let action = cmp.get('c.runRecalculationWithoutLoanEvents');
        action.setParams({
            loanString: that['loanJSON']
        });
        action.setCallback(this, function (response) {
            that.hideSpinner(cmp, 'v.isLoading', spinner);
            let state = response.getState();
            if (state === 'SUCCESS') {
                console.group('%s, time: %f', 'fetchData-SUCCESS', that.timeStamp());
                that.showSuccessMessage('Recalculation completed.');
                that.cancel(cmp);
                console.groupEnd();
            }
            else {
                let errors = response.getError();
                that.log('errors', errors);
                that.showErrMessage(that.getErrMessage(errors));
                that.cancel(cmp);
            }
        });
        $A.enqueueAction(action);
        console.groupEnd();
    },

    toggleProgress: function (cmp) {
        console.log('%s, time: %f', 'toggleProgress', this.timeStamp());
        cmp.set('v.progress', Number(cmp.get('v.progress') + this['toggleStep']));
    },

    cancel: function (cmp, isRedirect) {
        console.group('%s, time: %f', 'cancel', this.timeStamp());
        isRedirect = isRedirect || false;
        if (cmp.get('v.isRunning')) {
            this.closeModal(cmp, 'v.isRunning');
        } else {
            if (isRedirect) {
                if (!cmp.get('v.recordId')) {
                    this.navigateToObjectHome();
                } else {
                    this.navigateToSObject(cmp, cmp.get('v.recordId'));
                }
            } else {
                this.closeQuickAction();
                this.closeOverlayLib(cmp);
                $A.get('e.force:refreshView').fire();
            }
        }
        console.groupEnd();
    },

    navigateToSObject: function (cmp, recordId) {
        console.log('%s, time: %f', 'navigateToSObject', this.timeStamp());
        let record = recordId || cmp.get('v.recordId');
        let navEvt = $A.get('e.force:navigateToSObject');
        navEvt.setParams({
            'recordId': record
        });
        navEvt.fire();
    },

    navigateToObjectHome: function () {
        console.log('%s, time: %f', 'navigateToObjectHome', this.timeStamp());
        let homeEvt = $A.get('e.force:navigateToObjectHome');
        homeEvt.setParams({
            'scope': 'sfims__Investment__c'
        });
        homeEvt.fire();
    },

    elementValidation: function (cmp, element, label) {
        console.log('%s, time: %f, %s', 'elementValidation', this.timeStamp(), element);
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
        }
        return response;
    },

    formValidation: function (cmp, fields, recordUi) {
        console.group('%s, time: %f', 'formValidation', this.timeStamp());
        if (!this['errFields']) {
            this['errFields'] = [];
        }
        let response = true;
        recordUi = recordUi || null;
        let recordUiFields = {};
        if (recordUi) {
            if (recordUi.hasOwnProperty('recordUi')) {
                if (recordUi['recordUi'].hasOwnProperty('objectInfo')) {
                    if (recordUi['recordUi']['objectInfo'].hasOwnProperty('fields')) {
                        recordUiFields = recordUi['recordUi']['objectInfo']['fields'];
                    }
                }
            }
        }
        let that = this;
        fields.forEach(function (field) {
            if (!that.elementValidation(cmp, field, (recordUiFields.hasOwnProperty(field) ? recordUiFields[field]['label'] : null))) {
                response = false;
            }
        });
        console.groupEnd();
        return response;
    },

    trim: function (str) {
        return str.replace(/^\s+|\s+$/g, '');
    },

    showModal: function (cmp, attribute) {
        console.log('%s, time: %f', 'showModal', this.timeStamp());
        cmp.set(attribute, true);
    },

    closeModal: function (cmp, attribute) {
        console.log('%s, time: %f', 'closeModal', this.timeStamp());
        cmp.set(attribute, false);
    },

    closeQuickAction: function () {
        console.log('%s, time: %f', 'closeQuickAction', this.timeStamp());
        $A.get('e.force:closeQuickAction').fire();
    },

    closeOverlayLib: function (cmp) {
        console.log('%s, time: %f', 'closeOverlayLib', this.timeStamp());
        let overlayLib = cmp.find('overlayLib');
        if (overlayLib) {
            overlayLib.notifyClose();
        } else {
            this.showErrMessage('The "overlayLib" was not found.')
        }
    },

    showSpinner: function (cmp, attribute, delay, timeStamp) {
        timeStamp = timeStamp || new Date().getTime();
        console.log('%s, attribute: %s, timeStamp: %s, time: %f', 'showSpinner', attribute, timeStamp, this.timeStamp());
        delay = delay || 40000;
        let spinners = cmp.get('v.spinners');
        let size = spinners.length;
        let flag = false;
        for (let i = 0; i < size; i++) {
            if (spinners[i].attribute === attribute) {
                spinners[i].timeStamp.push(timeStamp);
                flag = true;
                break;
            }
        }
        if (!flag) {
            spinners.push({
                'attribute': attribute,
                'timeStamp': [timeStamp]
            });
        }
        let that = this;
        window.setTimeout(
            $A.getCallback(function () {
                that.hideSpinner(cmp, attribute, timeStamp);
            }), delay);
        cmp.set(attribute, true);
        cmp.set('v.spinners', spinners);
        return timeStamp;
    },

    hideSpinner: function (cmp, attribute, timeStamp) {
        console.log('%s, attribute: %s, timeStamp: %s, time: %f', 'hideSpinner', attribute, timeStamp, this.timeStamp());
        let spinners = cmp.get('v.spinners');
        if (spinners) {
            let size = spinners.length;
            for (let i = 0; i < size; i++) {
                if (spinners[i].attribute === attribute) {
                    let elements = spinners[i].timeStamp;
                    let index = elements.indexOf(timeStamp);
                    if (index !== -1) {
                        if (elements.length === 1) {
                            cmp.set(attribute, false);
                        }
                        elements.splice(index, 1);
                    }
                    break;
                }
            }
            cmp.set('v.spinners', spinners);
        }
    },

    log: function (label, values, style) {
        let consoleStyles = {
            'h1': 'font: 2.5em/1 Arial; color: crimson;',
            'h2': 'font: 2em/1 Arial; color: orangered;',
            'h3': 'font: 1.5em/1 Arial; color: olivedrab;',
            'bold': 'font: bold 1.3em/1 Arial; color: midnightblue;',
            'warn': 'padding: 0 .5rem; background: crimson; font: 1.6em/1 Arial; color: white;'
        };
        style = style || 'background: blue; color: white;';
        if (Array.isArray(values)) {
            console.log('%c' + label, style);
            console.log(values);
        } else if (typeof values === 'object') {
            console.log('%c' + label, style);
            console.log(JSON.parse(JSON.stringify(values)));
        } else {
            console.log('%c' + label + ' - ' + values, style);
        }
    },

    timeStamp: function () {
        return performance.now() / 1000;
    },

    showErrMessage: function (message, title) {
        console.log('%s, time: %f', 'showErrMessage', this.timeStamp());
        this.showMessage(title, message, 'error', 10000);
    },

    showSuccessMessage: function (message, title) {
        console.log('%s, time: %f', 'showSuccessMessage', this.timeStamp());
        this.showMessage(title, message, 'success');
    },

    showWarningMessage: function (message, title) {
        console.log('%s, time: %f', 'showWarningMessage', this.timeStamp());
        this.showMessage(title, message, 'warning');
    },

    showMessage: function (title, message, type, duration, mode) {
        console.log('%s, time: %f', 'showMessage', this.timeStamp());
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
    },

    getErrMessage: function(errors) {
        console.log('%s, time: %f', 'getErrMessage', this.timeStamp());
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
    }
});