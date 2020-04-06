import {LightningElement, api, track} from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import getIndicatorCatalogsData from '@salesforce/apex/IndicatorCatalogsController.getIndicatorCatalogsData';

export default class LwcIndicatorCatalogs extends LightningElement {
    @api isDebugLog = false;
    @api recordId;
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
            value: 'background: blue; color: white;'
        }
    };
    @track columns = [];
    @track indicators = [];
    original = [];
    @track originalJSON = '';
    @track originalReplaceJSON = '';
    privateIsDisplayFilters;
    @track privateSearchValue;
    privateRecoveryIndicatorId;
    isGetIndicatorCatalogs = false;
    @track privateIsRefreshCatalogFilters;
    privateReloadCatalogIndicators;

    connectedCallback() {
        this.group('connectedCallback');
        this.log('initialization');
        this.columns = [
            {label: 'Indicator Name', fieldName: 'sfims__Indicator_Name__c', type: 'url'},
            {label: 'Indicator Type', fieldName: 'sfims__Indicator_Type__c', type: 'text'},
            {label: 'Library', fieldName: 'RecordTypeId', type: 'text'},
            {label: 'Definition', fieldName: 'sfims__Definition__c', type: 'text'},
            {label: 'Outcome Area', fieldName: 'sfims__Outcome_Area__c', type: 'text'},
        ];
        this.groupEnd();
    }

    @api get reloadCatalogIndicators() {
        return this.privateReloadCatalogIndicators;
    }

    set reloadCatalogIndicators(value) {
        this.group('set isDisplayFilters');
        this.privateReloadCatalogIndicators = value;
        if (value !== undefined) {
            this.getIndicatorCatalogs();
        }
        this.groupEnd();
    }

    @api get isDisplayFilters() {
        return this.privateIsDisplayFilters;
    }

    set isDisplayFilters(value) {
        this.group('set isDisplayFilters');
        this.privateIsDisplayFilters = !value;
        let filters = this['template'].querySelector('span[data-id="moreFilters"]');
        if (filters) {
            if (this.privateIsDisplayFilters) {
                filters.style.display = 'block';
            } else {
                filters.style.display = 'none';
            }
        }
        this.groupEnd();
    }

    @api get recoveryIndicatorId() {
        return this.privateRecoveryIndicatorId;
    }

    set recoveryIndicatorId(value) {
        this.group('set recoveryIndicatorId');
        if (value !== undefined) {
            this.privateRecoveryIndicatorId = value;
            this.dispatchEvent(new CustomEvent('clearrecoveryindicatorid'));
            let that = this;
            setTimeout(() => {
                let originalIndex = that.original.findIndex(function (row) {
                    return row.Id === value
                });
                if (originalIndex === -1) {
                    // that.showErrMessage('Indicator was not received.');
                    return;
                }
                that.original[originalIndex].display = true;
                let response = {
                    original: that.original,
                    filter: true
                };
                that.originalJSON = JSON.stringify(response);
            }, 0);
        }
        this.groupEnd();
    }

    @api get isRefreshCatalogFilters() {
        return this.privateIsRefreshCatalogFilters;
    }

    set isRefreshCatalogFilters(value) {
        this.group('set isRefreshCatalogFilters');
        if (value !== undefined) {
            this.privateIsRefreshCatalogFilters = value;
        }
        this.groupEnd();
    }

    @api get searchValue() {
        return this.privateSelectedLibraries;
    }

    set searchValue(value) {
        this.group('set searchValue');
        if (value !== undefined) {
            this.privateSearchValue = value;
        }
        this.groupEnd();
    }

    privateSelectedIndicatorsList;

    @api get selectedIndicatorsList() {
        return this.privateSelectedIndicatorsList;
    }

    set selectedIndicatorsList(value) {
        this.group('set selectedIndicatorsList');
        if (value !== undefined) {
            this.privateSelectedIndicatorsList = value;
        }
        this.groupEnd();
    }

    @track privateSelectedLibraries;

    @api get selectedLibraries() {
        return this.privateSelectedLibraries;
    }

    set selectedLibraries(value) {
        this.group('set selectedLibraries');
        this.privateSelectedLibraries = value;
        if (value.length) {
            this.getIndicatorCatalogs();
        } else {
            let that = this;
            let spinner = this.showSpinner('main');
            setTimeout(() => {
                this.indicators = [];
                this.original = [];
                let response = {
                    original: [],
                    filter: true
                };
                this.originalJSON = JSON.stringify(response);
                that.hideSpinner('main', spinner);
            }, 0);
        }
        this.groupEnd();
    }

    getIndicatorCatalogs() {
        this.group('getIndicatorCatalogs');
        let that = this;
        let spinner = this.showSpinner('main');
        let params = {
            selectedRecordTypes: this.selectedLibraries,
            recordId: this.recordId
        };
        getIndicatorCatalogsData(params)
            .then(data => {
                that.group('getIndicatorCatalogs-SUCCESS');
                if (!data) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                let values = JSON.parse(data);
                that.log('getIndicatorCatalogsData', values);
                if (!values.hasOwnProperty('allIndicators')) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                if (!values.hasOwnProperty('allFields') || !values.allFields) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                if (!values.hasOwnProperty('availableFields') || !values.availableFields) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                if (!values.hasOwnProperty('allRecordTypes') || !values.allRecordTypes) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                /*
                let savedIds = [];
                if (values.hasOwnProperty('savedIds') && values['savedIds']) {
                    savedIds = values['savedIds'];
                }
                that.log('savedIds', savedIds);
                */
                that.log('selected indicators', that.privateSelectedIndicatorsList);
                let savedIds = [];
                if (that.privateSelectedIndicatorsList) {
                    that.privateSelectedIndicatorsList.forEach(function (item) {
                        savedIds.push(item['Id']);
                    });
                }
                that.log('savedIds', savedIds);
                let newColumns = [];
                values.allFields.forEach(function (field) {
                    values.availableFields.forEach(function (availableField) {
                        if (availableField.value === field) {
                            newColumns.push({
                                'label': availableField.label,
                                'fieldName': field,
                                'type': 'text'
                            })
                        }

                    });
                });
                that.log('new columns', newColumns);
                that.columns = newColumns;
                let columnSize = newColumns.length;
                let size = values.allIndicators.length;
                let recordTypes = {};
                values.allRecordTypes.forEach(function (item) {
                    recordTypes[item.value] = item.label;
                });
                for (let i = 0; i < size; i++) {
                    delete values.allIndicators[i].attributes;
                    delete values.allIndicators[i].RecordType;
                    let rowValues = [];
                    for (let c = 0; c < columnSize; c++) {
                        let url = values.allIndicators[i][newColumns[c].fieldName];
                        let isTextType = true;
                        if (values.allIndicators[i].hasOwnProperty(newColumns[c].fieldName)) {
                            switch (newColumns[c].fieldName) {
                                case 'sfims__Indicator_Name__c':
                                    isTextType = false;
                                    url = '/' + values.allIndicators[i].Id;
                                    break;
                                case 'RecordTypeId':
                                    if (recordTypes[values.allIndicators[i].RecordTypeId]) {
                                        values.allIndicators[i][newColumns[c].fieldName] = recordTypes[values.allIndicators[i].RecordTypeId];
                                    }
                                    break;
                                default:

                            }
                            rowValues.push({
                                Id: values.allIndicators[i].Id + c,
                                isTextType: isTextType,
                                url: url,
                                value: values.allIndicators[i][newColumns[c].fieldName]
                            })
                        } else {
                            rowValues.push({
                                id: values.allIndicators[i].Id + c,
                                isTextType: isTextType,
                                url: url,
                                value: ''
                            })
                        }
                    }
                    values.allIndicators[i].values = rowValues;
                    values.allIndicators[i].display = (savedIds.indexOf(values.allIndicators[i].Id) === -1);
                    // values.allIndicators[i].display = true;
                }
                let response = {
                    original: values.allIndicators,
                    filter: true
                };
                that.originalJSON = JSON.stringify(response);
                that.original = values.allIndicators;
                that.isGetIndicatorCatalogs = true;
                that.log('indicators', values.allIndicators);
                that.hideSpinner('main', spinner);
                that.groupEnd();
            })
            .catch(error => {
                that.group('getIndicatorCatalogs-ERROR');
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

    handleEventListIndicatorsFromFilter(event) {
        this.group('handleEventListIndicatorsFromFilter');
        if (event.detail) {
            this.indicators = JSON.parse(event.detail);
        }
        this.groupEnd();
    }

    handleEventFiltersLoaded(event) {
        this.group('handleEventFiltersLoaded');
        this.dispatchEvent(new CustomEvent('filtersloaded', {detail: event.detail}));
        this.groupEnd();
    }

    handleAddSelected(event) {
        this.group('handleAddSelected');
        let that = this;
        // let rows = JSON.parse(JSON.stringify(this.indicators));
        // let originalRows = JSON.parse(JSON.stringify(this.original));
        let index = event.target.value;
        this.log('index', index);
        if (index !== undefined && index !== null) {
            this.indicators[index].display = false;
            let convertRow = this.indicators[index];
            // let convertRow = JSON.parse(JSON.stringify(this.indicators[index]));
            convertRow.values = [
                {
                    id: convertRow['Id'] + '_sfims__Indicator_Name__c',
                    value: convertRow['sfims__Indicator_Name__c'],
                    isUrl: true,
                    typeAttributes: {
                        url: '/' + convertRow.Id
                    }
                },
                {
                    id: convertRow['Id'] + '_sfims__Indicator_Type__c',
                    value: convertRow['sfims__Indicator_Type__c'],
                    isText: true
                },
                {
                    id: convertRow['Id'] + '_RecordTypeId',
                    value: convertRow['RecordTypeId'],
                    isText: true
                },
                {
                    id: convertRow['Id'] + '_sfims__Standard_Custom__c',
                    value: convertRow['sfims__Standard_Custom__c'],
                    isText: true
                },
                {
                    id: convertRow['Id'] + '_sfims__Definition__c',
                    value: convertRow['sfims__Definition__c'],
                    isText: true
                },
                {
                    id: convertRow['Id'] + '_sfims__Outcome_Area__c',
                    value: convertRow['sfims__Outcome_Area__c'],
                    isText: true
                }
            ];
            this.dispatchEvent(new CustomEvent('addindicator', {detail: JSON.stringify(convertRow)}));
            setTimeout(() => {
                let originalIndex = that.original.findIndex(function (row) {
                    return row.Id === that.indicators[index].Id
                });
                if (originalIndex === -1) {
                    that.log('id', that.indicators[index].Id);
                    that.log('original catalogs', that.original);
                    that.showErrMessage('Indicator was not received in the original indicator catalogs.');
                    return;
                }
                that.original[originalIndex].display = false;
                let response = {
                    original: that.original,
                    filter: false
                };
                that.originalJSON = JSON.stringify(response);
            }, 0);
        }
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
        this.modals[attribute] = true;
    }

    closeModal(attribute) {
        if (this.modals.hasOwnProperty(attribute)) {
            this.modals[attribute] = false;
        } else {
            this.showWarningMessage('The attribute \'' + attribute + '\' was not found.');
        }
    }

    timeStamp() {
        return performance.now() / 1000;
    }

    showErrMessage(message, title) {
        this.showMessage(title, message, 'error', 20000);
    }

    showSuccessMessage(message, title) {
        this.showMessage(title, message, 'success');
    }

    showWarningMessage(message, title) {
        this.showMessage(title, message, 'warning');
    }

    showMessage(title, message, type, mode) {
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