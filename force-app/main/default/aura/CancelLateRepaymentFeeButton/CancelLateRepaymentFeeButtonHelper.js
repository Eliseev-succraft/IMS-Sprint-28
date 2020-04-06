({
    fetchData: function (cmp) {
    	if ($A.util.isEmpty(cmp.get('v.recordId'))) {
    		this.showErrMessage($A.get("$Label.sfims.js_error_message_4"))
    		return;
		}
        let that = this;
        let spinner = that.run(that.showSpinner, [cmp, 'v.isLoading']);
        let action = cmp.get('c.cancelLateRepaymentFee');
        action.setParams({
            rsId: cmp.get('v.recordId')
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.group('fetchData-SUCCESS');
                that.run(that.hideSpinner, [cmp, 'v.isLoading', spinner]);
                that.run(that.showSuccessMessage, [response.getReturnValue()]);
                that.run(that.cancel, [cmp]);
                that.groupEnd();
            } else {
                that.group('fetchData-ERROR');
                let errors = response.getError();
                that.log('errors', errors);
                that.run(that.showErrMessage, [that.run(that.getErrMessage, [errors])]);
                that.run(that.hideSpinner, [cmp, 'v.isLoading', spinner]);
                that.run(that.cancel, [cmp]);
                that.groupEnd();
            }
        });
        $A.enqueueAction(action);
    },

    run: function (func, arg) {
        let response;
        this.group(func.name);
        try {
            response = func.apply(this, arg);
        } catch (e) {
            console.log(e);
            this.showErrMessage($A.get("$Label.sfims.js_error_message_2"));
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
        this.log('attribute: ' + attribute + ', timeStamp: ' + timeStamp);
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
        let message = $A.get("$Label.sfims.js_error_message_5");
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
                this.run(this.closeQuickAction, [cmp]);
                this.run(this.forceRefreshView, [cmp]);
                // this.run(this.closeOverlayLib, [cmp]);
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
        } else {
            this.run(this.showErrMessage, [$A.get("$Label.sfims.js_error_message_6")]);
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
        item.showHelpMessageIfInvalid();
        let isValid = item.get('v.validity').valid;
        if (!isValid) {
            this['errFields'].push(label);
        }
        return isValid;
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
            this.run(this.showErrMessage, [$A.get("$Label.sfims.part_of_js_error_message_1") + ' "' + element + '" ' + $A.get("$Label.sfims.part_of_js_error_message_2") + '.']);
        }
        return response;
    },

    formValidation: function (cmp, fields) {
        let response = true;
        let that = this;
        fields.forEach(function (field) {
            if (!this.run(that.elementValidation, [cmp, field.name, field.label])) {
                response = false;
            }
        });
        return response;
    },

    trim: function (str) {
        return str.replace(/^\s+|\s+$/g, '');
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
        this.run(this.showMessage, [title, message, 'error', 10000]);
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