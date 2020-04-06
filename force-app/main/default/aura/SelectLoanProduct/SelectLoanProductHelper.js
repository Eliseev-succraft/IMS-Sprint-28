({
    fetchAccess: function (cmp) {
        console.log('%s, time: %f', 'fetchAccess', this.timeStamp());
        let that = this;
        let spinner = this.showSpinner(cmp, 'v.isLoading');
        let action = cmp.get('c.getAccessLoanProduct');
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                console.group('%s, time: %f', 'fetchAccess-SUCCESS', that.timeStamp());
                cmp.set('v.isAccessNewProduct', response.getReturnValue());
                that.hideSpinner(cmp, 'v.isLoading', spinner);
                console.groupEnd();
            }
            else {
                let errors = response.getError();
                that.log('errors', errors);
                that.showErrMessage(that.getErrMessage(errors));
                that.hideSpinner(cmp, 'v.isLoading', spinner);
            }
        });
        $A.enqueueAction(action);
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
        $A.get('e.force:closeQuickAction').fire();
    },

    showSpinner: function (cmp, attribute, delay, timeStamp) {
        timeStamp = timeStamp || new Date().getTime();
        console.log('%s, attribute: %s, timeStamp: %s, time: %f', 'showSpinner', attribute, timeStamp, this.timeStamp());
        delay = delay || 5000;
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

    showErrMessage: function (message, title) {
        console.log('%s, time: %f', 'showErrMessage', this.timeStamp());
        this.showMessage(title, message, 'error');
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