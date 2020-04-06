import {LightningElement, api, track, wire} from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import {NavigationMixin} from 'lightning/navigation';
import getLibraries from '@salesforce/apex/ReportTemplateController.getLibraries';
import saveReportTemplateIndicators from '@salesforce/apex/ReportTemplateController.saveReportTemplateIndicators';
import getLayoutFields from '@salesforce/apex/ReportTemplateController.getLayoutFields';

export default class LwcReportTemplate extends NavigationMixin(LightningElement) {
    @api recordId;
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
    selectedTabName;
    isFirstCallRenderedCallback = true;
    formInformation = {};
    @track customRecordTypeId;
    @track selectedIndicatorsList = [];
    @track recoveryIndicatorId;
    @track setActiveFieldValue;
    @track templateName = 'New Template';
    @track lowMode;
    @track libraries = [];
    @track selectedLibraries = [];
    @track isMoreFiltersByIndicatorCatalogs = true;
    @track isMoreFiltersByIndicatorCatalogsDisabled = true;
    @track searchValueBySelectedIndicators;
    @track searchValueByIndicatorCatalogs;
    @track isMoreFiltersBySelectedIndicators = true;
    @track isMoreFiltersBySelectedIndicatorsDisabled = true;
    @track addIndicator;
    @track isDisabledNewIndicatorButton = true;
    @track reloadCatalogIndicators;
    @track isRefreshCatalogFilters;
    @track error;

    errorCallback(error, stack) {
        this.group('errorCallback');
        this.error = error;
        this.showErrMessage('An error occurred during the execution of JavaScript.');
        console.error(JSON.stringify(error));
        this.groupEnd();
    }

    connectedCallback() {
        this.group('connectedCallback');
        this.log('initialization');
        this.getLibraries();
        this.getLayoutFields();
        this.groupEnd();
    }

    renderedCallback() {
        this.group('renderedCallback');
        if (this.isFirstCallRenderedCallback) {
            this.isFirstCallRenderedCallback = false;
            if (!this.recordId) {
                this.setActiveFieldValue = true;
                this.setActiveTab('tab2');
            } else {
                this.setActiveTab('tab3');
            }
        }
        this.groupEnd();
    }

    refreshColumns() {
        this.group('refreshColumns');
        this.connectedCallback();
        this.isRefreshCatalogFilters = !(this.isRefreshCatalogFilters);
        this.groupEnd();
    }

    get getIndicatorCatalogsClass() {
        return (this.selectedTabName === 'tab1' || this.selectedTabName === 'tab2') ? 'slds-grid slds-gutters' : 'slds-grid slds-gutters slds-hide';
    }

    get getSelectedIndicatorsClass() {
        return (this.selectedTabName === 'tab3') ? 'slds-grid slds-gutters' : 'slds-grid slds-gutters slds-hide';
    }

    getLayoutFields() {
        this.group('getLayoutFields');
        let that = this;
        let spinner = this.showSpinner('main');
        let params = {
            pageLayoutName: 'Custom Indicator Catalogue Layout',
            requiredFields: []
        };
        getLayoutFields(params)
            .then(data => {
                that.group('getLayoutFields-SUCCESS');
                that.log('layout fields', data);
                this.layoutFields = data;
                this.isDisabledNewIndicatorButton = false;
                that.hideSpinner('main', spinner);
                that.groupEnd();
            })
            .catch(error => {
                that.group('getLayoutFields-ERROR');
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

    getLibraries() {
        this.group('getLibraries');
        let that = this;
        let spinner = this.showSpinner('main');
        getLibraries()
            .then(data => {
                that.group('getLibraries-SUCCESS');
                let results = JSON.parse(data);
                that.log('getLibraries', results);
                if (!results.hasOwnProperty('allRecordTypes') || !results.hasOwnProperty('availableFields') || !results.hasOwnProperty('savedSettings')) {
                    that.showErrMessage('The required parameter was not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                let recordTypes = results.allRecordTypes;
                let accessRecordTypes = [];
                recordTypes.forEach(function (recordType) {
                    if (results.savedSettings[recordType.value]) {
                        if (recordType.label === 'Custom') {
                            that.customRecordTypeId = recordType.value;
                        }
                        if (results.savedSettings[recordType.value].active) {
                            accessRecordTypes.push({
                                label: recordType.label,
                                value: recordType.value,
                            })
                        }
                    }
                });
                if (accessRecordTypes.length > 1) {
                    let recordTypesAll = [{label: 'All Libraries', value: '0'}];
                    accessRecordTypes = recordTypesAll.concat(accessRecordTypes);
                }
                if (accessRecordTypes.length > 0) {
                    accessRecordTypes.forEach(function (item) {
                        item.checked = true;
                        if (item.value !== '0') {
                            item.disabled = true;
                        }
                    });
                    that.libraries = accessRecordTypes;
                } else {
                    recordTypes.forEach(function (item) {
                        item.checked = true;
                        if (item.value !== '0') {
                            item.disabled = true;
                        }
                    });
                    if (recordTypes.length > 1) {
                        let recordTypesAll = [{label: 'All Libraries', value: '0', checked: true}];
                        that.libraries = recordTypesAll.concat(recordTypes);
                    } else {
                        that.libraries = recordTypes;
                    }
                }
                let selectedLibraries = [];
                that.libraries.forEach(function (item) {
                    if (item.checked) {
                        selectedLibraries.push(item.value);
                    }
                });
                that.selectedLibraries = selectedLibraries;
                that.hideSpinner('main', spinner);
                that.groupEnd();
            })
            .catch(error => {
                that.group('getLibraries-ERROR');
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

    handleEventClearRecoveryIndicatorId() {
        this.recoveryIndicatorId = '';
    }

    handleEventRecoveryIndicator(event) {
        this.group('handleEventRecoveryIndicator');
        if (event.detail !== undefined) {
            this.recoveryIndicatorId = event.detail;
        }
        this.groupEnd();
    }

    handleShowHideMoreFiltersByIndicatorCatalogs() {
        this.group('handleShowHideMoreFiltersByIndicatorCatalogs');
        this.isMoreFiltersByIndicatorCatalogs = !this.isMoreFiltersByIndicatorCatalogs;
        this.groupEnd();
    }

    handleShowHideMoreFiltersBySelectedIndicators() {
        this.group('handleShowHideMoreFiltersBySelectedIndicators');
        this.isMoreFiltersBySelectedIndicators = !this.isMoreFiltersBySelectedIndicators;
        this.groupEnd();
    }

    handleFormLoad(event) {
        this.group('handleFormLoad');
        if (event.detail.hasOwnProperty('records')) {
            if (event.detail.records.hasOwnProperty(this.recordId)) {
                if (event.detail.records[this.recordId].hasOwnProperty('fields')) {
                    if (event.detail.records[this.recordId].fields.hasOwnProperty('Name')) {
                        this.templateName = 'Edit ' + event.detail.records[this.recordId].fields['Name'].value;
                    }
                }
            }
        }
        if (event.detail.hasOwnProperty('objectInfos')) {
            if (event.detail.objectInfos.hasOwnProperty('sfims__Report_Template__c')) {
                if (event.detail.objectInfos.sfims__Report_Template__c.hasOwnProperty('fields')) {
                    this.formInformation = JSON.parse(JSON.stringify(event.detail.objectInfos.sfims__Report_Template__c.fields));
                }
            }
        }
        this.groupEnd();
    }

    handleFormError(event) {
        this.group('handleFormError');
        this.showErrMessage('Error in the form of adding a report template.');
        console.log(JSON.stringify(event.detail));
        this.hideSpinner('main', 'saveTemplate');
        this.groupEnd();
    }

    handleFormSuccess(event) {
        this.group('handleFormSuccess');
        let result = event.detail;
        this.log('result', result);
        if (result.hasOwnProperty('id')) {
            if (this.selectedIndicatorsList.length === 0) {
                this.showWarningMessage('The list of Selected Indicators is empty.');
            }
            this.saveIndicators(result.id);
            this.hideSpinner('main', 'saveTemplate');
        }
        else {
            this.showErrMessage('Report Template was not saved.');
            this.hideSpinner('main', 'saveTemplate');
        }
        this.groupEnd();
    }

    onSearchKeyUpByIndicatorCatalogs(event) {
        this.searchValueByIndicatorCatalogs = event.target.value;
    }

    onSearchKeyUpBySelectedIndicators(event) {
        this.searchValueBySelectedIndicators = event.target.value;
    }

    handleClickTab(event) {
        this.group('handleClickTab');
        if (event.target.dataset.id) {
            this.setActiveTab(event.target.dataset.id);
        }
        this.groupEnd();
    }

    setActiveTab(tabId) {
        this.group('setActiveTab');
        this.log('tab id', tabId);
        this.startTimer('setActiveTab');
        if (tabId) {
            this.selectedTabName = tabId;
            let tabs = this['template'].querySelectorAll('span[data-id="tab"]');
            if (tabs.length === 3) {
                switch (tabId) {
                    case 'tab1':
                        this.lowMode = false;
                        tabs[0].classList.remove('slds-hide'); // open
                        tabs[1].classList.remove('slds-hide'); // open
                        tabs[2].classList.add('slds-hide'); // close
                        tabs[2].classList.remove('slds-hide-low'); // close
                        break;
                    case 'tab2':
                        this.lowMode = true;
                        tabs[0].classList.add('slds-hide'); // close
                        tabs[1].classList.remove('slds-hide'); // open
                        tabs[2].classList.remove('slds-hide'); // open
                        tabs[2].classList.add('slds-hide-low'); // open
                        break;
                    case 'tab3':
                        this.lowMode = false;
                        tabs[0].classList.add('slds-hide'); // close
                        tabs[1].classList.add('slds-hide'); // close
                        tabs[2].classList.remove('slds-hide', 'slds-hide-low'); // open
                        break;
                    default:
                }
            } else {
                this.showErrMessage('The required parameter was not received.');
            }
        }
        this.stopTimer('setActiveTab');
        this.groupEnd();
    }

    handleAddNewIndicator() {
        this.group('handleAddNewIndicator');
        this.showSpinner('newCustomIndicator', 'AddIndicator', 40000);
        this.showModal('newCustomIndicator');
        this.groupEnd();
    }

    handleCancelNewIndicator() {
        this.group('handleCancelNewIndicator');
        this.closeModal('newCustomIndicator');
        this.groupEnd();
    }

    handleChangeLibraries(event) {
        this.group('handleChangeLibraries');
        let index = event.target.value;
        this.log('index', index);
        let isChecked = event.target.checked;
        this.log('isChecked', isChecked);
        if (index === undefined || isChecked === undefined) {
            this.showErrMessage('Required parameters were not received.');
            return;
        }
        if (!this.libraries[index]) {
            this.showErrMessage('Required parameters were not received.');
            return;
        }
        let id = this.libraries[index].value;
        this.libraries[index].checked = isChecked;
        this.log('id', id);
        if (id) {
            if (id === '0') {
                if (event.target.checked) {
                    this.libraries.forEach(function (item) {
                        item.checked = true;
                        if (item.value !== '0') {
                            item.disabled = true;
                        }
                    });
                } else {
                    this.libraries.forEach(function (item) {
                        item.checked = false;
                        item.disabled = false;
                    });
                }
            } else {
                let count = 0;
                this.libraries.forEach(function (item) {
                    if (item.checked) {
                        count++;
                    }
                });
                if (this.libraries[0].value === '0' && count === this.libraries.length - 1) {
                    this.libraries.forEach(function (item) {
                        item.checked = true;
                        if (item.value !== '0') {
                            item.disabled = true;
                        }
                    });
                }
            }
            this.log('libraries', this.libraries);
            let selectedLibraries = [];
            this.libraries.forEach(function (item) {
                if (item.checked) {
                    selectedLibraries.push(item.value);
                }
            });
            this.log('selectedLibraries', selectedLibraries);
            this.selectedLibraries = selectedLibraries;
        }
        this.groupEnd();
    }

    handleEventCatalogsFiltersLoaded() {
        this.group('handleEventCatalogsFiltersLoaded');
        this.isMoreFiltersByIndicatorCatalogsDisabled = false;
        this.groupEnd();
    }

    handleEventAddIndicatorFromCatalog(event) {
        this.group('handleEventAddIndicatorFromCatalog');
        this.addIndicator = event.detail;
        this.groupEnd();
    }

    handleEventClearAddIndicator(event) {
        this.group('handleEventClearAddIndicator');
        this.addIndicator = '';
        this.groupEnd();
    }

    handleEventIndicatorsFiltersLoaded() {
        this.group('handleEventIndicatorsFiltersLoaded');
        this.isMoreFiltersBySelectedIndicatorsDisabled = false;
        this.groupEnd();
    }

    handleEventUpdateListSelectedIndicators(event) {
        this.group('handleEventUpdateListSelectedIndicators');
        this.handleEventClearAddIndicator(event);
        if (event.detail) {
            this.selectedIndicatorsList = JSON.parse(event.detail);
        }
        this.groupEnd();
    }

    handleEventCheckActiveTab() {
        this.group('handleEventCheckActiveTab');
        if (this.selectedTabName !== 'tab2') {
            this.setActiveTab('tab2');
        }
        this.groupEnd();
    }

    handleSaveReportTemplate() {
        this.group('handleSaveReportTemplate');
        let fields = this.formInformation;
        let formFields = {};
        let errFields = [];
        this['template'].querySelectorAll('lightning-input-field').forEach(function (elm) {
            formFields[elm.fieldName] = elm.value;
            if (!elm.reportValidity())
                if (fields[elm.fieldName]) {
                    errFields.push(fields[elm.fieldName].label);
                }
        });
        this.log('errors', errFields);
        this.log('form fields', formFields);
        if (errFields.length > 0) {
            let msg = '';
            if (errFields.length === 1) {
                msg = errFields[0] + '\n';
            } else {
                errFields.forEach(function (err) {
                    msg += '- ' + err + '\n';
                });
            }
            if (msg !== '') {
                this.showErrMessage('These required fields must be completed: ' + '\n' + msg);
            }
        } else {
            let isDuplicate = false;
            let selectedIndicatorsIds = [];
            this.selectedIndicatorsList.forEach(function (indicator) {
                if (selectedIndicatorsIds.indexOf(indicator.Id) !== -1) {
                    isDuplicate = true;
                } else {
                    selectedIndicatorsIds.push(indicator.Id);
                }
            });
            if (isDuplicate) {
                this.showErrMessage('Report Template has duplicate indicators.');
            } else {
                this.showSpinner('main', 'saveTemplate', 40000);
                this['template'].querySelector('lightning-record-edit-form').submit(formFields);
            }
        }
        this.groupEnd();
    }

    saveIndicators(templateId) {
        this.group('saveIndicators');
        let that = this;
        let spinner = this.showSpinner('main');
        let selectedIndicatorsIds = [];
        let size = this.selectedIndicatorsList.length;
        for (let i = 0; i < size; i++) {
            selectedIndicatorsIds.push(this.selectedIndicatorsList[i].Id);
        }
        this.log('selectedIndicatorsIds', selectedIndicatorsIds);
        let params = {
            newListIDs: selectedIndicatorsIds,
            templateId: templateId
        };
        saveReportTemplateIndicators(params)
            .then(data => {
                that.group('saveReportTemplateIndicators-SUCCESS');
                that.log('results', data);
                if (that.recordId) {
                    that.showSuccessMessage('Report Template "' + data.Name + '" was saved.');
                }
                else {
                    that.showSuccessMessage('Report Template "' + data.Name + '" was created.');
                }
                that.handleCancel();
                that.hideSpinner('main', spinner);
                that.groupEnd();
            })
            .catch(error => {
                that.group('saveReportTemplateIndicators-ERROR');
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

    handleAddIndicatorFormLoad(event) {
        this.group('handleAddIndicatorFormLoad');
        this.hideSpinner('newCustomIndicator', 'AddIndicator');
        this.groupEnd();
    }

    handleAddIndicatorFormError(event) {
        this.group('handleAddIndicatorFormError');
        this.showErrMessage('Error in the form of adding a custom indicator.');
        console.log(JSON.stringify(event.detail));
        this.groupEnd();
    }

    handleAddIndicatorSubmit(event) {
        this.group('handleAddIndicatorSubmit');
        this.showSpinner('newCustomIndicator', 'AddIndicator', 40000);
        this.groupEnd();
    }

    handleAddIndicatorFormSuccess(event) {
        this.group('handleAddIndicatorFormSuccess');
        this.hideSpinner('newCustomIndicator', 'AddIndicator');
        let newIndicator = event.detail;
        this.log('newIndicator', newIndicator);
        if (newIndicator) {
            this.showSuccessMessage('Indicator "' + newIndicator.fields.sfims__Indicator_Name__c.value + '" added successfully.');
            this.reloadCatalogIndicators = !(this.reloadCatalogIndicators);
        }
        else {
            this.showErrMessage('New Indicator was not received.');
        }
        this.handleCancelNewIndicator();
        this.groupEnd();
    }

    handleCancel() {
        this.group('handleCancel');
        this.cancel(true, 'sfims__Report_Template__c');
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

    cancel(isRedirect, sObject) {
        this.group('cancel');
        isRedirect = isRedirect || false;
        if (isRedirect) {
            if (!this.recordId) {
                this.navigateToObjectHome(sObject);
            } else {
                this.navigateToSObject(this.recordId);
            }
        } else {
            if (this.isRunning) {
                this.closeModal('v.isRunning');
            } else {
                /*
                if (cmp.find('overlayLib')) {
                    this.run(this.closeOverlayLib, []);
                } else {
                    this.run(this.closeQuickAction, []);
                }*/
            }
        }
        this.groupEnd();
    }

    navigateToSObject(recordId) {
        this.group('navigateToSObject');
        let record = recordId || this.recordId;
        if (record) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: record,
                    actionName: 'view'
                },
            });
        } else {
            this.showErrMessage('The Id was not received.');
        }
        this.groupEnd();
    }

    navigateToObjectHome(sObject) {
        this.group('navigateToObjectHome');
        if (sObject) {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: sObject,
                    actionName: 'home'
                },
            });
        } else {
            this.showErrMessage('The sObject was not received.');
        }
        this.groupEnd();
    }

    navigateToListView(objectApiName, filterName) {
        this.group('navigateToListView');
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: objectApiName,
                actionName: 'list'
            },
            state: {
                filterName: filterName
            }
        });
        this.groupEnd();
    }

    navigateToNewRecordPage(objectApiName) {
        this.group('navigateToNewRecordPage');
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: objectApiName,
                actionName: 'new'
            }
        });
        this.groupEnd();
    }

    navigateToRecordViewPage(recordId, objectApiName) {
        this.group('navigateToRecordViewPage');
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: objectApiName,
                actionName: 'view'
            }
        });
        this.groupEnd();
    }

    navigateToRecordEditPage(recordId, objectApiName) {
        this.group('navigateToRecordEditPage');
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: objectApiName,
                actionName: 'edit'
            }
        });
        this.groupEnd();
    }

    navigateToRelatedList(recordId, objectApiName, relationshipApiName) {
        this.group('navigateToRelatedList');
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: recordId,
                objectApiName: objectApiName,
                relationshipApiName: relationshipApiName,
                actionName: 'view'
            }
        });
        this.groupEnd();
    }

    navigateToTabPage(tabName) {
        this.group('navigateToTabPage');
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: tabName
            }
        });
        this.groupEnd();
    }

    navigateToWebPage(url) {
        this.group('navigateToWebPage');
        this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: url
                }
            },
            true
        );
        this.groupEnd();
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