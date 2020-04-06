({
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