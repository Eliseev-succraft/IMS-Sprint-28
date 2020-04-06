({
    log: function (string, style) {
        let consoleStyles = {
            'h1': 'font: 2.5em/1 Arial; color: crimson;',
            'h2': 'font: 2em/1 Arial; color: orangered;',
            'h3': 'font: 1.5em/1 Arial; color: olivedrab;',
            'bold': 'font: bold 1.3em/1 Arial; color: midnightblue;',
            'warn': 'padding: 0 .5rem; background: crimson; font: 1.6em/1 Arial; color: white;'
        };
        style = style || 'background: crimson; color: white;';
        console.log('%c' + string, style);
    },

    cancel: function (cmp) {
        console.group('%s, time: %f', 'cancel', this.timeStamp());
        if (cmp.get('v.isRunning')) {
            this.closeModal(cmp, 'v.isRunning');
        } else {
            if (!cmp.get('v.recordId')) {
                let homeEvt = $A.get('e.force:navigateToObjectHome');
                homeEvt.setParams({
                    'scope': 'sfims__Investment__c'
                });
                homeEvt.fire();
            } else {
                let navEvt = $A.get('e.force:navigateToSObject');
                navEvt.setParams({
                    'recordId': cmp.get('v.recordId')
                });
                navEvt.fire();
            }
        }
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
        cmp.find('overlayLib').notifyClose();
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
    }
})