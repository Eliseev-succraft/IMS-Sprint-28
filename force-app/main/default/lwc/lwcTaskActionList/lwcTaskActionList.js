import {LightningElement, api, track} from 'lwc';
import {loadStyle} from 'lightning/platformResourceLoader';
import lwcTaskActionList from '@salesforce/resourceUrl/lwcTaskActionList';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import getTasks from '@salesforce/apex/TaskActionListController.getTasks';
import changeTaskStatus from '@salesforce/apex/TaskActionListController.changeTaskStatus';
import deleteTask from '@salesforce/apex/TaskActionListController.deleteTask';
import {NavigationMixin} from 'lightning/navigation';
import {deleteRecord} from 'lightning/uiRecordApi';

export default class LwcTaskActionList extends NavigationMixin(LightningElement) {
    // Design attributes (from aura component)
    @api environmentType;
    @api relatedObjectRecordId;
    @api customTaskFields;
    @api customObjectFields;
    @api showTasks;
    @api isOnlyMyTasks;
    @api isShowPaginationBar;
    @api numberOfResults;
    @api isDebugLog;
    searchValue;
    sortingField;
    isTaskField;
    isDescSorting;
    //default values
    logSettings = {
        text: '',
        array: 'background: green; color: white;',
        object: 'background: green; color: white;',
    };
    // Global attributes
    isRunning = false;
    // Spinner attributes
    @track spinner = {
        main: false
    };
    qSpinners = {};
    cmpSpinner = {};
    @track modals = {};
    // Additional attributes
    menu = [
        {id: 'Open', label: 'Open Tasks'},
        {id: 'Done', label: 'Closed Tasks'},
        {id: 'All', label: 'All Tasks'}
    ];
    @track selectedMenuItem = 0; // open tasks
    recordTypes = {};
    @track columns = {
        objectColumns: [],
        taskColumns: [],
        allColumns: []
    };
    tasks = [];
    @track displayTasks = [];
    @track recordPageUrl;
    selectedTaskId;

    // Methods
    get operationName() {
        return this.menu[this.selectedMenuItem].label;
    }

    get isDisplayGrid() {
        return this.columns.length > 0;
    }

    get tasksCount() {
        return this.tasks.length;
    }

    get isCommunity() {
        return this.environmentType === 'Community';
    }

    @api refreshView() {
        this.fetchData();
    }

    // Component
    connectedCallback() {
        this.startMethod('connectedCallback');
        this.log('initialization');
        this.fetchData();
        let that = this;
        Promise.all([loadStyle(this, lwcTaskActionList)])
            .then(() => {
                that.log('global styles were loaded')
            })
            .catch(error => {
                let message = 'Unknown error';
                if (Array.isArray(error.body)) {
                    message = error.body.map(e => e.message).join(', ');
                } else if (typeof error.body.message === 'string') {
                    message = error.body.message;
                }
                that.showErrMessage(message);
            });
        this.stopMethod();
    }

    renderedCallback() {
        this.startMethod('renderedCallback');
        this.log('initialization');
        this.stopMethod();
    }

    handleCreateTask() {
        this.startMethod('handleCreateTask');
        let recordTypeId;
        // set standard record type to create a new task
        if (this.recordTypes.hasOwnProperty('Standard')) {
            recordTypeId = this.recordTypes.Standard;
        }
        const customEvent = new CustomEvent('NewTask', {
            detail: {recordTypeId: recordTypeId},
        });
        this.dispatchEvent(customEvent);
        /* does not work in LWC yet
        https://success.salesforce.com/ideaView?id=0873A000000TziWQAS
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Task',
                actionName: 'new'
            }
        });
        */
        this.stopMethod();
    }

    handleChangeMenuItem(event) {
        this.startMethod('handleChangeMenuItem');
        this.selectedMenuItem = event.detail.value;
        this.fetchData();
        this.stopMethod();
    }

    handleStartTaskClick(event) {
        this.startMethod('handleStartTaskClick');
        let key = event.target.dataset.key;
        this.log(key);
        if (key) {
            const customEvent = new CustomEvent('StartTask', {
                detail: {taskId: key},
            });
            this.dispatchEvent(customEvent);
        } else {
            this.showErrMessage('The event was not found.');
        }
        this.stopMethod();
    }

    handleMarkCompleteClick(event) {
        this.startMethod('handleMarkCompleteClick');
        let key = event.target.dataset.key;
        let that = this;
        this.log(key);
        if (key) {
            let spinner = this.showSpinner('main');
            let params = {
                taskId: key,
                status: 'Done'
            };
            changeTaskStatus(params)
                .then(data => {
                    that.log(data);
                    that.hideSpinner('main', spinner);
                    if (data === true) {
                        that.showSuccessMessage('The task was completed successfully.');
                    } else {
                        that.showErrMessage('The task was not completed.');
                    }
                    that.fetchData();
                })
                .catch(error => {
                    that.hideSpinner('main', spinner);
                    if (error) {
                        let message = 'Unknown error';
                        console.log(error);
                        if (Array.isArray(error.body)) {
                            message = error.body.map(e => e.message).join(', ');
                        } else if (typeof error.body.message === 'string') {
                            message = error.body.message;
                        }
                        that.showErrMessage(message)
                    }
                });
        } else {
            this.showErrMessage('The event was not found.');
        }
        this.stopMethod();
    }

    navigateToTask(event) {
        this.startMethod('navigateToTask');
        let id = event.target.dataset.id;
        this.log(id);
        if (id) {
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: id,
                    actionName: 'view',
                },
            }).then(url => {
                this.recordPageUrl = url;
            });
        } else {
            this.showErrMessage('The Id was not received.');
        }
        this.stopMethod();
    }

    navigateToURL(event) {
        this.startMethod('navigateToURL');
        let id = event.target.dataset.id;
        this.log(id);
        if (id) {
            this.navigateToRecordId(id);
        } else {
            this.showErrMessage('The Id was not received.');
        }
        this.stopMethod();
    }

    navigateToRecordId(id) {
        this.startMethod('navigateToRecordId');
        this.log(id);
        if (id) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: id,
                    actionName: 'view',
                },
            });
        } else {
            this.showErrMessage('The Id was not received.');
        }
        this.stopMethod();
    }

    handleTableAction(event) {
        this.startMethod('handleTableAction');
        let action = event.detail.value;
        console.log(action);
        let id = event.target.dataset.id;
        this.log(id);
        if (id && action) {
            this.selectedTaskId = id;
            switch (action) {
                case 'view':
                    this.navigateToRecordId(id);
                    break;
                case 'delete':
                    this.showModal('delete');
                    break;
            }
        } else {
            this.showErrMessage('The event has not been found.');
        }
        this.stopMethod();
    }

    handleCancelDeleteModal() {
        this.startMethod('handleCancelDeleteModal');
        this.closeModal('delete');
        this.stopMethod();
    }

    handleConfirmDeleteTask() {
        this.startMethod('handleConfirmDeleteTask');
        let that = this;
        let selectedTaskId = this.selectedTaskId;
        this.log(selectedTaskId);
        if (selectedTaskId) {
            let spinner = this.showSpinner('main');
            let params = {
                taskId: selectedTaskId
            };
            deleteTask(params)
                .then(data => {
                    that.log(data);
                    that.showSuccessMessage('Task was deleted.');
                    that.fetchData();
                    that.hideSpinner('main', spinner);

                })
                .catch(error => {
                    that.hideSpinner('main', spinner);
                    if (error) {
                        let message = 'Unknown error';
                        console.log(error);
                        if (Array.isArray(error.body)) {
                            message = error.body.map(e => e.message).join(', ');
                        } else if (typeof error.body.message === 'string') {
                            message = error.body.message;
                        }
                        that.showErrMessage(message)
                    }
                });
        } else {
            this.showErrMessage('The task was not found.');
        }
        that.closeModal('delete');
        this.stopMethod();
    }

    handleFieldClick(event) {
        this.startMethod('handleFieldClick');
        let field = event.target.dataset.field;
        this.log('field index', field);
        if (field) {
            field = Number(field);
            if (this.columns.allColumns[field]) {
                let size = this.columns.allColumns.length;
                for (let i = 0; i < size; i++) {
                    if (i !== field) {
                        this.columns.allColumns[i].isDescSorting = true;
                        this.columns.allColumns[i].isFieldSorting = false;
                    }
                }
                this.columns.allColumns[field].isDescSorting = !this.columns.allColumns[field].isDescSorting;
                this.columns.allColumns[field].isFieldSorting = true;
                this.sortingField = this.columns.allColumns[field].fieldName;
                this.isDescSorting = this.columns.allColumns[field].isDescSorting;
                this.isTaskField = this.columns.allColumns[field].isTaskField;
                this.fetchData();
            }
        }
        this.stopMethod();
    }

    fetchData() {
        this.startMethod('fetchData');
        let spinner = this.showSpinner('main');
        this.log('environmentType', this.environmentType);
        this.log('relatedObjectRecordId', this.relatedObjectRecordId);
        this.log('customTaskFields', this.customTaskFields);
        this.log('showTasks', this.showTasks);
        this.log('isOnlyMyTasks', this.isOnlyMyTasks);
        this.log('isShowPaginationBar', this.isShowPaginationBar);
        this.log('numberOfResults', this.numberOfResults);
        this.log('searchValue', this.searchValue);
        this.log('isTaskField', this.isTaskField);
        this.log('sortingField', this.sortingField);
        this.log('isDescSorting', this.isDescSorting);
        this.log('isDebugLog', this.isDebugLog);
        let that = this;
        // validations input variables
        if (this.menu[this.selectedMenuItem] === undefined) {
            that.showErrMessage('The operation is incorrect.');
            that.hideSpinner('main', spinner);
            return;
        }
        if (!(this.customTaskFields && this.trim(this.customTaskFields))) {
            that.showErrMessage('The list of fields in the Task object is empty.');
            that.hideSpinner('main', spinner);
            return;
        }
        if (this.showTasks !== 'All Users' && this.showTasks !== 'Current user') {
            that.showErrMessage('The \'Show Tasks\' option is incorrect.');
            that.hideSpinner('main', spinner);
            return;
        }
        if (this.isShowPaginationBar === true && Number(this.numberOfResults) <= 0) {
            that.showErrMessage('The number of results per page is incorrect.');
            that.hideSpinner('main', spinner);
            return;
        }
        // END validations
        let params = {
            recordId: this.relatedObjectRecordId,
            statusFilter: this.menu[this.selectedMenuItem].id,
            customTaskFields: this.customTaskFields,
            customObjectFields: this.customObjectFields,
            showTasks: this.showTasks,
            isOnlyMyTasks: this.isOnlyMyTasks,
            searchValue: this.searchValue,
            isTaskField: this.isTaskField,
            sortingField: this.sortingField,
            isDescSorting: this.isDescSorting,
            isDebugLog: this.isDebugLog
        };
        getTasks(params)
            .then(data => {
                that.hideSpinner('main', spinner);
                // validations input parameters
                if (!data) {
                    that.showErrMessage('The data from the apex were not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                let response = JSON.parse(data);
                that.log('response', response);
                if (!response.hasOwnProperty('recordTypes')) {
                    that.showErrMessage('The record types parameter was not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                if (!response.hasOwnProperty('someObject')) {
                    that.showErrMessage('The related object parameter was not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                if (!response.someObject.hasOwnProperty('columns') || !response.someObject.hasOwnProperty('labels')) {
                    that.showErrMessage('Parameters were not received for the related object.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                if (!response.hasOwnProperty('taskObject')) {
                    that.showErrMessage('The \'Task\' parameter was not received.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                if (!response.taskObject.hasOwnProperty('columns') || !response.taskObject.hasOwnProperty('labels')) {
                    that.showErrMessage('Parameters were not received for the task object.');
                    that.hideSpinner('main', spinner);
                    return;
                }
                // END validations input parameters
                that.recordTypes = response.recordTypes;
                if (that.columns.allColumns.length === 0) {
                    // if exists columns from the related object
                    if (response.someObject.columns && response.someObject.labels) {
                        let objectColumns = [];
                        let listColumns = response.someObject.columns;
                        listColumns.forEach(function (field) {
                            if (response.someObject.labels.hasOwnProperty(field)) {
                                switch (field) {
                                    default:
                                        objectColumns.push(
                                            {
                                                type: 'text',
                                                fieldName: field,
                                                label: response.someObject.labels[field],
                                                class: 'slds-is-sortable custom-th',
                                                isTaskField: false,
                                                isFieldSorting: false,
                                                isDescSorting: true,
                                                colSpan: '1'
                                            }
                                        );
                                }
                            } else {
                                that.showWarningMessage('The \'' + field + '\' label was not found.')
                            }
                        });
                        that.columns.objectColumns = objectColumns;
                        that.log('object columns', objectColumns);
                    }
                    let taskColumns = [];
                    // if exists columns from the task object
                    if (!response.taskObject.columns || !response.taskObject.labels) {
                        that.showErrMessage('The \'Task\' parameter was not received.');
                        that.hideSpinner('main', spinner);
                        return;
                    }
                    let listColumns = response.taskObject.columns;
                    that.startTimer('task columns iteration');
                    listColumns.forEach(function (field) {
                        if (response.taskObject.labels.hasOwnProperty(field)) {
                            switch (field) {
                                case 'Subject':
                                    taskColumns.push(
                                        {
                                            type: 'url',
                                            fieldName: field,
                                            fieldRelated: {
                                                label: 'Subject',
                                                id: 'Id'
                                            },
                                            label: response.taskObject.labels[field],
                                            class: 'slds-is-sortable custom-th',
                                            isTaskField: true,
                                            isFieldSorting: false,
                                            isDescSorting: true,
                                            colSpan: '2'
                                        }
                                    );
                                    break;
                                case 'WhatId':
                                    taskColumns.push(
                                        {
                                            type: 'url',
                                            fieldName: field,
                                            fieldRelated: {
                                                label: 'What',
                                                child: {
                                                    label: 'Name',
                                                    id: 'Id'
                                                }
                                            },
                                            label: response.taskObject.labels[field],
                                            class: 'slds-is-sortable custom-th',
                                            isTaskField: true,
                                            isFieldSorting: false,
                                            isDescSorting: true,
                                            colSpan: '1'
                                        }
                                    );
                                    break;
                                case 'OwnerId':
                                    taskColumns.push(
                                        {
                                            type: 'url',
                                            fieldName: field,
                                            fieldRelated: {
                                                label: 'Owner',
                                                child: {
                                                    label: 'Name',
                                                    id: 'Id'
                                                }
                                            },
                                            label: response.taskObject.labels[field],
                                            class: 'slds-is-sortable custom-th',
                                            isTaskField: true,
                                            isFieldSorting: false,
                                            isDescSorting: true,
                                            colSpan: '1'
                                        }
                                    );
                                    break;
                                case 'Start':
                                    taskColumns.push(
                                        {
                                            type: 'button',
                                            label: response.taskObject.labels[field],
                                            class: 'custom-btn-column',
                                            colSpan: '1'
                                        });
                                    break;
                                default:
                                    taskColumns.push(
                                        {
                                            type: 'text',
                                            fieldName: field,
                                            label: response.taskObject.labels[field],
                                            class: 'slds-is-sortable custom-th',
                                            isTaskField: true,
                                            isFieldSorting: false,
                                            isDescSorting: true,
                                            colSpan: '1'
                                        }
                                    );
                            }
                        } else {
                            that.showWarningMessage('The \'' + field + '\' label was not found.')
                        }
                    });
                    that.stopTimer('task columns iteration');
                    that.columns.taskColumns = taskColumns;
                    that.columns.allColumns = that.columns.objectColumns.concat(taskColumns);
                    that.log('task columns', taskColumns);
                }
                // if exists results
                if (response.taskObject.hasOwnProperty('results')) {
                    that.log('task iteration');
                    let tasks = [];
                    that.startTimer('task iteration');
                    response.taskObject.results.forEach(function (iterationTask) {
                        that.log('iterationTask', iterationTask);
                        let dataset = [];
                        // display the results from a related object
                        that.columns.objectColumns.forEach(function (iterationField) {
                            let set = {
                                fieldName: iterationField.fieldName,
                                value: '',
                                colSpan: iterationField.colSpan
                            };
                            if (iterationTask.hasOwnProperty('WhatId')) {
                                if (response.someObject['resultsMap'].hasOwnProperty(iterationTask.WhatId)) {
                                    if (response.someObject['resultsMap'][iterationTask.WhatId].hasOwnProperty(iterationField.fieldName)) {
                                        set.value = response.someObject['resultsMap'][iterationTask.WhatId][iterationField.fieldName];
                                    } else {
                                        // that.showErrMessage('The field was not found in the related object.');
                                        // that.hideSpinner('main', spinner);
                                        // return;
                                    }
                                } else {
                                    that.showErrMessage('The record was not found in the related object.');
                                    that.hideSpinner('main', spinner);
                                    return;
                                }
                            }
                            switch (iterationField.type) {
                                case 'url':
                                    set.isUrlType = true;
                                    set.urlLabel = 'undefined';
                                    if (iterationField.hasOwnProperty('fieldRelated')) {
                                        if (iterationField.fieldRelated.hasOwnProperty('child')) {
                                            set.urlLabel = iterationTask[iterationField.fieldRelated.label][iterationField.fieldRelated.child.label];
                                            set.value = iterationTask[iterationField.fieldRelated.label][iterationField.fieldRelated.child.id];
                                        } else {
                                            if (iterationField.fieldRelated.hasOwnProperty('label') && iterationField.fieldRelated.hasOwnProperty('id')) {
                                                set.urlLabel = iterationTask[iterationField.fieldRelated.label];
                                                set.value = iterationTask[iterationField.fieldRelated.id];
                                            }
                                        }
                                    }
                                    break;
                                default:
                                    set.isTextType = true;
                            }
                            dataset.push(set);
                        });
                        // display the results from a task object
                        that.columns.taskColumns.forEach(function (iterationField) {
                            let set = {
                                fieldName: iterationField.fieldName,
                                value: '',
                                colSpan: iterationField.colSpan
                            };
                            if (iterationTask.hasOwnProperty(iterationField.fieldName)) {
                                set.value = iterationTask[iterationField.fieldName];
                            }
                            switch (iterationField.type) {
                                case 'url':
                                    set.isUrlType = true;
                                    set.urlLabel = 'undefined';
                                    if (iterationField.hasOwnProperty('fieldRelated')) {
                                        if (iterationField.fieldRelated.hasOwnProperty('child')) {
                                            if (iterationTask.hasOwnProperty(iterationField.fieldRelated.label)) {
                                                set.urlLabel = iterationTask[iterationField.fieldRelated.label][iterationField.fieldRelated.child.label];
                                                set.value = iterationTask[iterationField.fieldRelated.label][iterationField.fieldRelated.child.id];
                                            } else {
                                                set.isUrlType = false;
                                            }
                                        } else {
                                            if (iterationField.fieldRelated.hasOwnProperty('label') && iterationField.fieldRelated.hasOwnProperty('id')) {
                                                if (iterationTask.hasOwnProperty(iterationField.fieldRelated.label)) {
                                                    set.urlLabel = iterationTask[iterationField.fieldRelated.label];
                                                    set.value = iterationTask[iterationField.fieldRelated.id];
                                                } else {
                                                    set.isUrlType = false;
                                                }
                                            }
                                        }
                                    }
                                    break;
                                case 'button':
                                    set.isShowButton = false;
                                    if (iterationTask.hasOwnProperty('Status')) {
                                        let recordTypeId;
                                        if (that.recordTypes.hasOwnProperty('Custom')) {
                                            recordTypeId = that.recordTypes.Custom;
                                        }
                                        if (recordTypeId) {
                                            if (iterationTask.RecordTypeId === recordTypeId) {
                                                if ((iterationTask.Status === 'Open' || iterationTask.Status === 'Rejected')) {
                                                    set.isShowButton = true;
                                                    if (iterationTask.hasOwnProperty('sfims__Task_List_Template_Item__r') && iterationTask['sfims__Task_List_Template_Item__r'].hasOwnProperty('sfims__Flow_Name__c')) {
                                                        set.isFlowType = true;
                                                    } else {
                                                        set.isCompleteType = true;
                                                    }
                                                }
                                            } else {
                                                if ((iterationTask.Status !== 'Done' || iterationTask.Status === 'Compleated')) {
                                                    set.isShowButton = true;
                                                    set.isCompleteType = true;
                                                }
                                            }
                                        }
                                    }
                                    break;
                                default:
                                    set.isTextType = true;
                            }
                            dataset.push(set);
                        });
                        tasks.push({
                            id: iterationTask['Id'],
                            dataset: dataset
                        });
                    });
                    that.stopTimer('task iteration');
                    that.tasks = tasks;
                    if (!that.isShowPaginationBar) {
                        that.displayTasks = tasks;
                    } else {
                        let lwcPaginationBar = that.template.querySelector('c-lwc-pagination-bar');
                        if (lwcPaginationBar) {
                            lwcPaginationBar.count = Number(that.numberOfResults);
                            lwcPaginationBar.results = tasks;
                            lwcPaginationBar.generatePages();
                        }
                    }
                }
            })
            .catch(error => {
                that.hideSpinner('main', spinner);
                if (error) {
                    let message = 'Unknown error';
                    console.log(error);
                    if (Array.isArray(error.body)) {
                        message = error.body.map(e => e.message).join(', ');
                    } else if (typeof error.body.message === 'string') {
                        message = error.body.message;
                    }
                    that.showErrMessage(message)
                }
            });
        this.stopMethod();
    }

    showResultsPage(event) {
        this.startMethod('showResultsPage');
        this.log('display tasks', event.detail);
        this.displayTasks = JSON.parse(JSON.stringify(event.detail));
        this.stopMethod();
    }

    handleKeyUp(event) {
        let inputValue = event.target.value;
        if (!inputValue) {
            this.searchValue = '';
            this.fetchData();
        }
    }

    handleEnter(event) {
        if (event.which === 13) {
            this.startMethod('handleKeyUp');
            let inputValue = event.target.value;
            this.log('search value', inputValue);
            if (inputValue) {
                inputValue = inputValue.trim();
                if (inputValue.length > 0) {
                    this.searchValue = inputValue;
                    this.fetchData();
                }
            }
            this.stopMethod();
        }
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

    showModal(attribute) {
        this.log('showModal, attribute: ' + attribute);
        this.modals[attribute] = true;
    }

    closeModal(attribute) {
        this.log('closeModal, attribute: ' + attribute);
        if (this.modals.hasOwnProperty(attribute)) {
            this.modals[attribute] = false;
        } else {
            this.showWarningMessage('The attribute \'' + attribute + '\' was not found.')
        }
    }

    showSpinner(attribute, timeStamp, delay, isOneSpinner) {
        timeStamp = timeStamp || new Date().getTime();
        this.log('showSpinner, attribute: ' + attribute);
        delay = delay || 10000; // time for local spinner
        let delayOneSpinner = 10000; // time for one spinner
        isOneSpinner = isOneSpinner || true;
        if (!this.qSpinners.hasOwnProperty(attribute)) {
            this.qSpinners[attribute] = [];
        }
        if (this.qSpinners[attribute].indexOf(timeStamp) === -1) {
            this.qSpinners[attribute].push(timeStamp);
            if (isOneSpinner) {
                if (!this.cmpSpinner.hasOwnProperty(attribute)) {
                    this.cmpSpinner[attribute] = timeStamp;
                    this.spinner[attribute] = true;
                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    setTimeout(() => {
                        this.log('getCallback hideSpinner, attribute: ' + attribute);
                        if (this.cmpSpinner.hasOwnProperty(attribute)) {
                            if (this.cmpSpinner[attribute] === timeStamp) {
                                delete this.cmpSpinner[attribute];
                                this.spinner[attribute] = false;
                                this.qSpinners = {};
                            }
                        }
                    }, delayOneSpinner);
                }
            } else {
                let that = this;
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    that.hideSpinner(attribute, timeStamp);
                }, delay);
                this.spinner[attribute] = true;
            }
        }
        return timeStamp;
    }

    hideSpinner(attribute, timeStamp) {
        this.log('hideSpinner, attribute: ' + attribute);
        if (this.qSpinners.hasOwnProperty(attribute)) {
            let index = this.qSpinners[attribute].indexOf(timeStamp);
            if (index !== -1) {
                if (this.qSpinners[attribute].length === 1) {
                    if (this.cmpSpinner.hasOwnProperty(attribute)) {
                        delete this.cmpSpinner[attribute];
                    }
                    delete this.qSpinners[attribute];
                    this.spinner[attribute] = false;
                } else {
                    this.qSpinners[attribute].splice(index, 1);
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

    trim(str) {
        return str.replace(/^\s+|\s+$/g, '');
    }
}