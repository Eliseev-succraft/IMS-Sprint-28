({
    getFieldSets: function (cmp) {
        console.group('%s, time: %f', 'getFieldSets', this.timeStamp());
        let that = this;
        let spinner = this.showSpinner(cmp, 'v.isLoading');
        let action = cmp.get('c.getFieldSets');
        action.setParams({
            mode: 'view'
        });
        action.setCallback(this, function (response) {
            that.hideSpinner(cmp, 'v.isLoading', spinner);
            let state = response.getState();
            if (state === 'SUCCESS') {
                console.group('%s, time: %f', 'getFieldSets-SUCCESS', that.timeStamp());
                let map = JSON.parse(response.getReturnValue());
                console.log(map);
                if (map.hasOwnProperty('top')) {
                    cmp.set('v.topSections', that.formFieldSets(map['top'], that));
                }
                if (map.hasOwnProperty('bottom')) {
                    cmp.set('v.bottomSections', that.formFieldSets(map['bottom'], that));
                }
                console.groupEnd();
            }
            else {
                let errors = response.getError();
                let message = 'Unknown error';
                if (errors && Array.isArray(errors) && errors.length > 0) {
                    message = errors[0].message;
                }
                that.showErrMessage(message);
            }
        });
        $A.enqueueAction(action);
        console.groupEnd();
    },

    formFieldSets: function (fieldSets, that) {
        console.group('%s, time: %f', 'formFieldSets', this.timeStamp());
        let sections = [];
        fieldSets.forEach(function (fieldSet) {
            if (fieldSet.hasOwnProperty('Fields') && fieldSet['Fields'].length > 0) { 
                let section = {};
                section['FieldSet'] = that.structureFields(fieldSet['Fields']);
                section['Label'] = fieldSet['Label'];
                section['isOpen'] = true;
                sections.push(section);
            }
        });
        console.groupEnd();
        return sections;
    },

    structureFields: function (fields) {
        console.log('%s, time: %f', 'structureFields', this.timeStamp());
        let newFields = [];
        let size = fields.length;
        for (let i = 0; i < size; i += 2) {
            let arr = [];
            if (fields[i + 1]) {
                arr = [fields[i], fields[i + 1]];
            } else {
                arr = [fields[i]];
            }
            newFields.push(arr);
        }
        console.log(newFields);
        return newFields;
    },
    
    cancel: function (cmp, object) {
        console.group('%s, time: %f', 'cancel', this.timeStamp());
        // delete this['spinners'];
        if (cmp.get('v.isRunning')) {
            this.closeModal(cmp, 'v.isRunning');
        } else {
            if (!cmp.get('v.recordId')) {
                let homeEvt = $A.get('e.force:navigateToObjectHome');
                homeEvt.setParams({
                    'scope': object
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

    elementValidation: function (cmp, element, label, isShowMsg) {
        console.log('%s, time: %f, %element', 'elementValidation', this.timeStamp(), element);
        isShowMsg = isShowMsg || false;
        let response = true;
        let item = cmp.find(element);
        if (!$A.util.isEmpty(item)) {
            if ($A.util.isEmpty(item.get('v.value'))) {
                $A.util.addClass(item, 'error');
                $A.util.addClass(item, 'slds-has-error');
                if (isShowMsg) {
                    this.showMessage(null, 'The field ' + label + ' has been not filled.', 'warning');
                }
                response = false;
            } else {
                $A.util.removeClass(item, 'error');
                $A.util.removeClass(item, 'slds-has-error');
            }
        }
        return response;
    },

    formValidation: function (cmp, fields, isShowMsg) {
        console.group('%s, time: %f', 'formValidation', this.timeStamp());
        let response = true;
        for (let field in fields) {
            if (fields.hasOwnProperty(field)) {
                if (!this.elementValidation(cmp, field, fields[field], isShowMsg)) {
                    response = false;
                }
            }
        }
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

    closeQuickAction: function (cmp) {
        console.log('%s, time: %f', 'closeQuickAction', this.timeStamp());
        $A.get('e.force:closeQuickAction').fire();
    },

    showSpinner: function (cmp, attribute, delay, timeStamp) {
        timeStamp = timeStamp || new Date().getTime();
        let spinners = cmp.get('v.spinners');
        console.log('%s, attribute: %s, timeStamp: %s, time: %f', 'showSpinner', attribute, timeStamp, this.timeStamp());
        delay = delay || 5000;
        /*
        if (!this['spinners']) {
            this['spinners'] = [];
        }
        */
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
            spinners.push(
                {
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
        this.showMessage(title, message, 'error');
    },

    showSuccessMessage: function (message, title) {
        console.log('%s, time: %f', 'showSuccessMessage', this.timeStamp());
        this.showMessage(title, message, 'success');
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