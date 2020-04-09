import {LightningElement, api, track, wire} from 'lwc';
import getAssessmentCriteria from '@salesforce/apex/AssessmentCriteriaEditorController.getAssessmentCriteria';
import setAssessmentCriteria from '@salesforce/apex/AssessmentCriteriaEditorController.setAssessmentCriteria';
import {getRecord} from 'lightning/uiRecordApi';

export default class lwcAssessmentCriteriaEditor extends LightningElement {
    @api isDebugLog = false;
    debugLogStyle = 'background: green; color: white;';
    @api recordId;
    @track defaultDisplayCount = 5;
    @track isShowAll;
    @track isAccessEdit = false;
    @track isEditMode = false;
    @track allCriteria = [];
    @track displayCriteria = [];

    get isVisibleBtn() {
        return (this.isAccessEdit === true && this.isEditMode === false)
    }

    get title() {
        let response = 'Assessment Criteria ' + '(' + this.allCriteria.length + ')';
        if (!this.isEditMode) {
            response = 'Assessment Criteria ' + '(' + this.displayCriteria.length + (this.isShowAll ? '' : '+') + ')';
        }
        return response;
    }

    get isShowViewAll() {
        return !(this.isShowAll || this.isEditMode);
    }

    errorCallback(error, stack) {
        this.begin('errorCallback');
        this['template'].querySelector('c-lwc-utility-message').showErrorMessage('An error occurred during the execution of JavaScript.');
        console.error(JSON.stringify(error));
        this.end();
    }

    connectedCallback() {
        this.begin('connectedCallback');
        this.isShowAll = true;
        // this.showAllCriteria();
        this.end();
    }

    showAllCriteria() {
        this.begin('showAllCriteria');
        this.isShowAll = true;
        this.refreshView();
        this.end();
    }

    refreshView() {
        this.begin('refreshView');
        if (this.isShowAll) {
            this.displayCriteria = JSON.parse(JSON.stringify(this.allCriteria));
        } else {
            let allCriteriaSize = this.allCriteria.length;
            if (allCriteriaSize > this.defaultDisplayCount) {
                for (let i = 0; i < this.defaultDisplayCount; i++) {
                    this.displayCriteria.push(this.allCriteria[i]);
                }
                this.isShowAll = false;
            } else {
                this.displayCriteria = this.allCriteria;
                this.isShowAll = true;
            }
        }
        this.end();
    }

    @wire(getRecord, {recordId: '$recordId', fields: ['sfims__Assessment__c.sfims__Status__c']})
    currentRecord({error, data}) {
        let that = this;
        if (error) {
            that.begin('currentRecord-ERROR');
            let message = 'Unknown error';
            if (Array.isArray(error.body)) {
                message = error.body.map(e => e.message).join(', ');
            } else if (typeof error.body.message === 'string') {
                message = error.body.message;
            }
            if (message.toString() !== 'The requested resource does not exist') {
                that['template'].querySelector('c-lwc-utility-message').showErrorMessage(message);
            }
            that.end();
        } else if (data) {
            that.begin('currentRecord-SUCCESS');
            that.log(data);
            if (!data) {
                that['template'].querySelector('c-lwc-utility-message').showErrorMessage('The Data were not received.');
                that.end();
                return;
            }
            let status = data.fields.sfims__Status__c.value;
            that.log('status', status);
            that.isAccessEdit = !(status === 'Approved' || status === 'Completed');
            that.end();
        }
    }

    fetchData() {
        this.begin('fetchData');
        let spinner = this['template'].querySelector('c-lwc-utility-spinner').showSpinner();
        let that = this;
        getAssessmentCriteria({assessmentId: this.recordId})
            .then(data => {
                that.begin('getAssessmentCriteria-SUCCESS');
                that.log(data);
                if (!data) {
                    that['template'].querySelector('c-lwc-utility-message').showErrorMessage('The Data were not received.');
                    that['template'].querySelector('c-lwc-utility-spinner').hideSpinner(spinner);
                    that.end();
                    return;
                }
                if (Array.isArray(data)) {
                    that.displayCriteria = [];
                    let results = JSON.parse(JSON.stringify(data));
                    results.forEach(function (elm) {
                        if (elm.hasOwnProperty('sfims__Type__c')) {
                            elm.isHelpText = false;
                            elm.sfims__Description__c = '';
                            if (elm.hasOwnProperty('sfims__Assessment_Criteria_Definition__r')) {
                                if (elm.sfims__Assessment_Criteria_Definition__r.hasOwnProperty('sfims__Description__c')) {
                                    elm.isHelpText = true;
                                    elm.sfims__Description__c = elm.sfims__Assessment_Criteria_Definition__r.sfims__Description__c.replace(/<\/?[^>]+(>|$)/g, '');
                                }
                            }
                            let isExistInPicklist = false;
                            switch (elm.sfims__Type__c) {
                                case 'Rating':
                                    if (elm.hasOwnProperty('sfims__Rating__c')) {
                                        elm.Score = elm.sfims__Rating__c; // view mode
                                    } else {
                                        elm.sfims__Rating__c = ''; // edit mode
                                        elm.Score = ''; // view mode
                                    }
                                    elm.Min = 0;
                                    elm.Max = 10;
                                    if (elm.hasOwnProperty('sfims__Assessment_Criteria_Definition__r')) {
                                        if (elm.sfims__Assessment_Criteria_Definition__r.hasOwnProperty('sfims__Maximum_Rating__c')) {
                                            elm.Max = Number(elm.sfims__Assessment_Criteria_Definition__r.sfims__Maximum_Rating__c);
                                        }
                                        if (elm.sfims__Assessment_Criteria_Definition__r.hasOwnProperty('sfims__Minimum_Rating__c')) {
                                            elm.Min = Number(elm.sfims__Assessment_Criteria_Definition__r.sfims__Minimum_Rating__c);
                                        }
                                    }
                                    elm.isRating = true;
                                    if (elm.sfims__Rating__c === '' && (elm.Min === elm.Max)) {
                                        elm.sfims__Rating__c = elm.Min;
                                    }
                                    elm.isPicklist = false;
                                    elm.isText = false;
                                    break;
                                case 'Picklist':
                                    if (elm.hasOwnProperty('sfims__Selected_Picklist_Value__c')) {
                                        elm.Score = elm.sfims__Selected_Picklist_Value__c; // view mode
                                    } else {
                                        elm.sfims__Selected_Picklist_Value__c = ''; // edit mode
                                        elm.Score = ''; // view mode
                                    }
                                    elm.isRating = false;
                                    elm.isPicklist = true;
                                    elm.isText = false;
                                    elm.Options = [{
                                        label: '--None--',
                                        value: ''
                                    }];
                                    if (elm.hasOwnProperty('sfims__Assessment_Criteria_Definition__r')) {
                                        if (elm.sfims__Assessment_Criteria_Definition__r.hasOwnProperty('sfims__Picklist_Values__c')) {
                                            let options = elm.sfims__Assessment_Criteria_Definition__r.sfims__Picklist_Values__c.split(';');
                                            options.forEach(function (opt) {
                                                opt = opt.trim();
                                                if (opt) {
                                                    if (opt === elm.Score) {
                                                        isExistInPicklist = true;
                                                    }
                                                    elm.Options.push({
                                                        value: opt,
                                                        label: opt
                                                    });
                                                }
                                            });
                                        }
                                    }
                                    if (elm.Options.length === 1) {
                                        that['template'].querySelector('c-lwc-utility-message').showErrorMessage('The picklist values have not been loaded.');
                                        that.end();
                                        return;
                                    } else {
                                        if (!isExistInPicklist && elm.Score) {
                                            elm.Options.push({
                                                value: elm.Score,
                                                label: elm.Score + ' (excluded)'
                                            });
                                        }
                                    }
                                    break;
                                default:
                                    elm.Score = '';
                                    elm.isRating = false;
                                    elm.isPicklist = false;
                                    elm.isText = true;
                            }
                        }
                    });
                    that.allCriteria = results;
                    that.refreshView();
                }
                that.log('all criteria', that.allCriteria);
                that['template'].querySelector('c-lwc-utility-spinner').hideSpinner(spinner);
                that.end();
            })
            .catch(error => {
                that.begin('getAssessmentCriteria-ERROR');
                if (error) {
                    let message = 'Unknown error';
                    console.log(error);
                    if (Array.isArray(error.body)) {
                        message = error.body.map(e => e.message).join(', ');
                    } else if (typeof error.body.message === 'string') {
                        message = error.body.message;
                    }
                    that['template'].querySelector('c-lwc-utility-spinner').hideSpinner(spinner);
                    that['template'].querySelector('c-lwc-utility-message').showErrorMessage(message);
                }
                that.end();
            });
        this.end();
    }

    handleChange(event) {
        this.begin('handleChange');
        let row = event.target.dataset.row;
        this.log('row', row);
        let name = event.target.name;
        this.log('field', name);
        if (row !== undefined && name !== undefined) {
            if (this.allCriteria[row][name] !== event.target.value) {
                this.allCriteria[row][name] = event.target.value;
            }
        } else {
            this['template'].querySelector('c-lwc-utility-message').showErrorMessage('The event has not been found.');
            this.end();
            return;
        }
        this.log('all criteria', this.allCriteria);
        this.end();
    }

    handlerClickSave() {
        this.begin('handlerClickSave');
        let spinner = this['template'].querySelector('c-lwc-utility-spinner').showSpinner();
        this.log('save data', this.allCriteria);
        let that = this;
        setAssessmentCriteria({criteria: this.allCriteria})
            .then(result => {
                that.begin('setAssessmentCriteria-SUCCESS');
                if (result) {
                    that.handlerClickCancel();
                    that['template'].querySelector('c-lwc-utility-message').showSuccessMessage('Assessment Criteria are saved.');
                } else {
                    that['template'].querySelector('c-lwc-utility-message').showErrorMessage('Assessment Criteria are not saved.');
                }
                that['template'].querySelector('c-lwc-utility-spinner').hideSpinner(spinner);
                that.end();
            })
            .catch(error => {
                that.begin('setAssessmentCriteria-ERROR');
                if (error) {
                    let message = 'Unknown error';
                    console.log(error);
                    if (Array.isArray(error.body)) {
                        message = error.body.map(e => e.message).join(', ');
                    } else if (typeof error.body.message === 'string') {
                        message = error.body.message;
                    }
                    that['template'].querySelector('c-lwc-utility-message').showErrorMessage(message);
                }
                that['template'].querySelector('c-lwc-utility-spinner').hideSpinner(spinner);
                that.end();
            });
        this.end();
    }

    handleClickEdit() {
        this.begin('handleClickEdit');
        this.isEditMode = true;
        this.end();
    }

    handlerClickCancel() {
        this.begin('handlerClickCancel');
        this.fetchData();
        this.isEditMode = false;
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