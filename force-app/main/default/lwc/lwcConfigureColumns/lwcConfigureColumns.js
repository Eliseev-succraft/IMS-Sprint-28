import {LightningElement, api, track, wire} from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import getSettingsData from '@salesforce/apex/configureColumnsController.getSettingsData';
import saveAllConfigures from '@salesforce/apex/configureColumnsController.saveAllConfigures';

export default class lwcConfigureColumns extends LightningElement {
    @api isDebugLog = false;
    isRunning = false;
    qSpinners = {};
    cmpSpinner = {};
    @track spinner = {
        main: false
    };
    @track modals = {};
    logSettings = {
        style1: {
            value: 'background: blue; color: white;'
        },
        defaultLogStyle: {
            value: 'background: green; color: white;'
        }
    };
    @api isShowConfigureColumns;
    min = 5;
    max = 10;
    objRecordType = {
        'availableFields': [],
        'recordTypes': {}
    };
    defaultFields = [
        {'label': 'Indicator Name', 'value': 'sfims__Indicator_Name__c'},
        {'label': 'Indicator Type', 'value': 'sfims__Indicator_Type__c'},
        {'label': 'Library', 'value': 'RecordTypeId'},
        {'label': 'Definition', 'value': 'sfims__Definition__c'},
        {'label': 'Outcome Area', 'value': 'sfims__Outcome_Area__c'}
    ];
    @track selectedLibraryName = '';
    @track values;
    @track requiredFields;
    @track options;
    recordTypes;
    @track allRecordTypes = [];
    selectedRecordType;

    connectedCallback() {
        this.group('connectedCallback');
        this.log('initialization');
        this.groupEnd();
    }

    handleOpenConfigureColumn() {
        this.group('handleOpenConfigureColumn');
        this.showModal('isShowConfigureColumns');
        this.fetchData();
        this.groupEnd();
    }

    handleChangeViewConfigureDualListBox(event) {
        this.group('handleChangeViewConfigureDualListBox');
        if (event.target.value !== undefined) {
            this.objRecordType.recordTypes[this.selectedRecordType].selectedFields = event.target.value;
        }
        this.groupEnd();
    }

    handleActive(event) {
        this.group('handleActive');
        let that = this;
        if (event.currentTarget.dataset.id !== undefined) {
            let recordTypeIndex = event.currentTarget.dataset.id;
            this.log('record type index', recordTypeIndex);
            let allRecordTypes = this.allRecordTypes;
            if (recordTypeIndex === '0') {
                let setActive = !allRecordTypes[recordTypeIndex].active;
                allRecordTypes.forEach(function (recordType) {
                    recordType.active = setActive;
                    that.objRecordType.recordTypes[recordType.value].active = setActive;
                    if (recordType.value !== '0') {
                        recordType.disabled = (recordType.active);
                    }
                });
            } else {
                allRecordTypes[recordTypeIndex].active = !allRecordTypes[recordTypeIndex].active;
                this.objRecordType.recordTypes[allRecordTypes[recordTypeIndex].value].active = allRecordTypes[recordTypeIndex].active;
                let activeCount = 0;
                allRecordTypes.forEach(function (recordType) {
                    if (recordType.active && recordType.value !== '0') {
                        activeCount++;
                    }
                });
                if (activeCount === allRecordTypes.length - 1) {
                    allRecordTypes.forEach(function (recordType) {
                        if (recordType.value !== '0') {
                            recordType.disabled = true;
                        }
                    });
                    allRecordTypes[0].active = true;
                }
            }
            this.allRecordTypes = allRecordTypes;
        }
        event.preventDefault();
        event.stopPropagation();
        this.groupEnd();
    }

    handleCancel() {
        this.group('handleCancel');
        this.closeModal('isShowConfigureColumns');
        this.groupEnd();
    }

    handleSave() {
        this.group('handleSave');
        let spinner = this.showSpinner('main');
        let flag = false;
        for (let key in this.objRecordType.recordTypes) {
            if (this.objRecordType.recordTypes.hasOwnProperty(key)) {
                if (this.objRecordType.recordTypes[key].active) {
                    flag = true;
                    break;
                }
            }
        }
        if (!flag) {
            this.showErrMessage('Please select at least one active Record Type.');
            this.hideSpinner('main', spinner);
            return;
        }
        let that = this;
        let params = {
            objRecordType: JSON.stringify(that.objRecordType.recordTypes)
        };
        saveAllConfigures(params)
            .then(data => {
                that.group('saveConfigures-SUCCESS');
                if (data) {
                    that.showSuccessMessage('Columns settings were saved.');
                    this.dispatchEvent(new CustomEvent('refreshcolumns'));
                } else {
                    that.showErrMessage('Columns settings were not saved.');
                }
                that.hideSpinner('main', spinner);
                that.handleCancel();
                that.hideSpinner('main', spinner);
                that.groupEnd();
            })
            .catch(error => {
                that.group('saveConfigures-ERROR');
                if (error) {
                    let message = 'Unknown error';
                    console.log(error);
                    if (Array.isArray(error.body)) {
                        message = error.body.map(e => e.message).join(', ');
                    } else if (typeof error.body.message === 'string') {
                        message = error.body.message;
                    }
                    that.showErrMessage(message);
                }
                that.hideSpinner('main', spinner);
                that.groupEnd();
            });
        this.groupEnd();
    }

    clickEvent() {
        this.group('clickEvent');
        let element = this['template'].querySelector('div[data-id="comboBoxWithActive"]');
        if (element) {
            element.classList.toggle('slds-is-open');
        }
        this.groupEnd();
    }

    blurEvent() {
        this.group('blurEvent');
        let element = this['template'].querySelector('div[data-id="comboBoxWithActive"]');
        if (element) {
            element.classList.remove('slds-is-open');
        }
        this.groupEnd();
    }

    handleSelectItem(event) {
        this.group('handleSelectItem');
        if (event.currentTarget.dataset.id !== undefined) {
            this.log('record type Id', event.currentTarget.dataset.id);
            let id = event.currentTarget.dataset.id;
            if (id !== '0') {
                this.selectedRecordType = id;
                this.refreshViewConfigure();
            }
        }
        this.groupEnd();
    }

    fetchData() {
        this.group('fetchData');
        let that = this;
        let spinner = this.showSpinner('main');
        let requiredFields = [];
        this.defaultFields.forEach(function (field) {
            requiredFields.push(field.value);
        });
        getSettingsData()
            .then(data => {
                that.group('fetchData-SUCCESS');
                let results = JSON.parse(data);
                that.log('results', results);
                if (!results.hasOwnProperty('allRecordTypes') || !results.hasOwnProperty('savedSettings')) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                let recordTypes = [{
                    label: 'All Libraries',
                    value: '0',
                    active: false
                }];
                recordTypes = recordTypes.concat(results.allRecordTypes);
                that.recordTypes = {};
                recordTypes.forEach(function (recordType) {
                    that.recordTypes[recordType.value] = recordType.label;
                });
                let currentAvailableFields = [];
                that.objRecordType.availableFields = results.availableFields;
                that.objRecordType.availableFields.forEach(function (field) {
                    currentAvailableFields.push(field.value);
                });
                that.requiredFields = requiredFields;
                that.options = that.objRecordType.availableFields;
                let activeCount = 0;
                recordTypes.forEach(function (recordType) {
                    if (recordType['value'] !== '0') {
                        if (results.savedSettings[recordType.value] != null) {
                            let selectedFields = [];
                            results.savedSettings[recordType.value].fields.forEach(function (field) {
                                if (currentAvailableFields.indexOf(field) !== -1) {
                                    selectedFields.push(field);
                                }
                            });
                            that.objRecordType.recordTypes[recordType.value] = {
                                'selectedFields': selectedFields,
                                'active': results.savedSettings[recordType.value].active
                            };
                            recordType['active'] = results.savedSettings[recordType.value].active;
                            recordType['disabled'] = false;
                        } else {
                            that.objRecordType.recordTypes[recordType.value] = {
                                'selectedFields': requiredFields,
                                'active': true
                            };
                            recordType['active'] = true;
                            recordType['disabled'] = false;
                        }
                        if (recordType['active']) {
                            activeCount++;
                        }
                    } else {
                        that.objRecordType.recordTypes[recordType.value] = {};
                    }
                });
                if (activeCount === recordTypes.length - 1) {
                    recordTypes.forEach(function (recordType) {
                        if (recordType.value !== '0') {
                            recordType.disabled = true;
                        }
                    });
                    recordTypes[0].active = true;
                }
                that.allRecordTypes = recordTypes;
                that.log('allRecordTypes', that.allRecordTypes);
                that.log('config', that.objRecordType);
                that.selectedRecordType = recordTypes[1].value;
                that.refreshViewConfigure();
                that.hideSpinner('main', spinner);
                that.groupEnd();
            })
            .catch(error => {
                that.group('fetchData-ERROR');
                if (error) {
                    let message = 'Unknown error';
                    console.log(error);
                    if (Array.isArray(error.body)) {
                        message = error.body.map(e => e.message).join(', ');
                    } else if (typeof error.body.message === 'string') {
                        message = error.body.message;
                    }
                    that.showErrMessage(message);
                }
                that.hideSpinner('main', spinner);
                that.groupEnd();
            });
        this.groupEnd();
    }

    refreshViewConfigure() {
        this.group('refreshViewConfigure');
        this.values = this.objRecordType.recordTypes[this.selectedRecordType].selectedFields;
        this.selectedLibraryName = this.recordTypes[this.selectedRecordType];
        this.groupEnd();
    }

    group(name) {
        if (this.isDebugLog) {
            console.group('%s, time: %f', name, this.timeStamp());
        }
    }

    groupEnd() {
        if (this.isDebugLog) {
            console.groupEnd();
        }
    }

    log(label, values, style) {
        if (this.isDebugLog) {
            style = style || this.logSettings.defaultLogStyle.value;
            if (!values) {
                values = label;
                label = '';
            }
            if (Array.isArray(values)) {
                if (label) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else if (typeof values === 'object') {
                if (label) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else {
                if (label) {
                    console.log('%c' + label + ' - ' + values, style);
                } else {
                    console.log('%c' + values, style);
                }
            }
        }
    }

    showSpinner(attribute, timeStamp, delay, isOneSpinner) {
        this.group('showSpinner');
        let that = this;
        timeStamp = timeStamp || new Date().getTime();
        that.log('attribute: ' + attribute + ', timeStamp: ' + timeStamp);
        delay = delay || 40000; // time for local spinner
        let delayOneSpinner = 40000; // time for one spinner
        isOneSpinner = isOneSpinner || true;
        if (!that.qSpinners.hasOwnProperty(attribute)) {
            that.qSpinners[attribute] = [];
        }
        if (that.qSpinners[attribute].indexOf(timeStamp) === -1) {
            that.qSpinners[attribute].push(timeStamp);
            if (isOneSpinner) {
                if (!that.cmpSpinner.hasOwnProperty(attribute)) {
                    that.cmpSpinner[attribute] = timeStamp;
                    that.spinner[attribute] = true;
                    setTimeout(() => {
                        that.log('getCallback hideSpinner, attribute: ' + attribute);
                        if (that.cmpSpinner.hasOwnProperty(attribute)) {
                            if (that.cmpSpinner[attribute] === timeStamp) {
                                delete that.cmpSpinner[attribute];
                                that.spinner[attribute] = false;
                                that.qSpinners = {};
                            }
                        }
                    }, delayOneSpinner);
                }
            } else {
                setTimeout(() => {
                    that.hideSpinner(attribute, timeStamp);
                }, delay);
                that.spinner[attribute] = true;
            }
        }
        this.groupEnd();
        return timeStamp;
    }

    hideSpinner(attribute, timeStamp) {
        this.group('hideSpinner');
        let that = this;
        that.log('attribute: ' + attribute + ', timeStamp: ' + timeStamp);
        if (that.qSpinners.hasOwnProperty(attribute)) {
            let index = that.qSpinners[attribute].indexOf(timeStamp);
            if (index !== -1) {
                if (that.qSpinners[attribute].length === 1) {
                    if (that.cmpSpinner.hasOwnProperty(attribute)) {
                        delete that.cmpSpinner[attribute];
                    }
                    delete that.qSpinners[attribute];
                    that.spinner[attribute] = false;
                } else {
                    that.qSpinners[attribute].splice(index, 1);
                }
            }
        }
        this.groupEnd();
    }

    trim(str) {
        return str.replace(/^\s+|\s+$/g, '');
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

    showModal(attribute) {
        this.group('showModal');
        this.log('attribute: ' + attribute);
        this.modals[attribute] = true;
        this.groupEnd();
    }

    closeModal(attribute) {
        this.group('closeModal');
        this.log('attribute: ' + attribute);
        if (this.modals.hasOwnProperty(attribute)) {
            this.modals[attribute] = false;
        } else {
            this.showWarningMessage('The attribute \'' + attribute + '\' was not found.');
        }
        this.groupEnd();
    }

    timeStamp() {
        return performance.now() / 1000;
    }

    showErrMessage(message, title) {
        this.group('showErrMessage');
        this.showMessage(title, message, 'error', 20000);
        this.groupEnd();
    }

    showSuccessMessage(message, title) {
        this.group('showSuccessMessage');
        this.showMessage(title, message, 'success');
        this.groupEnd();
    }

    showWarningMessage(message, title) {
        this.group('showWarningMessage');
        this.showMessage(title, message, 'warning');
        this.groupEnd();
    }

    showMessage(title, message, type, mode) {
        this.group('showMessage');
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
        this.groupEnd();
    }
}