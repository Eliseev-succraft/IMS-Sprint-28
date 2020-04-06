({
    resetOptions: function (cmp) {
        // console.log('%s, time: %f', 'resetOptions', this.timeStamp());
        let options = cmp.get('v.options');
        let selectedItem = cmp.get('v.selectedItem');
        options.forEach(function (item, index) {
            item.selected = (parseInt(selectedItem) === index);
        });
        cmp.set('v.options', options);
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

    closeActionModal: function (cmp) {
        console.log('%s, time: %f', 'closeActionModal', this.timeStamp());
        if (cmp.get('v.isModal')) {
            let homeEvent = $A.get('e.force:navigateToObjectHome');
            homeEvent.setParams({
                'scope': 'Task'
            });
            homeEvent.fire();
            setTimeout(function () {
                location.reload(true)
            }, 100);
        } else {
            $A.get('e.force:closeQuickAction').fire();
        }
        $A.get('e.force:refreshView').fire();
    },

    showSpinner: function (cmp, attribute, delay, timeStamp) {
        timeStamp = timeStamp || new Date().getTime();
        console.log('%s, attribute: %s, timeStamp: %s, time: %f', 'showSpinner', attribute, timeStamp, this.timeStamp());
        delay = delay || 5000;
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