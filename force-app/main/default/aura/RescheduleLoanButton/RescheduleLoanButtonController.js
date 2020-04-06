({
    doInit: function (cmp, event, helper) {
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['debugLogStyle'] = 'background: green; color: white;';
        helper.begin('doInit');
        if (helper['isDebugLog'] === undefined) {
            cmp.find('message').showErrorMessage('The "isDebugLog" attribute was not found in the component markup.');
            helper.end();
            return;
        }
        helper.fetchData(cmp);
        helper.end();
    },

    handleChangeRescheduleAmount: function (cmp, event, helper) {
        helper.begin('handleChangeRescheduleAmount');
        let numberOfInstalments = cmp.find('numberOfInstalments');
        if (Number(cmp.get('v.rescheduleAmount')) === 0) {
            numberOfInstalments.set('v.min', 0);
            // numberOfInstalments.set('v.value', 0);
            numberOfInstalments.reportValidity();
        } else {
            numberOfInstalments.set('v.min', 1);
        }
        helper.end();
    },

    handleCancel: function (cmp, event, helper) {
        helper.begin('handleCancel');
        helper.cancelFromOverlayLib(cmp);
        helper.end();
    },

    handleNext: function (cmp, event, helper) {
        helper.begin('handleNext');
        helper.setRescheduleDate(cmp);
        let selectedType = cmp.get('v.default');
        if (selectedType) {
            cmp.set('v.selectedType', selectedType);
            if (selectedType === 'Manual Reschedule' && !cmp.get('v.access')) {
                cmp.find('message').showInfoMessage(cmp.get('v.messageNoAccess'));
                return;
            }
            if (selectedType === 'Manual Reschedule' || selectedType === 'Introduce Grace Period') {
                cmp.find('spinner').showSpinner('load');
            }
            switch (selectedType) {
                case 'Manual Reschedule':
                case 'Change Periodic Repayment Amount': {
                    let simpleRecord = cmp.get('v.simpleRecord');
                    if (simpleRecord.hasOwnProperty('sfims__Last_Instalment_Amount__c')) {
                        let element = cmp.find('currentPeriodicRepaymentAmount');
                        if (element) {
                            element.set('v.value', simpleRecord['sfims__Last_Instalment_Amount__c']);
                        }
                    }
                    break;
                }
            }
        }
        helper.end();
    },

    handlePrevious: function (cmp, event, helper) {
        helper.begin('handlePrevious');
        cmp.set('v.selectedType', null);
        cmp.set('v.isOpenPreview', false);
        helper.end();
    },

    handlePreview: function (cmp, event, helper) {
        helper.begin('handlePreview');
        if (helper.isValidForm(cmp)) {
            helper.preview(cmp);
        }
        helper.end();
    },

    handleSave: function (cmp, event, helper) {
        helper.begin('handleSave');
        if (helper.isValidForm(cmp)) {
            helper.reschedule(cmp);
        }
        helper.end();
    },

    handleChangeGracePeriodType: function (cmp, event, helper) {
        helper.begin('handleChangeGracePeriodType');
        let gracePeriodType = cmp.find('sfims__Grace_Period_Type__c').get('v.value');
        let element = cmp.find('sfims__Number_of_Grace_Periods__c');
        $A.util.removeClass(element, 'error');
        $A.util.removeClass(element, 'slds-has-error');
        if (gracePeriodType === '' || gracePeriodType === 'None') {
            element.set('v.value', '');
            element.set('v.disabled', true);
        } else {
            element.set('v.disabled', false);
        }
        helper.end();
    },

    handleChangeRescheduleBasedOn: function (cmp, event, helper) {
        helper.begin('handleChangeRescheduleBasedOn');
        let baseOnValue = cmp.get('v.baseOnValue');
        let numberOfInstalmentsDiv = cmp.find('numberOfInstalmentsDiv');
        let numberOfInstalments = cmp.find('numberOfInstalments');
        let newPeriodicRepaymentAmountDiv = cmp.find('newPeriodicRepaymentAmountDiv');
        let newPeriodicRepaymentAmount = cmp.find('newPeriodicRepaymentAmount');
        if (!baseOnValue || !numberOfInstalments || !numberOfInstalmentsDiv || !newPeriodicRepaymentAmountDiv || !newPeriodicRepaymentAmount) {
            cmp.find('message').showErrorMessage('The required attributes were not received.');
            helper.end();
            return;
        }
        switch (baseOnValue) {
            case 'Number of Instalments' : {
                $A.util.removeClass(numberOfInstalmentsDiv, 'slds-hide');
                $A.util.addClass(newPeriodicRepaymentAmountDiv, 'slds-hide');
                numberOfInstalments.set('v.required', true);
                newPeriodicRepaymentAmount.set('v.required', false);
                newPeriodicRepaymentAmount.reportValidity();
                newPeriodicRepaymentAmount.set('v.value', null);
                break;
            }
            case 'Periodic Repayment Amount' : {
                $A.util.addClass(numberOfInstalmentsDiv, 'slds-hide');
                $A.util.removeClass(newPeriodicRepaymentAmountDiv, 'slds-hide');
                numberOfInstalments.set('v.required', false);
                numberOfInstalments.reportValidity();
                numberOfInstalments.set('v.value', null);
                newPeriodicRepaymentAmount.set('v.required', true);
                break;
            }
        }
        helper.end();
    },

    formLoadFromIntroduceForm: function (cmp, event, helper) {
        helper.begin('formLoadFromIntroduceForm');
        let payload = event.getParams();
        if (payload) {
            helper.log('loan product', payload);
            helper['recordUi'] = payload;
        }
        let action = cmp.get('c.handleChangeGracePeriodType');
        action.setParams({cmp: cmp, event: event, helper: helper});
        $A.enqueueAction(action);
        cmp.find('spinner').hideSpinner('load');
        helper.end();
    },

    formLoadFromManualForm: function (cmp, event, helper) {
        helper.begin('formLoadFromManualForm');
        let payload = event.getParams();
        if (payload) {
            helper.log('loan product', payload);
            helper['recordUi'] = payload;
        }
        let action = cmp.get('c.handleChangeGracePeriodType');
        action.setParams({cmp: cmp, event: event, helper: helper});
        $A.enqueueAction(action);
        action = cmp.get('c.handleChangeRescheduleBasedOn');
        action.setParams({cmp: cmp, event: event, helper: helper});
        $A.enqueueAction(action);
        $A.util.addClass(cmp.find('sfims__Repayment_Frequency_Unit__c'), 'custom-required');
        $A.util.addClass(cmp.find('sfims__Repayment_Frequency__c'), 'custom-required');
        cmp.find('spinner').hideSpinner('load');
        helper.end();
    },

    formError: function (cmp, event, helper) {
        helper.begin('formError');
        let errors = event.getParams();
        helper.log('form errors', errors);
        if (errors) {
            cmp.find('message').showErrorMessage(cmp.find('system').getAuraErrorsFromRecordForm(errors));
        }
        cmp.find('spinner').hideSpinner('load');
        helper.end();
    }
});