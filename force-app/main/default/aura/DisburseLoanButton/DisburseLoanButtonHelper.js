({
    fetchData: function (cmp) {
        console.group('%s, time: %f', 'fetchData', this.timeStamp());
        // let today = $A.localizationService.formatDate(new Date(), 'YYYY-MM-DD');
        //cmp.set('v.today', today);
        if (!$A.util.isEmpty(cmp.get('v.recordId'))) {
            let that = this;
            let spinner = this.showSpinner(cmp, 'v.isLoading');
            let action = cmp.get('c.getDisbursementTransactions');
            action.setParams({
                loanId: cmp.get('v.recordId')
            });
            action.setCallback(this, function (response) {
                let state = response.getState();
                if (state === 'SUCCESS') {
                    console.group('%s, time: %f', 'fetchData-SUCCESS', that.timeStamp());
                    let rec = cmp.get('v.simpleRecord');
                    let transactions = response.getReturnValue();
                    cmp.set('v.JSONtransactionsOld', JSON.stringify(transactions));
                    cmp.set('v.transactions', transactions);
                    // set up data for the 'Full disbursement at start' type of the Disbursement method
                    if (rec['sfims__Disbursement_Method__c'] === 'Full disbursement at start') {
                        if (rec['sfims__Setup_Fee_Charging_Method__c'] === 'Deducted From Principal') {
                            cmp.set('v.amount', rec['sfims__Amount__c'] - rec['sfims__Setup_Fee_Expected__c']);
                        } else {
                            cmp.set('v.amount', rec['sfims__Amount__c']);
                        }
                        if (response.getReturnValue().length > 0) {
                            cmp.set('v.transactionDate', transactions[0]['sfims__Transaction_Date__c']);
                            cmp.set('v.status', transactions[0]['sfims__Status__c']);
                        } else {
                            cmp.set('v.transactionDate', rec['sfims__Disbursement_Date__c']);
                            cmp.set('v.status', 'Disbursed');
                        }
                    }
                    // set up data for the 'Tranched disbursement allowed' type of the Disbursement method
                    if (rec['sfims__Disbursement_Method__c'] === 'Tranched disbursement allowed') {
                        // sum the amounts of the transactions with the type 'Disbursement' associated with the current Loan
                        let disbursementAmount = 0;
                        for (let tr in transactions) {
                            if (transactions.hasOwnProperty(tr)) {
                                disbursementAmount += transactions[tr]['sfims__Amount__c'];
                            }
                        }
                        cmp.set('v.disbursementAmount', disbursementAmount);
                        // check that the total of amounts is not higher than the Loan Amount
                        let maxAmountToDisburse = 0;
                        if (rec['sfims__Setup_Fee_Charging_Method__c'] === 'Deducted From Principal') {
                            maxAmountToDisburse = rec['sfims__Amount__c'] - rec['sfims__Setup_Fee_Expected__c'];
                        } else {
                            maxAmountToDisburse = rec['sfims__Amount__c'];
                        }
                        cmp.set('v.maxAmountToDisburse', maxAmountToDisburse);
                        if (disbursementAmount > maxAmountToDisburse) {
                            // if not, make control buttons invisible and show a message
                            cmp.set('v.showButtons', false);
                        }
                    }

                    // Full disbursement at start
                    if (rec['sfims__Disbursement_Method__c'] === 'Full disbursement at start') {
                        let status = cmp.get('v.status');
                        if (transactions.length > 0 && status === 'Disbursed') {
                            that.showWarningMessage($A.get("$Label.c.js_warning_message_2"));
                            that.cancel(cmp);
                        }
                    }
                    // 'Tranched disbursement allowed'
                    if (rec['sfims__Disbursement_Method__c'] === 'Tranched disbursement allowed') {
                        if (!cmp.get('v.showButtons')) {
                            that.showErrMessage($A.get("$Label.c.error_message_18"));
                            that.cancel(cmp);
                        }
                    }
                    cmp.set('v.isDisplayForm', true);

                    console.groupEnd();
                }
                else {
                    let errors = response.getError();
                    that.log('errors', errors);
                    that.showErrMessage(that.getErrMessage(errors));
                    that.cancel(cmp);
                }
                that.hideSpinner(cmp, 'v.isLoading', spinner);
            });
            $A.enqueueAction(action);
        }
        else {
            this.showErrMessage($A.get("$Label.c.js_error_message_3"));
            this.cancel(cmp);
        }
        console.groupEnd();
    },

    getRowActions: function (cmp, row, doneCallback) {
        let actions = [];
        let editAction = {
            'label': $A.get("$Label.c.aura_label_57"),
            'iconName': 'utility:edit',
            'name': 'edit'
        };
        if (row['sfims__Status__c'] === 'Disbursed') {
            editAction['disabled'] = 'true';
        }
        actions.push(editAction);
        let deleteAction = {
            'label': $A.get("$Label.c.aura_label_13"),
            'iconName': 'utility:delete',
            'name': 'delete'
        };
        actions.push(deleteAction);
        setTimeout($A.getCallback(function () {
            doneCallback(actions);
        }), 10);
    },

    formTransaction: function (cmp, transactions) {
        console.log('%s, time: %f', 'formTransaction', this.timeStamp());
        if (transactions.length === 0) {
            let transaction = {};
            transaction['sfims__Amount__c'] = cmp.get('v.amount');
            transaction['sfims__Transaction_Date__c'] = cmp.get('v.transactionDate');
            transaction['sfims__Investment__c'] = cmp.get('v.simpleRecord')['Id'];
            transaction['sfims__Type__c'] = 'Disbursement';
            transaction['sfims__Status__c'] = cmp.get('v.status');
            transactions.push(transaction);
        } else {
            transactions[0]['sfims__Transaction_Date__c'] = cmp.get('v.transactionDate');
            transactions[0]['sfims__Status__c'] = cmp.get('v.status');
        }
        return transactions;
    },

    runPreviewFullDisbursement: function (cmp, withPlanned) {
        let isValid = true;
        if (cmp.get('v.simpleRecord').sfims__Disbursement_Method__c === 'Full disbursement at start') {
            isValid = cmp.find('disburseLoanUtilCmp').validationForm();
        }

        if (isValid) {
            let transactionsForPreview = JSON.parse(JSON.stringify(cmp.get('v.transactions')));
            transactionsForPreview = this.formTransaction(cmp, transactionsForPreview);
            if (withPlanned) transactionsForPreview[0]['sfims__Status__c'] = 'Disbursed';
            this.log('transactionsForPreview', transactionsForPreview);
            this.runPreview(cmp, transactionsForPreview);
        }
    },

    runPreview: function (cmp, transactionsForPreview) {
        console.group('%s, time: %f', 'runPreview', this.timeStamp());
        let that = this;
        let spinner = this.showSpinner(cmp, 'v.isLoading');
        let action = cmp.get('c.generateSchedulePreview'),
            rec = cmp.get('v.simpleRecord');
        action.setParams({
            'loanId': rec['Id'],
            'JSONtransactionsNew': JSON.stringify(transactionsForPreview),
            'JSONtransactionsOld': cmp.get('v.JSONtransactionsOld')
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                console.group('%s, time: %f', 'fetchData-SUCCESS', that.timeStamp());
                let status = response.getReturnValue();
                console.log(status);
                if (status['toInsert']) {
                    if (status['variableInterest']) that.showWarningMessage(status['variableInterest']);
                    let records = JSON.parse(status['toInsert']);
                    console.log(records);
                    for (let rs in records) {
                        if (records.hasOwnProperty(rs)) {
                            let interestExpected = 0;
                            if (rec['sfims__Open_Ended_Loan__c']) {
                                interestExpected = Number(records[rs]['sfims__Interest_Expected_On_Last_Paid_Date__c']);
                            } else {
                                interestExpected = Number(records[rs]['sfims__Interest_Expected_Standard_Loan__c']);
                            }
                            records[rs]['sfims__Interest_Expected__c'] = interestExpected;
                            records[rs]['sfims__Total_Expected__c'] = Number(records[rs]['sfims__Principal_Expected__c']) + interestExpected + Number(records[rs]['sfims__Fees_Expected__c']);
                        }
                    }
                    console.log(records);
                    cmp.set('v.showPreview', true);
                    cmp.set('v.repaymentSchedules', records);
                    cmp.set('v.previewColumns', [
                        {label: $A.get("$Label.c.aura_label_106"), fieldName: 'sfims__Due_Date__c', type: 'date-local'},
                        {
                            label: $A.get("$Label.c.aura_label_107"),
                            fieldName: 'sfims__Total_Expected__c',
                            type: 'currency',
                            typeAttributes: {minimumFractionDigits: '2'}
                        },
                        {
                            label: $A.get("$Label.c.aura_label_108"),
                            fieldName: 'sfims__Principal_Expected__c',
                            type: 'currency',
                            typeAttributes: {minimumFractionDigits: '2'}
                        },
                        {
                            label: $A.get("$Label.c.aura_label_109"),
                            fieldName: 'sfims__Interest_Expected__c',
                            type: 'currency',
                            typeAttributes: {minimumFractionDigits: '2'}
                        },
                        {
                            label: $A.get("$Label.c.aura_label_110"),
                            fieldName: 'sfims__Fees_Expected__c',
                            type: 'currency',
                            typeAttributes: {minimumFractionDigits: '2'}
                        }
                    ]);
                } else if (status['error']) {
                    cmp.set('v.showPreview', false);
                    cmp.set('v.repaymentSchedules', []);
                    that.showErrMessage(status['error']);
                }
                console.groupEnd();
            }
            else {
                let errors = response.getError();
                that.log('errors', errors);
                that.showErrMessage(that.getErrMessage(errors));
                // that.cancel(cmp);
            }
            that.hideSpinner(cmp, 'v.isLoading', spinner);
        });
        $A.enqueueAction(action);
        console.groupEnd();
    },

    saveTransactions: function (cmp, newTransactions) {
        console.group('%s, time: %f', 'saveTransactions', this.timeStamp());
        // let today = $A.localizationService.formatDate(new Date(), 'YYYY-MM-DD');
        // cmp.set('v.today', today);
        let that = this;
        let spinner = this.showSpinner(cmp, 'v.isLoading');
        let action = cmp.get('c.saveData');
        action.setParams({
            'loanId': cmp.get('v.simpleRecord').Id,
            'JSONtransactionsNew': JSON.stringify(newTransactions),
            'JSONtransactionsOld': cmp.get('v.JSONtransactionsOld')
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                console.group('%s, time: %f', 'fetchData-SUCCESS', that.timeStamp());
                let status = response.getReturnValue();
                console.log(status);
                if (status['success']) {
                    that.showSuccessMessage(status['success']);
                    $A.get('e.force:refreshView').fire();
                    that.cancel(cmp);
                } else if (status['error']) {
                    that.showErrMessage(status['error']);
                }
                console.groupEnd();
            }
            else {
                let errors = response.getError();
                that.log('errors', errors);
                that.showErrMessage(that.getErrMessage(errors));
                // that.cancel(cmp);
            }
            that.hideSpinner(cmp, 'v.isLoading', spinner);
        });
        $A.enqueueAction(action);
        console.groupEnd();
    },

    showModalDeleteTransaction: function (cmp) {
        console.group('%s, time: %f', 'deleteTransaction', this.timeStamp());
        this.showModal(cmp, 'v.showDeletePopup');
        console.groupEnd();
    },

    closeModalDeleteTransaction: function (cmp) {
        console.group('%s, time: %f', 'deleteTransaction', this.timeStamp());
        this.closeModal(cmp, 'v.showDeletePopup');
        console.groupEnd();
    },

    deleteTransaction: function (cmp) {
        console.group('%s, time: %f', 'deleteTransaction', this.timeStamp());
        let row = cmp.get('v.selectedRow'),
            rows = cmp.get('v.transactions');
        let rowIndex = rows.indexOf(row);
        rows.splice(rowIndex, 1);
        this.showSuccessMessage($A.get("$Label.c.js_success_message_1"));
        cmp.set('v.transactions', rows);
        if (rows.length > 0) {
            cmp.set('v.disbursementAmount', Number(cmp.get('v.disbursementAmount')) - Number(row['sfims__Amount__c']));
        } else {
            cmp.set('v.disbursementAmount', 0);
        }
        console.groupEnd();
    },

    editTransaction: function (cmp, event) {
        console.log('%s, time: %f', 'editTransaction', this.timeStamp());
        // set attributes
        let row = event.getParam('row');
        cmp.set('v.title', 'Edit Transaction');
        cmp.set('v.amount', row['sfims__Amount__c']);
        cmp.set('v.transactionDate', row['sfims__Transaction_Date__c']);
        cmp.set('v.status', row['sfims__Status__c']);
        // count the total of transactions amount without the record that has been called to update
        let transactions = cmp.get('v.transactions');
        let disbursementAmount = 0;
        let rowIndex = transactions.indexOf(row);
        for (let tr in transactions) {
            if (Number(tr) !== rowIndex) {
                if (transactions.hasOwnProperty(tr)) {
                    disbursementAmount += Number(transactions[tr]['sfims__Amount__c']);
                }
            }
        }
        cmp.set('v.disbursementAmount', disbursementAmount);
        // throw a validation error if the total of amounts with the amount of record to update is higher than the Loan Amount
        if (!cmp.get('v.showButtons', false)) {
            //cmp.set('v.validationAmountError', true);
            this.showErrMessage($A.get("$Label.c.error_message_18"));
            this.cancel(cmp);
        }
        // open popup
        cmp.set('v.showPopup', true);
        cmp.set('v.showUpdateButton', true);
    },

    showSpinner: function (cmp, attribute, delay, timeStamp) {
        timeStamp = timeStamp || new Date().getTime();
        console.log('%s, attribute: %s, timeStamp: %s, time: %f', 'showSpinner', attribute, timeStamp, this.timeStamp());
        delay = delay || 40000;
        let spinners = cmp.get('v.spinners');
        let size = spinners.length;
        let flag = false;
        for (let i = 0; i < size; i++) {
            if (spinners[i].attribute === attribute) {
                spinners[i].timeStamp.push(timeStamp);
                flag = true;
                break;
            }
        }
        if (!flag) {
            spinners.push({
                'attribute': attribute,
                'timeStamp': [timeStamp]
            });
        }
        let that = this;
        window.setTimeout(
            $A.getCallback(function () {
                that.hideSpinner(cmp, attribute, timeStamp);
            }), delay);
        cmp.set(attribute, true);
        cmp.set('v.spinners', spinners);
        return timeStamp;
    },
        
    hideSpinner: function (cmp, attribute, timeStamp) {
        console.log('%s, attribute: %s, timeStamp: %s, time: %f', 'hideSpinner', attribute, timeStamp, this.timeStamp());
        let spinners = cmp.get('v.spinners');
        if (spinners) {
            let size = spinners.length;
            for (let i = 0; i < size; i++) {
                if (spinners[i].attribute === attribute) {
                    let elements = spinners[i].timeStamp;
                    let index = elements.indexOf(timeStamp);
                    if (index !== -1) {
                        if (elements.length === 1) {
                            cmp.set(attribute, false);
                        }
                        elements.splice(index, 1);
                    }
                    break;
                }
            }
            cmp.set('v.spinners', spinners);
        }
    },

    getErrMessage: function (errors) {
        console.log('%s, time: %f', 'getErrMessage', this.timeStamp());
        let message = $A.get("$Label.c.js_error_message_5");
        if (errors && Array.isArray(errors) && errors.length > 0) {
            let msgErrors = '';
            errors.forEach(function (err) {
                if (err.hasOwnProperty('message')) {
                    msgErrors += err.message + '\n';
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
        return message;
    },

    cancel: function (cmp, isRedirect) {
        console.group('%s, time: %f', 'cancel', this.timeStamp());
        isRedirect = isRedirect || false;
        if (cmp.get('v.isRunning')) {
            this.closeModal(cmp, 'v.isRunning');
        } else {
            if (isRedirect) {
                if (!cmp.get('v.recordId')) {
                    this.navigateToObjectHome();
                } else {
                    this.navigateToSObject(cmp, cmp.get('v.recordId'));
                }
            } else {
                //this.closeQuickAction();
                this.closeOverlayLib(cmp);
                // $A.get('e.force:refreshView').fire();
            }
        }
        console.groupEnd();
    },

    navigateToSObject: function (cmp, recordId) {
        console.log('%s, time: %f', 'navigateToSObject', this.timeStamp());
        let record = recordId || cmp.get('v.recordId');
        let navEvt = $A.get('e.force:navigateToSObject');
        navEvt.setParams({
            'recordId': record
        });
        navEvt.fire();
    },

    navigateToObjectHome: function () {
        console.log('%s, time: %f', 'navigateToObjectHome', this.timeStamp());
        let homeEvt = $A.get('e.force:navigateToObjectHome');
        homeEvt.setParams({
            'scope': 'sfims__Loan_Product__c'
        });
        homeEvt.fire();
    },

    elementValidationStandard: function (cmp, element, label) {
        console.log('%s, time: %f, %s', 'elementValidationStandard', this.timeStamp(), element);
        let item = cmp.find(element);
        item.showHelpMessageIfInvalid();
        let isValid = item.get('v.validity').valid;
        if (!isValid) {
            this['errFields'].push(label);
        }
        return isValid;
    },

    elementValidation: function (cmp, element, label) {
        console.log('%s, time: %f, %s', 'elementValidation', this.timeStamp(), element);
        let response = true;
        let item = cmp.find(element);
        if (!$A.util.isEmpty(item)) {
            if ($A.util.isEmpty(item.get('v.value'))) {
                $A.util.addClass(item, 'error');
                $A.util.addClass(item, 'slds-has-error');
                if (label) {
                    this['errFields'].push(label);
                }
                response = false;
            } else {
                $A.util.removeClass(item, 'error');
                $A.util.removeClass(item, 'slds-has-error');
            }
        } else {
            this.showErrMessage($A.get("$Label.c.part_of_js_error_message_1") + ' "' + element + '" ' + $A.get("$Label.c.part_of_js_error_message_2") + '.');
        }
        return response;
    },

    formValidation: function (cmp, fields) {
        console.group('%s, time: %f', 'formValidation', this.timeStamp());
        // this['errFields'] = [];
        let response = true;
        let that = this;
        fields.forEach(function (field) {
            if (!that.elementValidation(cmp, field.name, field.label)) {
                response = false;
            }
        });
        console.groupEnd();
        return response;
    },

    trim: function (str) {
        return str.replace(/^\s+|\s+$/g, '');
    },

    showModal: function (cmp, attribute) {
        console.log('%s, time: %f', 'showModal', this.timeStamp());
        cmp.set(attribute, true);
    },

    closeModal: function (cmp, attribute) {
        console.log('%s, time: %f', 'closeModal', this.timeStamp());
        cmp.set(attribute, false);
    },

    closeQuickAction: function () {
        console.log('%s, time: %f', 'closeQuickAction', this.timeStamp());
        $A.get('e.force:closeQuickAction').fire();
    },

    closeOverlayLib: function (cmp) {
        console.log('%s, time: %f', 'closeOverlayLib', this.timeStamp());
        let overlayLib = cmp.find('overlayLib');
        if (overlayLib) {
            overlayLib.notifyClose();
        } else {
            this.showErrMessage($A.get("$Label.c.js_error_message_6"));
        }
    },

    log: function (label, values, style) {
        let consoleStyles = {
            'h1': 'font: 2.5em/1 Arial; color: crimson;',
            'h2': 'font: 2em/1 Arial; color: orangered;',
            'h3': 'font: 1.5em/1 Arial; color: olivedrab;',
            'bold': 'font: bold 1.3em/1 Arial; color: midnightblue;',
            'warn': 'padding: 0 .5rem; background: crimson; font: 1.6em/1 Arial; color: white;'
        };
        style = style || 'background: blue; color: white;';
        if (Array.isArray(values)) {
            console.log('%c' + label, style);
            console.log(values);
        } else if (typeof values === 'object') {
            console.log('%c' + label, style);
            console.log(JSON.parse(JSON.stringify(values)));
        } else {
            console.log('%c' + label + ' - ' + values, style);
        }
    },

    timeStamp: function () {
        return 0 // performance.now() / 1000;
    },

    showErrMessage: function (message, title) {
        console.log('%s, time: %f', 'showErrMessage', this.timeStamp());
        this.showMessage(title, message, 'error', 10000);
    },

    showSuccessMessage: function (message, title) {
        console.log('%s, time: %f', 'showSuccessMessage', this.timeStamp());
        this.showMessage(title, message, 'success');
    },

    showWarningMessage: function (message, title) {
        console.log('%s, time: %f', 'showWarningMessage', this.timeStamp());
        this.showMessage(title, message, 'warning');
    },

    showMessage: function (title, message, type, duration, mode) {
        console.log('%s, time: %f', 'showMessage', this.timeStamp());
        duration = duration || (type === 'error') ? 6000 : 3000;
        mode = mode || 'disptable';
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
        let toast = $A.get('e.force:showToast');
        if (toast !== undefined) {
            toast.setParams({
                'title': title,
                'message': message,
                'type': type,
                'mode': mode,
                'duration': duration
            });
            toast.fire();
        }
        else {
            alert(message);
        }
    }
});