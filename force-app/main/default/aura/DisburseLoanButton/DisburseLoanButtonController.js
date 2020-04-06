({
    doInit: function (cmp, event, helper) {
        console.group('%s, time: %f', 'doInit', helper.timeStamp());
        helper.showSpinner(cmp, 'v.isLoading', 40000, 'doInit');
        let rowActions = helper.getRowActions.bind(this, cmp);
        cmp.set('v.columns', [
            {
                label: $A.get("$Label.c.aura_label_102"),
                fieldName: 'sfims__Transaction_Date__c',
                type: 'date-local',
                fixedWidth: 300,
                cellAttributes: {
                    alignment: 'left'
                },
            },
            {
                label: $A.get("$Label.c.aura_label_103"),
                fieldName: 'sfims__Status__c',
                type: 'text',
                // fixedWidth: 140,
                cellAttributes: {
                    alignment: 'left'
                },
            },
            {
                label: $A.get("$Label.c.aura_label_104"),
                fieldName: 'sfims__Amount__c',
                type: 'currency',
                // fixedWidth: 136,
                cellAttributes: {
                    alignment: 'left'
                },
                typeAttributes: {
                    minimumFractionDigits: 2
                }
            },
            {
                type: 'action',
                fixedWidth: 60,
                typeAttributes: {rowActions: rowActions}
            }
        ]);
        console.groupEnd();
    },

    handleRecordUpdated: function (cmp, event, helper) {
        console.group('%s, time: %f', 'handleRecordUpdated', helper.timeStamp());
        let eventParams = event.getParams();
        helper.hideSpinner(cmp, 'v.isLoading', 'doInit');
        if (eventParams['changeType'] === 'LOADED') {
            helper.fetchData(cmp);
        } else if (eventParams['changeType'] === 'ERROR') {
            helper.showErrMessage($A.get("$Label.c.js_error_message_1"));
            helper.cancel(cmp);
        }
        console.groupEnd();
    },

    newTransaction: function (cmp, event, helper) {
        console.log('%s, time: %f', 'newTransaction', helper.timeStamp());
        cmp.set('v.amount', '');
        cmp.set('v.transactionDate', '');
        cmp.set('v.status', 'None');
        // open popup
        cmp.set('v.showPopup', true);
        cmp.set('v.showAddButton', true);
        // set attributes
        cmp.set('v.title', $A.get("$Label.c.aura_label_105"));
    },

    updateTransaction: function (cmp, event, helper) {
        console.log('%s, time: %f', 'updateTransaction', helper.timeStamp());
        if (cmp.find('disburseLoanUtilCmp').validationForm()) {
            let amount = cmp.get('v.amount');
            let transactionDate = cmp.get('v.transactionDate');
            let status = cmp.get('v.status');
            let transactions = cmp.get('v.transactions');
            let selectedRow = cmp.get('v.selectedRow')
            let rowIndex = transactions.indexOf(selectedRow);
            if (rowIndex !== -1) {
                transactions[rowIndex]['sfims__Amount__c'] = amount;
                transactions[rowIndex]['sfims__Transaction_Date__c'] = transactionDate;
                transactions[rowIndex]['sfims__Status__c'] = status;
            }
            cmp.set('v.transactions', transactions);
            // set a new total of amounts
            cmp.set('v.disbursementAmount', Number(cmp.get('v.disbursementAmount')) + Number(amount));
            cmp.set('v.showButtons', true);
            // close popup
            cmp.set('v.showPopup', false);
            cmp.set('v.showUpdateButton', false);
        }
    },

    addTransaction: function (cmp, event, helper) {
        console.log('%s, time: %f', 'addTransaction', helper.timeStamp());
        if (cmp.find('disburseLoanUtilCmp').validationForm()) {
            let amount = cmp.get('v.amount');
            let transactionDate = cmp.get('v.transactionDate');
            let status = cmp.get('v.status');
            let transactions = cmp.get('v.transactions');
            let row = {};
            // create a new transaction	and add it to data
            row['sfims__Amount__c'] = amount;
            row['sfims__Transaction_Date__c'] = transactionDate;
            row['sfims__Status__c'] = status;
            row['sfims__Investment__c'] = cmp.get('v.simpleRecord').Id;
            row['sfims__Type__c'] = 'Disbursement';
            transactions.push(row);
            cmp.set('v.transactions', transactions);
            // set a new total of amounts
            cmp.set('v.disbursementAmount', Number(cmp.get('v.disbursementAmount')) + Number(amount));
            cmp.set('v.showButtons', true);
            //close popup
            cmp.set('v.showPopup', false);
            cmp.set('v.showAddButton', false);
        }
    },

    handleRowAction: function (cmp, event, helper) {
        console.group('%s, time: %f', 'handleRowAction', helper.timeStamp());
        let action = event.getParam('action');
        let row = event.getParam('row');
        cmp.set('v.selectedRow', row);
        switch (action['name']) {
            case 'edit':
                helper.editTransaction(cmp, event);
                break;
            case 'delete':
                helper.showModalDeleteTransaction(cmp);
                break;
        }
        console.groupEnd();
    },

    handleShowModalDeleteTransaction: function (cmp, event, helper) {
        console.group('%s, time: %f', 'handleShowModalDeleteTransaction', helper.timeStamp());
        helper.showModalDeleteTransaction(cmp);
        console.groupEnd();
    },

    handleCloseModalDeleteTransaction: function (cmp, event, helper) {
        console.group('%s, time: %f', 'handleCloseModalDeleteTransaction', helper.timeStamp());
        helper.closeModalDeleteTransaction(cmp);
        console.groupEnd();
    },

    handleDeleteTransaction: function (cmp, event, helper) {
        console.group('%s, time: %f', 'handleDeleteTransaction', helper.timeStamp());
        helper.deleteTransaction(cmp);
        helper.closeModalDeleteTransaction(cmp);
        console.groupEnd();
    },

    closePopup: function (cmp, event, helper) {
        console.log('%s, time: %f', 'closePopup', helper.timeStamp());
        cmp.set('v.showPopup', false);
        cmp.set('v.showAddButton', false);
        cmp.set('v.showUpdateButton', false);
    },

    openPreview: function (cmp, event, helper) {
        console.group('%s, time: %f', 'openPreview', helper.timeStamp());
        // cmp.set('v.showError', false);
        let transactionsForPreview = JSON.parse(JSON.stringify(cmp.get('v.transactions')));
        helper.runPreview(cmp, transactionsForPreview);
        console.groupEnd();
    },

    openPreviewWithPlanned: function (cmp, event, helper) {
        console.group('%s, time: %f', 'openPreviewWithPlanned', helper.timeStamp());
        // helper.showSpinner(cmp, 'v.spinner');
        //  if (cmp.find('disburseLoanUtilCmp').validationForm()) {
        let transactionsForPreview = JSON.parse(JSON.stringify(cmp.get('v.transactions')));
        for (let tr in transactionsForPreview) {
            if (transactionsForPreview.hasOwnProperty(tr)) {
                if (transactionsForPreview[tr]['sfims__Status__c'] === 'Planned') {
                    transactionsForPreview[tr]['sfims__Status__c'] = 'Disbursed';
                }
            }
        }
        helper.runPreview(cmp, transactionsForPreview);
        // }
        console.groupEnd();
    },

    openPreviewFullDisbursement: function (cmp, event, helper) {
        console.group('%s, time: %f', 'openPreviewFullDisbursement', helper.timeStamp());
        helper.runPreviewFullDisbursement(cmp, false);
        console.groupEnd();
    },

    openPreviewWithPlannedFullDisbursement: function (cmp, event, helper) {
        console.group('%s, time: %f', 'openPreviewWithPlannedFullDisbursement', helper.timeStamp());
        helper.runPreviewFullDisbursement(cmp, true);
        console.groupEnd();
    },

    saveTransaction: function (cmp, event, helper) {// for the 'Full disbursement at start' type of the Disbursement method
        console.group('%s, time: %f', 'saveTransaction', helper.timeStamp());
        // cmp.set('v.showError', false);
        if (cmp.find('disburseLoanUtilCmp').validationForm()) {
            let rec = cmp.get('v.simpleRecord'),
                transactions = cmp.get('v.transactions');
            console.log(transactions.length);
            transactions = helper.formTransaction(cmp, transactions);
            // check if the Disbursement Date on a loan corresponds the Transaction Date on the transaction record related to this loan
            if (rec['sfims__Disbursement_Date__c'] !== transactions[0]['sfims__Transaction_Date__c'] 
                && transactions[0]['sfims__Status__c'] === 'Disbursed' && !cmp.get('v.showWarning')) {
                // warn that with saving the Disbursement Date on the loan will be changed
                // if (status === 'Planned') {
                cmp.set('v.showWarning', true);
                helper.showWarningMessage($A.get("$Label.c.js_warning_message_1"));
                //helper.cancel(cmp);
                // }
                return;
            }
            console.log('after warning');
            // status of the Transaction should become 'Disbursed'
            // transactions[0]['sfims__Status__c'] = 'Disbursed';
            helper.saveTransactions(cmp, transactions);
        }
        console.groupEnd();
    },

    saveTransactions: function (cmp, event, helper) {// for the 'Tranched disbursement allowed' type of the Disbursement method
        console.group('%s, time: %f', 'saveTransactions', helper.timeStamp());
        // cmp.set('v.showError', false);
        helper.saveTransactions(cmp, cmp.get('v.transactions'));
        console.groupEnd();
    },

    handleCancel: function (cmp, event, helper) {
        console.log('%s, time: %f', 'handleCancel', helper.timeStamp());
        helper.cancel(cmp);
    }
});