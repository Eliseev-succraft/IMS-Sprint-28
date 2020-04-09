({
    doInit: function (cmp, event, helper) {
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['debugLogStyle'] = 'background: green; color: white;';
        helper.begin('doInit');
        helper.log('initialization');
        let today = $A.localizationService.formatDate(new Date(), "YYYY-MM-DD");
        cmp.set('v.transactionDate', today);
        helper.end();
    },

    handleChangeCustomValidityMessage: function (cmp, event, helper) {
        helper.begin('handleChangeCustomValidityMessage');
        cmp.set('v.isReloadCustomMessage', false);
        cmp.set('v.isReloadCustomMessage', true);
        helper.end();
    },

    handleEventUpdateModals: function (cmp, event, helper) {
        helper.begin('handleEventUpdateModals');
        if (event.getParam('modals')) {
            cmp.set('v.modals', JSON.parse(event.getParam('modals')));
        }
        helper.end();
    },

    handleNext: function (cmp, event, helper) {
        helper.begin('handleNext');
        let from = cmp.find('from');
        let to = cmp.find('to');
        from.validation();
        to.validation();
        let err = [];
        if (!from.get('v.isValid')) {
            err.push('From');
        }
        if (!to.get('v.isValid')) {
            err.push('To');
        }
        if (err.length === 0) {
            let today = $A.localizationService.formatDate(new Date(), "YYYY-MM-DD");
            cmp.set('v.transactionDate', today);
            let from = cmp.get('v.from');
            let fromId;
            if (from.hasOwnProperty('fields')) {
                if (from.fields.hasOwnProperty('Id')) {
                    fromId = from.fields.Id;
                }
            }
            let to = cmp.get('v.to');
            let toId;
            if (to.hasOwnProperty('fields')) {
                if (to.fields.hasOwnProperty('Id')) {
                    toId = to.fields.Id;
                }
                helper['sfims__Principal_Remaining__c'] = to.fields.sfims__Principal_Remaining__c;
                if (to.fields.hasOwnProperty('sfims__Principal_Remaining__c')) {
                    cmp.set('v.amount', helper['sfims__Principal_Remaining__c']);
                }
            }
            if (fromId === toId && toId !== null) {
                cmp.find('message').showErrorMessage('Loan From cannot be equal to Loan To.');
                helper.end();
                return;
            }
            cmp.find('modal').showModal('newTransaction');
        } else {
            cmp.find('message').showErrorMessage('These required fields must be completed: ' + err.join(', '));
        }
        helper.end();
    },

    handleSaveNewTransaction: function (cmp, event, helper) {
        helper.begin('handleSaveNewTransaction');
        cmp.set('v.customValidityMessage', $A.get('$Label.c.aura_label_64'));
        helper['errFields'] = [];
        let validationFields = [
            {name: 'transactionDate'},
            {name: 'amount'}
        ];
        validationFields.forEach(function (item) {
            if (!item.hasOwnProperty('label')) {
                item['label'] = cmp.find(item.name).get('v.label');
            }
        });
        let isValid = true;
        validationFields.forEach(function (field) {
            if (!helper.elementValidationCustom(cmp, field.name, field.label)) {
                isValid = false;
            }
        });
        if (!isValid) {
            if (helper['errFields']) {
                let err = [];
                for (let i = 0; i < helper['errFields'].length; i++) {
                    err.push(helper['errFields'][i].label);
                }
                cmp.find('message').showErrorMessage('These required fields must be completed: ' + err.join(', '));
            }
            helper.end();
            return;
        }
        // additional validations
        if (cmp.get('v.amount') > helper['sfims__Principal_Remaining__c']) {
            cmp.set('v.customValidityMessage', 'Amount cannot be more ' + helper['sfims__Principal_Remaining__c']);
            let amount = cmp.find('amount');
            $A.util.addClass(amount, 'error');
            $A.util.addClass(amount, 'slds-has-error');
            helper.end();
            return;
        } else {
            let amount = cmp.find('amount');
            $A.util.removeClass(amount, 'error');
            $A.util.removeClass(amount, 'slds-has-error');
        }
        helper.createTransferTransactions(cmp);
        helper.end();
    },

    handleCancelNewTransaction: function (cmp, event, helper) {
        helper.begin('handleCancelNewTransaction');
        cmp.find('modal').closeModal('newTransaction');
        helper.end();
    },


    handleCancel: function (cmp, event, helper) {
        helper.begin('handleCancel');
        helper.cancelFromOverlayLib(cmp);
        helper.end();
    },

    handleSectionClick: function (cmp, event, helper) {
        helper.begin('handleSectionClick');
        if (event.currentTarget.id) {
            cmp.set('v.sections.' + event.currentTarget.id, !cmp.get('v.sections')[event.currentTarget.id]);
        }
        helper.end();
    },

    handleChangeFrom: function (cmp, event, helper) {
        helper.begin('handleChangeFrom');
        let fromData = {
            LoanName: '',
            AccountName: '',
            LoanStatus: '',
            LoanProduct: '',
            DisbursementDate: '',
            DisbursedAmount: '',
            LoanBalance: ''
        };
        if (event.getParam('value')) {
            let row = event.getParam('value');
            helper.log(row);
            if (row.hasOwnProperty('fields')) {
                if (row.fields.hasOwnProperty('Id')) {
                    helper['fromLoanId'] = row.fields.Id;
                }
                if (row.fields.hasOwnProperty('Name')) {
                    fromData['LoanName'] = row.fields.Name;
                }
                if (row.fields.hasOwnProperty('sfims__Account__r')) {
                    if (row.fields.sfims__Account__r.hasOwnProperty('Name')) {
                        fromData['AccountName'] = row.fields.sfims__Account__r.Name;
                    }
                }
                if (row.fields.hasOwnProperty('sfims__Status__c')) {
                    fromData['LoanStatus'] = row.fields.sfims__Status__c;
                }
                if (row.fields.hasOwnProperty('sfims__Loan_Product__r')) {
                    if (row.fields.sfims__Loan_Product__r.hasOwnProperty('Name')) {
                        fromData['LoanProduct'] = row.fields.sfims__Loan_Product__r.Name;
                    }
                }
                if (row.fields.hasOwnProperty('sfims__Disbursement_Date__c')) {
                    fromData['DisbursementDate'] = row.fields.sfims__Disbursement_Date__c;
                }
                if (row.fields.hasOwnProperty('sfims__Disbursed_Amount__c')) {
                    fromData['DisbursedAmount'] = row.fields.sfims__Disbursed_Amount__c;
                }
                if (row.fields.hasOwnProperty('sfims__Available_Disbursement_Amount__c')) {
                    fromData['LoanBalance'] = row.fields.sfims__Available_Disbursement_Amount__c;
                }
                cmp.set('v.sections.FromLoanInformation', false);
                cmp.set('v.fromCustomValidity', '');
            }
        } else {
            cmp.set('v.sections.FromLoanInformation', true);
            cmp.set('v.fromCustomValidity', 'Complete this field');
        }
        cmp.set('v.fromData', fromData);
        helper.end();
    },

    handleChangeTo: function (cmp, event, helper) {
        helper.begin('handleChangeTo');
        let fromData = {
            LoanName: '',
            AccountName: '',
            LoanStatus: '',
            LoanProduct: '',
            DisbursementDate: '',
            DisbursedAmount: '',
            LoanBalance: ''
        };
        if (event.getParam('value')) {
            let row = event.getParam('value');
            helper.log(row);
            if (row.hasOwnProperty('fields')) {
                if (row.fields.hasOwnProperty('Id')) {
                    helper['toLoanId'] = row.fields.Id;
                }
                if (row.fields.hasOwnProperty('Name')) {
                    fromData['LoanName'] = row.fields.Name;
                }
                if (row.fields.hasOwnProperty('sfims__Account__r')) {
                    if (row.fields.sfims__Account__r.hasOwnProperty('Name')) {
                        fromData['AccountName'] = row.fields.sfims__Account__r.Name;
                    }
                }
                if (row.fields.hasOwnProperty('sfims__Status__c')) {
                    fromData['LoanStatus'] = row.fields.sfims__Status__c;
                }
                if (row.fields.hasOwnProperty('sfims__Loan_Product__r')) {
                    if (row.fields.sfims__Loan_Product__r.hasOwnProperty('Name')) {
                        fromData['LoanProduct'] = row.fields.sfims__Loan_Product__r.Name;
                    }
                }
                if (row.fields.hasOwnProperty('sfims__Disbursement_Date__c')) {
                    fromData['DisbursementDate'] = row.fields.sfims__Disbursement_Date__c;
                }
                if (row.fields.hasOwnProperty('sfims__Disbursed_Amount__c')) {
                    fromData['DisbursedAmount'] = row.fields.sfims__Disbursed_Amount__c;
                }
                if (row.fields.hasOwnProperty('sfims__Principal_Remaining__c')) {
                    fromData['LoanBalance'] = row.fields.sfims__Principal_Remaining__c;
                }
                cmp.set('v.sections.ToLoanInformation', false);
            }
        } else {
            cmp.set('v.sections.ToLoanInformation', true);
        }
        cmp.set('v.toData', fromData);
        helper.end();
    },
});