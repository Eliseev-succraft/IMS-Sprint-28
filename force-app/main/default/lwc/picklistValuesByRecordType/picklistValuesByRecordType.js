import {LightningElement, api, wire} from 'lwc';
import {getPicklistValuesByRecordType} from 'lightning/uiObjectInfoApi';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import OBJECT from '@salesforce/schema/Indicator_Catalogue__c';

export default class PicklistValuesByRecordType extends LightningElement {
    @api recordTypes;
    recordTypeId;
    @api isDebugLog;
    logSettings = {
        text: '',
        array: 'background: green; color: white;',
        object: 'background: green; color: white;',
    };
    // Global attributes
    isRunning = false;
    recordTypeIndex = 0;

    response = {};

    connectedCallback() {
        this.startMethod('connectedCallback');
        this.log('initialization');
        this.log('record types', this.recordTypes);
        this.recordTypeId = this.recordTypes[this.recordTypeIndex].value;
        this.stopMethod();
    }

    @wire(getPicklistValuesByRecordType, {objectApiName: OBJECT, recordTypeId: '$recordTypeId'})
    picklistValuesByRecordType({error, data}) {
        this.startMethod('picklistValuesByRecordType');
        let that = this;
        if (error) {
            let message = 'Unknown error';
            if (Array.isArray(error.body)) {
                message = error.body.map(e => e.message).join(', ');
            } else if (typeof error.body.message === 'string') {
                message = error.body.message;
            }
            that.showErrMessage(message);
        } else if (data) {
            that.log('recordTypeId', this.recordTypeId);
            that.log(data);
            this.response[this.recordTypeId] = data;
            if (this.recordTypeIndex < this.recordTypes.length - 1) {
                this.recordTypeIndex++;
                this.recordTypeId = this.recordTypes[this.recordTypeIndex].value;
            } else {
                const customEvent = new CustomEvent('GetPicklistValues', {
                    detail: {values: this.response}
                });
                this.dispatchEvent(customEvent);
            }
        }
        this.stopMethod()
    }

    startTimer(name) {
        if (this.isDebugLog) {
            console.time(name);
        }
    }

    stopTimer(name) {
        if (this.isDebugLog) {
            console.timeEnd(name);
        }
    }

    startMethod(name) {
        if (this.isDebugLog) {
            console.group('%s, time: %f', name, this.timeStamp());
        }
    }

    stopMethod() {
        if (this.isDebugLog) {
            console.groupEnd();
        }
    }

    log(label, values, style) {
        if (this.isDebugLog) {
            style = style || '';
            if (!values) {
                values = label;
                label = '';
            }
            if (Array.isArray(values)) {
                if (!style) {
                    style = this.logSettings.array;
                }
                if (label) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else if (typeof values === 'object') {
                style = this.logSettings.object;
                if (label) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else {
                if (!style) {
                    style = this.logSettings.text;
                }
                if (label) {
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

    showErrMessage(message, title) {
        this.log('showErrMessage');
        this.showMessage(title, message, 'error');
    }

    showSuccessMessage(message, title) {
        this.log('showSuccessMessage');
        this.showMessage(title, message, 'success');
    }

    showWarningMessage(message, title) {
        this.log('showWarningMessage');
        this.showMessage(title, message, 'warning');
    }

    showMessage(title, message, type, mode) {
        this.log('showMessage');
        mode = mode || 'dismissable';
        // pester—Remains visible for 3 seconds.
        // sticky—Remains visible until the user clicks the close button.
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
        const toast = new ShowToastEvent({
            'title': title,
            'message': message,
            'messageData': [
                'Salesforce',
                {
                    url: 'http://www.salesforce.com/',
                    label: 'here'
                }
            ],
            'variant': type,
            'mode': mode
        });
        if (toast !== undefined) {
            this.dispatchEvent(toast);
        }
        else {
            alert(message);
        }
    }
}