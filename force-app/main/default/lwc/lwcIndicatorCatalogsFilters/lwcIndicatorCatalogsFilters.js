import {LightningElement, api, track, wire} from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import getIndicatorCatalogsFiltersPicklistData
    from '@salesforce/apex/moreFiltersController.getIndicatorCatalogsFiltersPicklistData';
import {getObjectInfo, getPicklistValuesByRecordType} from 'lightning/uiObjectInfoApi';
import Indicator_Catalogue__c from '@salesforce/schema/Indicator_Catalogue__c';

export default class LwcIndicatorCatalogsFilters extends LightningElement {
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
    recordTypes = [];
    iterationRecordTypeIndex = 0;
    iterationRecordTypeId;
    picklistValuesByRecordTypes = {};
    privateSearchValue;
    allCheckboxGroup;
    isFetchData = false;
    privateIndicators = [];
    privateSelectedLibraries;
    privateIsRefreshCatalogFilters;
    @track activeSections = [];
    @track optionsCheckboxGroup = [];

    connectedCallback() {
        this.group('connectedCallback');
        this.log('initialization');
        this.groupEnd();
    }

    @api get isRefreshCatalogFilters() {
        return this.privateIsRefreshCatalogFilters;
    }

    set isRefreshCatalogFilters(value) {
        this.group('set isRefreshCatalogFilters');
        if (value !== undefined) {
            this.privateIsRefreshCatalogFilters = value;
            this.fetchData();
        }
        this.groupEnd();
    }

    @wire(getObjectInfo, {objectApiName: Indicator_Catalogue__c})
    getRecordTypes({error, data}) {
        this.group('getRecordTypes');
        let that = this;
        if (error) {
            that.group('getRecordTypes-ERROR');
            let message = 'Unknown error';
            if (Array.isArray(error.body)) {
                message = error.body.map(e => e.message).join(', ');
            } else if (typeof error.body.message === 'string') {
                message = error.body.message;
            }
            that.showErrMessage(message);
            that.groupEnd();
        } else if (data) {
            that.group('getRecordTypes-SUCCESS');
            that.log('record types', data);
            if (!data.hasOwnProperty('recordTypeInfos')) {
                that.showErrMessage('Record Type Info was not received.');
                return;
            }
            for (let key in data['recordTypeInfos']) {
                if (data['recordTypeInfos'].hasOwnProperty(key)) {
                    if (data['recordTypeInfos'][key]['available'] && !data['recordTypeInfos'][key]['master']) {
                        that.recordTypes.push(data['recordTypeInfos'][key].recordTypeId);
                    }
                }
            }
            that.iterationRecordTypeId = that.recordTypes[that.iterationRecordTypeIndex];
            that.log('list of record types', that.recordTypes);
            that.groupEnd();
        }
        this.groupEnd()
    }

    @wire(getPicklistValuesByRecordType, {
        objectApiName: Indicator_Catalogue__c,
        recordTypeId: '$iterationRecordTypeId'
    })
    picklistValuesByRecordType({error, data}) {
        this.group('picklistValuesByRecordType');
        let that = this;
        if (error) {
            that.group('picklistValuesByRecordType-ERROR');
            let message = 'Unknown error';
            if (Array.isArray(error.body)) {
                message = error.body.map(e => e.message).join(', ');
            } else if (typeof error.body.message === 'string') {
                message = error.body.message;
            }
            that.showErrMessage(message);
            that.groupEnd();
        } else if (data) {
            that.group('picklistValuesByRecordType-SUCCESS');
            that.log(that.iterationRecordTypeId, data);
            that.picklistValuesByRecordTypes[that.iterationRecordTypeId] = data;
            if (that.iterationRecordTypeIndex < that.recordTypes.length - 1) {
                that.iterationRecordTypeIndex++;
                that.iterationRecordTypeId = that.recordTypes[that.iterationRecordTypeIndex];
            } else { // pick list values are loaded
                that.fetchData();
            }
            that.groupEnd();
        }
        this.groupEnd()
    }

    fetchData() {
        this.group('fetchData');
        let that = this;
        let spinner = this.showSpinner('main');
        getIndicatorCatalogsFiltersPicklistData()
            .then(data => {
                that.group('fetchData-SUCCESS');
                let optionsCheckboxGroup = JSON.parse(data);
                that.log('getIndicatorCatalogsFiltersPicklistData', optionsCheckboxGroup);
                that.allCheckboxGroup = optionsCheckboxGroup;
                that.isFetchData = true;
                that.generateOptions();
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

    generateOptions() {
        this.group('generateOptions');
        let oldValues = this.optionsCheckboxGroup;
        let selectedLibraries = this.privateSelectedLibraries;
        if (!selectedLibraries.length) {
            selectedLibraries = Object.keys(this.allCheckboxGroup);
        }
        this.log('selected libraries', selectedLibraries);
        let optionsCheckboxGroup = this.allCheckboxGroup;
        this.log('options checkbox group', optionsCheckboxGroup);
        let picklistValuesByRecordType = this.picklistValuesByRecordTypes;
        this.log('picklist values by record type', picklistValuesByRecordType);
        let checkboxGroup = {};
        let size = selectedLibraries.length;
        for (let l = 0; l < size; l++) {
            let recordTypeId = selectedLibraries[l];
            if (recordTypeId !== '0') {
                if (optionsCheckboxGroup.hasOwnProperty(recordTypeId)) {
                    optionsCheckboxGroup[recordTypeId].forEach(function (field) {
                        if (picklistValuesByRecordType[recordTypeId]['picklistFieldValues']) {
                            if (picklistValuesByRecordType[recordTypeId]['picklistFieldValues'][field['fieldName']]) {
                                let valuesSize = picklistValuesByRecordType[recordTypeId]['picklistFieldValues'][field['fieldName']]['values'].length;
                                let items = [];
                                for (let h = 0; h < valuesSize; h++) {
                                    let value = picklistValuesByRecordType[recordTypeId]['picklistFieldValues'][field['fieldName']]['values'][h]['value'];
                                    if (checkboxGroup[field['fieldName']]) {
                                        if (checkboxGroup[field['fieldName']].indexOf(value) === -1) {
                                            items.push(value);
                                        }
                                    } else {
                                        items.push(value);
                                    }
                                }
                                let itemsSize = items.length;
                                if (itemsSize > 0) {
                                    if (!checkboxGroup[field['fieldName']]) {
                                        checkboxGroup[field['fieldName']] = items;

                                    } else {
                                        checkboxGroup[field['fieldName']] = checkboxGroup[field['fieldName']].concat(items);
                                    }
                                }
                            }
                        }

                    });
                }
            }
        }
        this.log('checkbox group', checkboxGroup);
        let newOptionsCheckBoxGroup = [];
        let newOptionsCheckBoxGroup2 = [];
        for (let l = 0; l < size; l++) {
            let recordTypeId = selectedLibraries[l];
            if (recordTypeId !== '0') {
                if (optionsCheckboxGroup.hasOwnProperty(recordTypeId)) {
                    optionsCheckboxGroup[recordTypeId].forEach(function (option) {
                        if (checkboxGroup.hasOwnProperty(option.fieldName)) {
                            let newItems = [];
                            checkboxGroup[option.fieldName].forEach(function (item) {
                                newItems.push({
                                    value: item,
                                    label: item
                                })
                            });
                            if (newItems.length > 0) option['checkboxGroup'] = newItems;
                        }
                        if (newOptionsCheckBoxGroup2.indexOf(option.fieldName) === -1) {
                            newOptionsCheckBoxGroup.push(option);
                            newOptionsCheckBoxGroup2.push(option.fieldName);
                        }
                    });
                }
            }
        }
        oldValues.forEach(function (item) {
            newOptionsCheckBoxGroup.forEach(function (group) {
                if (item['fieldName'] === group['fieldName']) {
                    group['fieldValue'] = item['fieldValue'];
                }
            });
        });
        this.log('newOptionsCheckBoxGroup', newOptionsCheckBoxGroup);
        this.optionsCheckboxGroup = newOptionsCheckBoxGroup;
        let activeSections = [];
        newOptionsCheckBoxGroup.forEach(function (item) {
            activeSections.push(item.fieldName);
        });
        this.log('active sections', activeSections);
        let that = this;
        setTimeout(() => {
            that.activeSections = activeSections;
        }, 0);
        this.dispatchEvent(new CustomEvent('filtersloaded'));
        this.groupEnd();
    }

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

    @api get replaceIndicators() {
        return this.privateIndicators;
    }

    set replaceIndicators(value) {
        this.group('set replaceIndicators');
        if (value) {
            this.privateIndicators = JSON.parse(value);
        }
        this.groupEnd();
    }

    @api get indicators() {
        return this.privateIndicators;
    }

    set indicators(value) {
        this.group('set indicators');
        if (value) {
            let request = JSON.parse(value);
            this.privateIndicators = request['original'];
            this.log('indicators', this.privateIndicators);
            if (request['filter']) {
                if (Array.isArray(this.privateIndicators)) {
                    this.refreshView();
                }
            }
        }
        this.groupEnd();
    }

    @api get selectedLibraries() {
        return this.privateSelectedLibraries;
    }

    set selectedLibraries(value) {
        this.group('set selectedLibraries');
        let that = this;
        that.privateSelectedLibraries = value;
        if (this.isFetchData) {
            this.generateOptions();
        }
        this.groupEnd();
    }

    handleChangeFilter(event) {
        this.group('handleChangeFilter');
        let that = this;
        let index = event.target.dataset.index;
        that.log('index', index);
        let name = event.target.name;
        that.log('name', name);
        let value = event.target.value;
        that.log('value', value);
        that.optionsCheckboxGroup[index].fieldValue = value;
        let spinner = this.showSpinner('refresh');
        setTimeout(() => {
            that.refreshView();
            that.hideSpinner('refresh', spinner);
        }, 0);
        this.groupEnd();
    }

    refreshView() {
        this.group('refreshView');
        let that = this;
        let data = that.indicators;
        let size = data.length;
        if (size > 0) {
            let pickListFields = [];
            let optionsCheckboxGroup = that.optionsCheckboxGroup;
            that.log('optionsCheckboxGroup', optionsCheckboxGroup);
            optionsCheckboxGroup.forEach(function (item) {
                if (item.fieldValue.length > 0) {
                    pickListFields.push({
                        fieldName: item.fieldName,
                        fieldValue: item.fieldValue
                    })
                }
            });
            let pickListFieldsSize = pickListFields.length;
            // search check
            let isSearch = false;
            let searchValue = that.searchValue;
            // let searchValue = this.trim(cmp.get('v.searchValue'), cmp);
            if (searchValue && searchValue.length > 0) {
                isSearch = true;
                searchValue = searchValue.toLowerCase();
            }
            let newData = [];
            // loop by original data for new data to display
            for (let i = 0; i < size; i++) {
                if (!data[i]['display']) {
                    continue;
                }
                // if the text fields does not contain search value go to the next iteration
                if (isSearch) {
                    let strToLowerCase = data[i]['sfims__Indicator_Name__c'].toLowerCase();
                    if (strToLowerCase.indexOf(searchValue) === -1) {
                        continue;
                    }
                }
                // if the pickList fields does not contain selected options go to the next iteration
                let filter = true;
                if (pickListFieldsSize > 0) {
                    for (let j = 0; j < pickListFieldsSize; j++) {
                        if (pickListFields[j]['fieldValue'].indexOf(data[i][pickListFields[j]['fieldName']]) === -1) {
                            filter = false;
                            break;
                        }
                    }
                }
                if (filter) {
                    newData.push(data[i]);
                }
            }
            that.dispatchEvent(new CustomEvent('filteredlist', {detail: JSON.stringify(newData)}));
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