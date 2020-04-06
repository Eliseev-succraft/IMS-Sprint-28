import {LightningElement, api} from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';

export default class lwcUtilityMessage extends LightningElement {
    @api isDebugLog = false;
    debugLogStyle = 'background: green; color: white;';

    connectedCallback() {
        this.begin('initialization');
        this.dispatchEvent(new CustomEvent('loaded'));
        this.end();
    }

    @api showErrorMessage(message, title) {
        this.begin('showErrorMessage');
        this.showMessage(title, message, 'error');
        this.end();
    }

    @api showSuccessMessage(message, title) {
        this.begin('showSuccessMessage');
        this.showMessage(title, message, 'success');
        this.end();
    }

    @api showInfoMessage(message, title) {
        this.begin('showInfoMessage');
        this.showMessage(title, message, 'info');
        this.end();
    }

    @api showWarningMessage(message, title) {
        this.begin('showWarningMessage');
        this.showMessage(title, message, 'warning');
        this.end();
    }

    @api showMessage(title, message, type, mode, messageData) {
        this.begin('showMessage');
        let that = this;
        mode = mode || 'dismissable';
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
        try {
            let toast = {
                title: title,
                variant: type,
                message: message,
                messageData: messageData,
                mode: mode
            };
            if (toast !== undefined) {
                that.dispatchEvent(new ShowToastEvent(toast));
            }
        } catch (e) {
            console.log(e);
            alert(message);
        }
        this.end();
    }

    begin(name) {
        if (this.isDebugLog) {
            console.group('%s, time: %f', name, this.timeStamp());
        }
    }

    end() {
        if (this.isDebugLog) {
            console.groupEnd();
        }
    }

    log(label, values, style) {
        if (this.isDebugLog) {
            style = style || this.debugLogStyle;
            if (values === undefined) {
                values = label;
                label = null;
            }
            if (Array.isArray(values)) {
                if (label !== null) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else if (typeof values === 'object') {
                if (label !== null) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else {
                if (label !== null) {
                    console.log('%c' + label + ' - ' + values, style);
                } else {
                    console.log('%c' + values, style);
                }
            }
        }
    }

    timeStamp() {
        return performance.now() / 1000;
    }
}