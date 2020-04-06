import {LightningElement, api} from 'lwc';

export default class lwcUtilitySystem extends LightningElement {
    @api isDebugLog = false;
    @api modals = {};
    debugLogStyle = 'background: green; color: white;';

    connectedCallback() {
        this.begin('initialization');
        this.dispatchEvent(new CustomEvent('loaded'));
        this.end();
    }

    @api getAuraErrorsFromRequest(errors) {
        this.begin('getAuraErrorsFromRequest');
        let message = 'Unknown error';
        if (errors && Array.isArray(errors) && errors.length > 0) {
            let msgErrors = '';
            errors.forEach(function (err) {
                if (err.hasOwnProperty('message')) {
                    let details = '';
                    if (err.hasOwnProperty('stackTrace')) {
                        details = '\n(' + err['stackTrace'] + ')';
                    }
                    msgErrors += err.message + details + '\n';
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
        this.end();
        return message;
    }

    @api getAuraErrorsFromRecordForm(errors) {
        this.begin('getAuraErrorsFromRecordForm');
        let message = 'Unknown error';
        let groupErr = {};
        if (errors.hasOwnProperty('output')) {
            if (errors.output.hasOwnProperty('fieldErrors')) {
                for (let key in errors.output.fieldErrors) {
                    if (errors.output.fieldErrors.hasOwnProperty(key)) {
                        for (let i = 0; i < errors.output.fieldErrors[key].length; i++) {
                            if (errors.output.fieldErrors[key][i].hasOwnProperty('message')) {
                                if (!groupErr.hasOwnProperty(errors.output.fieldErrors[key][i]['message'])) {
                                    groupErr[errors.output.fieldErrors[key][i]['message']] = [];
                                }
                                groupErr[errors.output.fieldErrors[key][i]['message']].push({
                                    label: errors.output.fieldErrors[key][i]['fieldLabel'],
                                    name: key
                                });
                            }
                        }
                    }
                }
            }
        }
        let msg = '';
        for (let key in groupErr) {
            if (groupErr.hasOwnProperty(key)) {
                let size = groupErr[key].length;
                let points = '';
                if (size > 0) {
                    for (let i = 0; i < size; i++) {
                        points += '- ' + groupErr[key][i]['label'] + '\n';
                    }
                }
                if (points !== '') {
                    msg += key + '\n' + points;
                }
            }
        }
        if (msg !== '') {
            message = msg;
        } else if (errors['detail']) {
            message = errors['detail'];
        } else if (errors['message']) {
            message = errors['message'];
        }
        this.end();
        return message;
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
                console.log(values);
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