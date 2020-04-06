({
    isValidForm: function (cmp) {
        console.group('%s, time: %f', 'isValidForm', this.timeStamp());
        let that = this;
        this['errFields'] = [];
        /* standard fields validation */
        let standardValidationFields = [
            {name: 'status'}
        ];
        if (!cmp.get('v.disableAmount')) {
            standardValidationFields.push({name: 'amount'});
        }
        standardValidationFields.forEach(function (item) {
            if (!item.hasOwnProperty('label')) {
                item['label'] = cmp.find(item.name).get('v.label');
            }
        });
        console.log(standardValidationFields);
        let isValid = true;
        standardValidationFields.forEach(function (field) {
            if (!that.elementValidationStandard(cmp, field.name, field.label)) {
                isValid = false;
            }
        });
        // custom validation
        if (!this.elementValidationCustom(cmp, 'transactionDate', cmp.find('transactionDate').get('v.label'))) {
            isValid = false;
        }

        if (!isValid) {
            if (that['errFields']) {
                let size = that['errFields'].length;
                let msg = '';
                if (size > 0) {
                    for (let i = 0; i < size; i++) {
                        msg += '- ' + that['errFields'][i] + '\n';
                    }
                }
                if (msg !== '') {
                    that.showErrMessage($A.get("$Label.sfims.js_error_message_7") + ': \n' + msg);
                }
            } else {
                that.showErrMessage($A.get("$Label.sfims.js_error_message_7") + '.');
            }
        } else {
            return true;
        }
        console.groupEnd();
        return false;
    },

    elementValidationStandard: function (cmp, element, label) {
        console.log('%s, time: %f, %s', 'elementValidationStandard', this.timeStamp(), element);
        let item = cmp.find(element);
        item.showHelpMessageIfInvalid();
        let isValid = item.get('v.validity').valid;
        if (!isValid) {
            this['errFields'].push(label);
        }
        return isValid;
    },

    elementValidationCustom: function (cmp, element, label) {
        console.log('%s, time: %f, %s', 'elementValidationCustom', this.timeStamp(), element);
        let response = true;
        let item = cmp.find(element);
        if (!$A.util.isEmpty(item)) {
            if ($A.util.isEmpty(item.get('v.value'))) {
                $A.util.addClass(item, 'error');
                $A.util.addClass(item, 'slds-has-error');
                this['errFields'].push(label);
                response = false;
            } else {
                $A.util.removeClass(item, 'error');
                $A.util.removeClass(item, 'slds-has-error');
            }
        }
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
            this.showErrMessage($A.get("$Label.sfims.js_error_message_6"));
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
        return 0 // performance.now() / 1000;
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
});