({
    fetchData: function (cmp) {
        console.group('%s, time: %f', 'fetchData', this.timeStamp());
        if (!$A.util.isEmpty(cmp.get('v.recordId'))) {
            let that = this;
            let spinner = this.showSpinner(cmp, 'v.isLoading');
            let action = cmp.get('c.getRepaymentSchedules');
            action.setParams({
                loanId: cmp.get('v.recordId')
            });
            action.setCallback(this, function (response) {
                that.hideSpinner(cmp, 'v.isLoading', spinner);
                let state = response.getState();
                if (state === 'SUCCESS') {
                    console.group('%s, time: %f', 'fetchData-SUCCESS', that.timeStamp());
                    let flagErr = false;
                    console.log(response.getReturnValue());
                    that['loan'] = response.getReturnValue();
                    if (that['loan'].sfims__Open_Ended_Loan__c) {
                        that.showMessage(null, 'Not available for open-ended loans.', 'error');
                        that.closeQuickAction(cmp);
                    } else {
                        that['schedules'] = that['loan'].sfims__Repayment_Schedules__r;
                        if (Array.isArray(that['schedules'])) {
                            let size = that['schedules'].length;
                            if (size) {
                                let options = [];
                                let index = 0;
                                that['schedules'].forEach(function (schedule) {
                                    if (index !== size - 1) {
                                        options.push({
                                            'label': schedule['sfims__Due_Date__c'],
                                            'value': index.toString()
                                        });
                                    }
                                    index++;
                                });
                                if (options.length > 0) {
                                    cmp.set('v.options', options);
                                } else {
                                    flagErr = true;
                                }
                            } else {
                                flagErr = true;
                            }
                        } else {
                            flagErr = true;
                        }
                    }
                    if (flagErr) {
                        that.showMessage(null, 'Repayment Schedules not found.', 'warning');
                        that.closeQuickAction(cmp);
                    }
                    console.groupEnd();
                }
                else {
                    let errors = response.getError();
                    let message = 'Unknown error';
                    if (errors && Array.isArray(errors) && errors.length > 0) {
                        message = errors[0].message;
                    }
                    that.showMessage(null, message, 'error');
                    that.closeQuickAction(cmp);
                }
            });
            $A.enqueueAction(action);
        }
        else {
            this.showMessage(null, 'Required attributes are empty.', 'error');
        }
        console.groupEnd();
    },

    confirm: function (cmp) {
        console.group('%s, time: %f', 'confirm', this.timeStamp());
        if (!$A.util.isEmpty(cmp.get('v.recordId')) && this['schedules'] !== undefined && this['scheduleNumber'] !== undefined) {
            let that = this;
            let spinner = this.showSpinner(cmp, 'v.isLoading');
            let action = cmp.get('c.scheduleBalloonRepayment');
            action.setParams({
                schedulesString: JSON.stringify(this['schedules']),
                scheduleNumber: this['scheduleNumber'],
                loanId: cmp.get('v.recordId'),
            });
            action.setCallback(this, function (response) {
                that.hideSpinner(cmp, 'v.isLoading', spinner);
                let state = response.getState();
                if (state === 'SUCCESS') {
                    console.group('%s, time: %f', 'fetchData-SUCCESS', that.timeStamp());
                    that.showMessage(null, 'The Balloon Repayment has been scheduled successfully.', 'success');
                    that.closeQuickAction(cmp);
                    console.groupEnd();
                }
                else {
                    let errors = response.getError();
                    let message = 'Unknown error';
                    if (errors && Array.isArray(errors) && errors.length > 0) {
                        message = errors[0].message;
                    }
                    that.showMessage(null, message, 'error');
                    that.closeQuickAction(cmp);
                }
            });
            $A.enqueueAction(action);
        }
        else {
            this.showMessage(null, 'Required attributes are empty.', 'error');
        }
        console.groupEnd();
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

    closeQuickAction: function (cmp) {
        console.log('%s, time: %f', 'closeQuickAction', this.timeStamp());
        $A.get('e.force:refreshView').fire();
        $A.get("e.force:closeQuickAction").fire();
        cmp.find('overlayLib').notifyClose();
    },

    showSpinner: function (cmp, attribute, delay, timeStamp) {
        timeStamp = timeStamp || new Date().getTime();
        console.log('%s, attribute: %s, timeStamp: %s, time: %f', 'showSpinner', attribute, timeStamp, this.timeStamp());
        delay = delay || 40000;
        if (!this['spinners']) {
            this['spinners'] = [];
        }
        let size = this['spinners'].length;
        let flag = false;
        for (let i = 0; i < size; i++) {
            if (this['spinners'][i].attribute === attribute) {
                this['spinners'][i].timeStamp.push(timeStamp);
                flag = true;
                break;
            }
        }
        if (!flag) {
            this['spinners'].push({
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
        return timeStamp;
    },

    hideSpinner: function (cmp, attribute, timeStamp) {
        console.log('%s, attribute: %s, timeStamp: %s, time: %f', 'hideSpinner', attribute, timeStamp, this.timeStamp());
        if (this['spinners']) {
            let size = this['spinners'].length;
            for (let i = 0; i < size; i++) {
                if (this['spinners'][i].attribute === attribute) {
                    let elements = this['spinners'][i].timeStamp;
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
        }
    },

    timeStamp: function () {
        return performance.now() / 1000;
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
    }
})