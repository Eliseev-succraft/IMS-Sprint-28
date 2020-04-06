import {LightningElement, api, track} from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import loadSelectedIndicators from '@salesforce/apex/SelectedIndicatorsController.loadSelectedIndicators';

export default class LwcSelectedIndicators extends LightningElement {
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
            value: 'background: black; color: white;'
        }
    };
    @api recordId;
    @track columns;
    @track indicators = [];
    original = [];
    @track originalJSON = '';
    dragAndDropStartIndex;
    privateLowMode;
    privateAddIndicatorFromIndicatorCatalogs;
    privateIsDisplayFilters;
    @track privateSearchValue = '';

    @api get lowMode() {
        return this.privateLowMode;
    }

    set lowMode(value) {
        this.group('set lowMode');
        if (value !== undefined) {
            this.privateLowMode = value;
            let low = this['template'].querySelector('div[data-id="lowResults"]');
            let high = this['template'].querySelector('div[data-id="highResults"]');
            if (low && high) {
                if (!this.privateLowMode) {
                    low.style.display = 'none';
                    high.style.display = 'block';
                } else {
                    high.style.display = 'none';
                    low.style.display = 'block';
                }
            } else {
                this.showErrMessage('The required parameter was not received.');
            }
        }
        this.groupEnd();
    }

    connectedCallback() {
        this.group('connectedCallback');
        this.log('initialization');
        this.columns = [
            {label: 'Indicator Name', fieldName: 'sfims__Indicator_Name__c', type: 'url'},
            {label: 'Indicator Type', fieldName: 'sfims__Indicator_Type__c', type: 'text'},
            {label: 'Library', fieldName: 'RecordTypeId', type: 'text'},
            {label: 'Standard - Custom', fieldName: 'sfims__Standard_Custom__c', type: 'text'},
            {label: 'Definition', fieldName: 'sfims__Definition__c', type: 'text'},
            {label: 'Outcome Area', fieldName: 'sfims__Outcome_Area__c', type: 'text'},
        ];
        if (this.recordId) {
            this.fetchData();
        }
        this.groupEnd();
    }

    renderedCallback() {
        this.group('renderedCallback');
        if (this.recordId) {
         //   this.lowMode = false;
        }
        this.groupEnd();
    }

    @api get searchValue() {
        return this.privateSearchValue;
    }

    set searchValue(value) {
        this.group('searchValue');
        if (value !== undefined) {
            this.privateSearchValue = value;
        }
        this.groupEnd();
    }

    @api get isDisplayFilters() {
        return this.privateIsDisplayFilters;
    }

    set isDisplayFilters(value) {
        let that = this;
        that.privateIsDisplayFilters = !value;
        let filters = that['template'].querySelector('span[data-id="moreFilters"]');
        if (filters) {
            if (that.privateIsDisplayFilters) {
                that['template'].querySelector('span[data-id="moreFilters"]').style.display = 'block';
            } else {
                that['template'].querySelector('span[data-id="moreFilters"]').style.display = 'none';
            }
        }
    }

    @api get addIndicatorFromIndicatorCatalogs() {
        return this.privateAddIndicatorFromIndicatorCatalogs;
    }

    set addIndicatorFromIndicatorCatalogs(value) {
        this.group('set addIndicatorFromIndicatorCatalogs');
        if (value) {
            // this.privateAddIndicatorFromIndicatorCatalogs = JSON.parse(value);
            // this.privateAddIndicatorFromIndicatorCatalogs['index'] = this.original.length + 1;
            this.original.push(JSON.parse(value));
            this.originalJSON = JSON.stringify(this.original);
            this.dispatchEvent(new CustomEvent('checkactivetab'));
            this.dispatchEvent(new CustomEvent('updatelistselectedindicators', {detail: this.originalJSON}));
        }
        this.groupEnd();
    }

    fetchData() {
        this.group('fetchData');
        let that = this;
        if (!this.recordId) {
            that.showErrMessage('The required parameter was not received.');
            return;
        }
        let spinner = this.showSpinner('main');
        let params = {
            templateId: this.recordId
        };
        loadSelectedIndicators(params)
            .then(data => {
                that.group('fetchData-SUCCESS');
                if (!data) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                let results = JSON.parse(data);
                that.log('results', results);
                if (!results.hasOwnProperty('allIndicators')) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                if (!results.hasOwnProperty('allRecordTypes') || !results['allRecordTypes']) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                let columnsSize = that.columns.length;
                let indicatorSize = results.allIndicators.length;
                let recordTypes = {};
                results.allRecordTypes.forEach(function (item) {
                    recordTypes[item.value] = item.label;
                });
                for (let i = 0; i < indicatorSize; i++) {
                    delete results.allIndicators[i]['attributes'];
                    delete results.allIndicators[i]['RecordType'];
                    let rowValues = [];
                    for (let c = 0; c < columnsSize; c++) {
                        let fieldValue = {
                            id: results.allIndicators[i]['Id'] + '_' + that.columns[c].fieldName,
                            value: '',
                            isText: true
                        };
                        if (results.allIndicators[i].hasOwnProperty(that.columns[c].fieldName)) {
                            fieldValue['value'] = results.allIndicators[i][that.columns[c].fieldName];
                            if (that.columns[c].fieldName === 'sfims__Indicator_Name__c') {
                                fieldValue['isUrl'] = true;
                                fieldValue['isText'] = false;
                                fieldValue['typeAttributes'] = {
                                    url: '/' + results.allIndicators[i]['Id']
                                };
                            } else if (that.columns[c].fieldName === 'RecordTypeId') {
                                results.allIndicators[i][that.columns[c].fieldName] = recordTypes[results.allIndicators[i]['RecordTypeId']];
                                fieldValue['value'] = results.allIndicators[i][that.columns[c].fieldName];
                            }
                        }
                        rowValues.push(fieldValue);
                    }
                    results.allIndicators[i]['values'] = rowValues;
                }
                that.log('indicators', results.allIndicators);
                that.originalJSON = JSON.stringify(results.allIndicators);
                that.original = JSON.parse(that.originalJSON);
                that.dispatchEvent(new CustomEvent('updatelistselectedindicators', {detail: that.originalJSON}));
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

    handleEventFiltersLoaded(event) {
        this.group('handleEventFiltersLoaded');
        this.dispatchEvent(new CustomEvent('filtersloaded', {detail: event.detail}));
        this.groupEnd();
    }

    handleEventListIndicatorsFromFilter(event) {
        this.group('handleEventListIndicatorsFromFilter');
        if (event.detail) {
            this.indicators = JSON.parse(event.detail);
        }
        this.groupEnd();
    }

    handleDeleteIndicator(event) {
        this.group('handleDeleteIndicator');
        let index = event.target.value;
        this.log('index', index);
        if (index !== undefined) {
            let indicators = this.indicators;
            if (!indicators[index]) {
                this.showErrMessage('Indicator was not received in the list of selected indicators.');
                return;
            }
            this.dispatchEvent(new CustomEvent('recoveryindicator', {detail: indicators[index].Id}));
            let originalIndex = this.original.findIndex(function (row) {
                return row.Id === indicators[index].Id
            });
            if (originalIndex !== -1) {
                this.original.splice(originalIndex, 1);
            } else {
                this.log('indicators', this.original);
                this.showErrMessage('Delete indicator was failed.')
            }
            this.originalJSON = JSON.stringify(this.original);
            this.dispatchEvent(new CustomEvent('updatelistselectedindicators', {detail: this.originalJSON}));
        }
        this.groupEnd();
    }

    handleDragStart(event) {
        this.group('handleDragStart');
        if (event.target.className) {
            this.dragAndDropStartIndex = event.target.className;
        } else {
            this.handleDrag = null;
        }
        this.groupEnd();
    }

    handleDragOver(event) {
        event.preventDefault();
    }

    handleDrop(event) {
        this.group('handleDrop');
        let that = this;
        let oldIndex = this.dragAndDropStartIndex;
        let newIndex = event.target.closest('tr[class]').className;
        this.log('oldIndex', oldIndex);
        this.log('newIndex', newIndex);
        if (oldIndex != null && newIndex != null) {
            if (this.indicators[newIndex] != null && this.indicators[oldIndex] != null) {
                let item = this.indicators[newIndex];
                // let itemOrderNumber = this.indicators[newIndex].index;
                // this.indicators[newIndex].index = this.indicators[oldIndex].index;
                // this.indicators[oldIndex].index = itemOrderNumber;
                this.indicators.splice(newIndex, 1, this.indicators[oldIndex]);
                this.indicators.splice(oldIndex, 1, item);
                setTimeout(() => {
                    let originalIndexNew = that.original.findIndex(function (row) {
                        return row.Id === that.indicators[newIndex].Id
                    });
                    let originalIndexOld = that.original.findIndex(function (row) {
                        return row.Id === that.indicators[oldIndex].Id
                    });
                    if (originalIndexNew !== -1 && originalIndexOld !== -1) {
                        let item = that.original[originalIndexNew];
                        that.original.splice(originalIndexNew, 1, that.original[originalIndexOld]);
                        that.original.splice(originalIndexOld, 1, item);
                        this.originalJSON = JSON.stringify(this.original);
                        this.dispatchEvent(new CustomEvent('updatelistselectedindicators', {detail: this.originalJSON}));
                    } else {
                        that.showErrMessage('Reorder was failed.')
                    }
                }, 0);
            }
        }
        event.preventDefault();
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