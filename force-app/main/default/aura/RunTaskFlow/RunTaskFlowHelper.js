({
    fetchData: function (cmp) {
        this.startMethod(cmp, 'fetchData');
        if (!$A.util.isEmpty(cmp.get('v.taskId'))) {
            let that = this;
            let spinner = this.showSpinner(cmp, 'v.isLoading');
            let action = cmp.get('c.apexGetFlowName');
            action.setParams({
                taskId: cmp.get('v.taskId')
            });
            action.setCallback(this, function (response) {
                let state = response.getState();
                if (state === 'SUCCESS') {
                    that.startMethod(cmp, 'fetchData-SUCCESS');
                    let errFlag = false;
                    let json = response.getReturnValue();
                    if (json) {
                        let classResponse = JSON.parse(json);
                        that.log(classResponse);
                        that['classResponse'] = classResponse;
                        if (classResponse.hasOwnProperty('status')) {
                            switch (classResponse['status']) {
                                case 'Open':
                                    errFlag = that.choiceFowStartingMethod(cmp, classResponse);
                                    break;
                                case 'Rejected':
                                    errFlag = that.choiceFowStartingMethod(cmp, classResponse);
                                    break;
                                case 'Pending':
                                    that.showWarningMessage('The flow has not been assigned.');
                                    that.cancel(cmp, true);
                                    break;
                                case 'Done':
                                    that.showWarningMessage('The flow has not been assigned.');
                                    that.cancel(cmp, true);
                                    break;
                                case 'Pending Approval':
                                    that.showWarningMessage('The flow has not been assigned.');
                                    that.cancel(cmp, true);
                                    break;
                                default:
                                    that.cancel(cmp, true);
                            }
                        } else {
                            errFlag = true;
                        }
                    } else {
                        that.showWarningMessage('The flow has not been assigned.');
                        that.cancel(cmp, true);
                    }
                    if (errFlag) {
                        that.showWarningMessage('Runtime error.');
                        that.cancel(cmp, true);
                    }
                    that.stopMethod(cmp);
                }
                else {
                    let errors = response.getError();
                    that.log('errors', errors);
                    that.showErrMessage(that.getErrMessage(errors));
                    that.cancel(cmp, true);
                }
                that.hideSpinner(cmp, 'v.isLoading', spinner);
            });
            $A.enqueueAction(action);
        } else {
            this.showErrMessage('Required attribute \'taskId\' is empty.');
            this.cancel(cmp, true);
        }
        this.stopMethod(cmp);
    },

    choiceFowStartingMethod: function (cmp, classResponse) {
        this.startMethod(cmp, 'choiceFowStartingMethod');
        let resumeFlowFlag = false;
        if (classResponse.hasOwnProperty('resumeFlowId')) {
            if (classResponse.resumeFlowId) {
                resumeFlowFlag = true;
                this.resumeFlow(cmp, classResponse.resumeFlowId);
            }
        }
        let startFlowFlag = false;
        if (!resumeFlowFlag) {
            if (classResponse.hasOwnProperty('taskListTemplateItem') && classResponse.hasOwnProperty('standardTask')) {
                if (classResponse.taskListTemplateItem.hasOwnProperty('sfims__Flow_Name__c') && classResponse.standardTask.hasOwnProperty('WhatId')) {
                    startFlowFlag = true;
                    this.startFlow(cmp, classResponse.taskListTemplateItem.sfims__Flow_Name__c, classResponse.standardTask.WhatId);
                }
            }
        }
        this.stopMethod(cmp);
        return (resumeFlowFlag === false && startFlowFlag === false);
    },

    startFlow: function (cmp, flowName, assignedTo) {
        this.startMethod(cmp, 'startFlow');
        this.log('Flow', flowName);
        if (!$A.util.isEmpty(flowName) && !$A.util.isEmpty(assignedTo) && !$A.util.isEmpty(cmp.get('v.taskId'))) {
            // this.showSpinner(cmp, 'v.isLoading', 10000, 'startFlow');
            let inputVariables = [
                {name: 'recordId', type: 'String', value: assignedTo},
                {name: 'taskId', type: 'String', value: cmp.get('v.taskId')},
            ];
            let flow = cmp.find('flowData');
            flow.startFlow(flowName, inputVariables);
        } else {
            this.showErrMessage('Required attributes are empty.');
            this.cancel(cmp);
        }
        this.stopMethod(cmp);
    },

    resumeFlow: function (cmp, resumeFlowId) {
        this.startMethod(cmp, 'resumeFlow' + ', resumeFlow: ' + resumeFlowId);
        let flow = cmp.find('flowData');
        flow.resumeFlow(resumeFlowId);
        this.stopMethod(cmp);
    },

    changeStatusTask: function (cmp, taskId, status) {
        this.startMethod(cmp, 'changeStatusTask' + ', status: ' + status);
        let that = this;
        if (!$A.util.isEmpty(status) && !$A.util.isEmpty(taskId)) {
            //   let spinner = this.showSpinner(cmp, 'v.isLoading');
            let action = cmp.get('c.apexChangeStatusTask');
            action.setParams({
                taskId: taskId,
                status: status
            });
            action.setCallback(this, function (response) {
                // this.hideSpinner(cmp, 'v.isLoading', spinner);
                let state = response.getState();
                if (state === 'SUCCESS') {
                    that.startMethod(cmp, 'changeStatusTask-SUCCESS');
                    if (response.getReturnValue()) {
                        switch (status) {
                            case 'Pending Approval':
                                that.showSuccessMessage('The task was submitted for approval.');
                                break;
                            default:
                                that.showSuccessMessage('The task was completed successfully.');
                        }
                        that.cancel(cmp);
                        cmp.set('v.isCompletedFlow', true);
                    } else {
                        that.showErrMessage('The task has not been completed.');
                        that.cancel(cmp);
                    }
                    that.stopMethod(cmp);
                }
                else {
                    let errors = response.getError();
                    that.log('errors', errors);
                    that.showErrMessage(that.getErrMessage(errors));
                    that.cancel(cmp);
                }
            });
            $A.enqueueAction(action);
        } else {
            let message = 'Required attributes \'Status, TaskId\' are empty.';
            this.showErrMessage(message);
            this.cancel(cmp);
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