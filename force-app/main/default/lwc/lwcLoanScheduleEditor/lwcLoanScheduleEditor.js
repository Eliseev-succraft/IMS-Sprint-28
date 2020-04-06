import {LightningElement, track, api} from 'lwc';
import {updateRecord} from 'lightning/uiRecordApi';
import getSchedules from '@salesforce/apex/LoanScheduleEditorController.getSchedules';

const actions = [
    {label: 'Show details', name: ''},
    {label: 'Delete', name: ''},
];

const columns = [
    {
        label: 'Repayment Schedule Number',
        fieldName: 'Name',
        type: 'navigation',
        cellAttributes: {alignment: 'left'},
        typeAttributes: {
            label: {fieldName: 'Name'},
            recordId: {fieldName: 'Id'},
            target: '_blank',
            template: 'url'
        },
        sortable: true
    },
    {
        label: 'Due Date',
        fieldName: 'sfims__Due_Date__c',
        type: 'date-local',
        sortable: true,
        editable: true,
        cellAttributes: {alignment: 'left'},
        typeAttributes: {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        }
    },
    {
        label: 'Status',
        fieldName: 'sfims__Status__c',
        sortable: true,
        cellAttributes: {alignment: 'left'}
    },
    {
        label: 'Total Expected',
        fieldName: 'sfims__Total_Expected__c',
        type: 'currency',
        sortable: true,
        cellAttributes: {alignment: 'left'}
    },
    {
        label: 'Principal Expected',
        fieldName: 'sfims__Principal_Expected__c',
        type: 'currency',
        sortable: true,
        editable: true,
        cellAttributes: {alignment: 'left'}
    },
    {
        label: 'Interest Expected',
        fieldName: 'sfims__Interest_Expected_Standard_Loan__c',
        type: 'currency',
        sortable: true,
        editable: true,
        cellAttributes: {alignment: 'left'}
    },
    {
        label: 'Interest Rate',
        fieldName: 'sfims__Interest_Rate__c',
        type: 'text',
        sortable: true,
        editable: true,
        cellAttributes: {alignment: 'left'}
    },
    {
        label: 'Fees Expected',
        fieldName: 'sfims__Fees_Expected__c',
        type: 'currency',
        sortable: true,
        editable: true,
        cellAttributes: {alignment: 'left'}
    }
    /* {
        type: 'action',
        typeAttributes: {rowActions: actions},
    } */
];

export default class lwcLoanScheduleEditor extends LightningElement {
    @api isDebugLog = false;
    debugLogStyle = 'background: green; color: white;';

    @api recordId;
    @track columns = columns;
    @track data;
    @track draftValues = [];
    @track count = 0;

    connectedCallback() {
        this.isDebugLog = true;
        this.begin('initialization');
        let that = this;
        this.columns.forEach(function (column) {
            if (column.fieldName) {
                that.sortFields[column.fieldName] = column;
            }
        });
        this.end();
    }

    selectedRows;
    @track selectedRowsCount = 0;

    handleGetSelectedRows(event) {
        this.begin('handleGetSelectedRows');
        this.log(event.detail);
        this.selectedRows = event.detail.selectedRows;
        this.selectedRowsCount = this.selectedRows.length;
        this.end();
    }

    sortFields = {};
    @track sortFieldLabel = 'Repayment Schedule Number';
    @track sortBy;
    @track sortDirection;

    errorCallback(error, stack) {
        this.begin('errorCallback');
        this['template'].querySelector('c-lwc-utility-message').showErrorMessage('An error occurred during the execution of JavaScript.');
        console.error(JSON.stringify(error));
        this.end();
    }

    handleSort(event) {
        this.begin('handleSort');
        if (event && event.detail) {
            this.log(event.detail);
            this.sortBy = event.detail.fieldName;
            this.sortDirection = event.detail.sortDirection;
            if (this.sortFields.hasOwnProperty(this.sortBy)) {
                this.sortFieldLabel = this.sortFields[this.sortBy].label;
            }
        }
        if (this.sortBy && this.sortDirection) {
            this.sortData(this.sortBy, this.sortDirection, this.sortFields[this.sortBy].type);
        }
        this.end();
    }

    sortData(fieldName, sortDirection, type) {
        this.begin('handleSort');
        let data = JSON.parse(JSON.stringify(this.data));
        let key = (a) => {
            return a[fieldName];
        };
        let reverse = sortDirection === 'asc' ? 1 : -1;
        // to handel number/currency/date fields
        let controlTypes = ['currency', 'date', 'date-local', 'numeric'];
        if (controlTypes.indexOf(type) !== -1) {
            data.sort((a, b) => {
                a = key(a) ? key(a) : '';
                b = key(b) ? key(b) : '';
                return reverse * ((a > b) - (b > a));
            });
        }
        else {
            // to handel text  fields
            data.sort((a, b) => {
                a = key(a) ? key(a).toLowerCase() : '';
                b = key(b) ? key(b).toLowerCase() : '';
                return reverse * ((a > b) - (b > a));
            });
        }
        this.data = data;
        this.end();
    }


    handleSave(event) {
        this.begin('handleSave');
        let spinner = this['template'].querySelector('c-lwc-utility-spinner').showSpinner();
        let that = this;
        this.log(event.detail);
        const recordInputs = event.detail.draftValues.slice().map(draft => {
            const fields = Object.assign({}, draft);
            return {fields};
        });
        this.log(recordInputs);
        const promises = recordInputs.map(recordInput => updateRecord(recordInput));
        Promise.all(promises).then(schedules => {
            that['template'].querySelector('c-lwc-utility-message').showSuccessMessage('Your changes are saved.');
            that.fetchData();
            that['template'].querySelector('c-lwc-utility-spinner').hideSpinner(spinner);
        }).catch(error => {
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
        });
        this.end();
    }

    fetchData() {
        this.begin('fetchData');
        let spinner = this['template'].querySelector('c-lwc-utility-spinner').showSpinner();
        this.log('loan id', this.recordId);
        let that = this;
        if (!this.recordId) {
            this['template'].querySelector('c-lwc-utility-message').showErrorMessage('The Loan Id was not received.');
            this['template'].querySelector('c-lwc-utility-spinner').hideSpinner(spinner);
            this.end();
            return;
        }
        let params = {
            loanId: this.recordId,
            isDebugLog: this.isDebugLog
        };
        getSchedules(params)
            .then(data => {
                that.begin('currentRecord-SUCCESS');
                if (!data) {
                    that['template'].querySelector('c-lwc-utility-message').showErrorMessage('The Data were not received.');
                    that['template'].querySelector('c-lwc-utility-spinner').hideSpinner(spinner);
                    that.end();
                    return;
                }
                data.forEach(function (item) {
                    item.sfims__Interest_Rate__c = item.sfims__Interest_Rate__c.toString() + '%';
                });
                that.log('schedules', data);
                that.draftValues = [];
                that.data = data;
                that.count = data.length;
                if (that.count === 0) {
                    that['template'].querySelector('c-lwc-utility-message').showWarningMessage('Please Generate Schedule at the beginning.');
                }
                that['template'].querySelector('c-lwc-redefine-data-table').selectedRows = [];
                that.selectedRowsCount = 0;
                that.handleSort();
                that['template'].querySelector('c-lwc-utility-spinner').hideSpinner(spinner);
                that.end();
            })
            .catch(error => {
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
            });
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