import {LightningElement, api, track} from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import getSelectedIndicatorsFiltersPicklistData
    from '@salesforce/apex/moreFiltersController.getSelectedIndicatorsFiltersPicklistData';

export default class lwcSelectedIndicatorsFilters extends LightningElement {
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
            value: 'background: yellow; color: black;'
        }
    };
    activeSections = [
        'Indicator_Type',
        'Record_Type',
        'Standard_Custom',
        'Outcome_Area'
    ];
    @track optionsCheckboxGroup = {
        sfims__Indicator_Type__c: [],
        RecordTypeId: [],
        sfims__Standard_Custom__c: [],
        sfims__Outcome_Area__c: []
    };
    checkboxGroupValues = {
        sfims__Indicator_Type__c: [],
        RecordTypeId: [],
        sfims__Standard_Custom__c: [],
        sfims__Outcome_Area__c: []
    };
    privateIndicators = [];

    privateSearchValue = '';

    @api get searchValue() {
        return this.privateSearchValue;
    }

    set searchValue(value) {
        this.group('set searchValue');
        if (value !== undefined) {
            this.privateSearchValue = value;
            this.refreshView();
        }
        this.groupEnd();
    }

    @api get indicators() {
        return this.privateIndicators;
    }

    set indicators(value) {
        this.group('set indicators');
        if (value) {
            this.privateIndicators = JSON.parse(value);
            this.log('indicators', this.privateIndicators);
            if (Array.isArray(this.privateIndicators)) {
                this.refreshView();
            }
        }
        this.groupEnd();
    }

    connectedCallback() {
        this.group('connectedCallback');
        this.log('initialization');
        this.fetchData();
        this.groupEnd();
    }

    handleChangeFilter(event) {
        this.group('handleChangeFilter');
        let that = this;
        let name = event.target.name;
        that.log('name', name);
        let value = event.target.value;
        that.log('value', value);
        that.checkboxGroupValues[name] = value;
        let spinner = that.showSpinner('refresh');
        setTimeout(() => {
            that.refreshView();
            that.hideSpinner('refresh', spinner);
        }, 0);
        this.groupEnd();
    }

    fetchData() {
        this.group('fetchData');
        let that = this;
        let spinner = this.showSpinner('main');
        getSelectedIndicatorsFiltersPicklistData()
            .then(data => {
                that.group('fetchData-SUCCESS');
                that.optionsCheckboxGroup = JSON.parse(data);
                that.log('getSelectedIndicatorsFiltersPicklistData', that.optionsCheckboxGroup);
                that.dispatchEvent(new CustomEvent('filtersloaded'));
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

    refreshView() {
        this.group('refreshView');
        let that = this;
        let checkboxGroupValues = that.checkboxGroupValues;
        let indicators = that.indicators;
        let size = indicators.length;
        let newList = [];
        if (size > 0) {
            let pickListFields = [];
            let optionsCheckboxGroup = that.optionsCheckboxGroup;
            for (let key in optionsCheckboxGroup) {
                if (optionsCheckboxGroup.hasOwnProperty(key)) {
                    pickListFields.push(key);
                }
            }
            let pickListFieldsSize = pickListFields.length;
            // search check
            let isSearch = false;
            let searchValue = that.searchValue;
            if (searchValue && searchValue.length > 0) {
                isSearch = true;
                searchValue = searchValue.toLowerCase();
            }
            // loop by original data for new data to display
            for (let i = 0; i < size; i++) {
                let isContinue = false;
                // if the text fields does not contain search value go to the next iteration
                if (isSearch) {
                    let strToLowerCase = indicators[i]['sfims__Indicator_Name__c'].toLowerCase();
                    if (strToLowerCase.indexOf(searchValue) === -1) {
                        continue;
                    }
                }
                // if the pickList fields does not contain selected options go to the next iteration
                if (!isContinue) {
                    for (let j = 0; j < pickListFieldsSize; j++) {
                        let cmpVal = checkboxGroupValues[pickListFields[j]];
                        if (cmpVal.length > 0) {
                            if (cmpVal.indexOf(indicators[i][pickListFields[j]]) === -1) {
                                isContinue = true;
                                break;
                            }
                        }
                    }
                }
                // flag go to the next iteration
                if (isContinue) {
                    continue;
                }
                // if the row matches the filter list - add it to the new list for display
                newList.push(indicators[i]);
            }
        }
        that.dispatchEvent(new CustomEvent('filteredlist', {detail: JSON.stringify(newList)}));
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
        delay = delay || 20000; // time for local spinner
        let delayOneSpinner = 20000; // time for one spinner
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