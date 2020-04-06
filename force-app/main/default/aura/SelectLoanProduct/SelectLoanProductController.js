({
    doInit: function (cmp, event, helper) {
        console.group('%s, time: %f', 'doInit', helper.timeStamp());
        helper['callBackObject'] = 'sfims__Investment__c';
        let isLoanProduct = false;
        let defaultFieldValues = cmp.get('v.defaultFieldValues');
        console.log(defaultFieldValues);
        if (defaultFieldValues) {
            let defaultFieldValuesMap = {};
            let params = defaultFieldValues.split(',');
            if (params.length > 0) {
                params.forEach(function (pr) {
                    let elements = pr.split('=');
                    if (elements.length === 2) {
                        defaultFieldValuesMap[elements[0].trim()] = elements[1].trim();
                    }
                });
            }
            if (defaultFieldValuesMap.hasOwnProperty('sfims__Loan_Product__c') && defaultFieldValuesMap.sfims__Loan_Product__c) {
                console.log('LoanProductId=' + defaultFieldValuesMap.sfims__Loan_Product__c);
                cmp.set('v.loanProductId', defaultFieldValuesMap.sfims__Loan_Product__c);
                cmp.set('v.isNewLoan', true);
                isLoanProduct = true;
            }
            if (defaultFieldValuesMap.hasOwnProperty('objectApiName')) {
                helper['callBackObject'] = defaultFieldValuesMap['objectApiName'];
            }
        }
        if (!isLoanProduct) {
            helper.showSpinner(cmp, 'v.isLoading', 50000, 'doInit');
            helper.fetchAccess(cmp);
        }
        console.groupEnd();
    },

    formLoad: function (cmp, event, helper) {
        console.group('%s, time: %f', 'formLoad', helper.timeStamp());
        helper.hideSpinner(cmp, 'v.isLoading', 'doInit');
        console.groupEnd();
    },

    formError: function (cmp, event, helper) {
        console.group('%s, time: %f', 'formError', helper.timeStamp());
        let errors = event.getParams();
        console.log(errors);
        helper.showErrMessage(errors['detail']);
        helper.hideSpinner(cmp, 'v.isLoading', 'formSubmit');
        helper.hideSpinner(cmp, 'v.isLoading', 'doInit');
        console.groupEnd();
    },

    formSubmit: function (cmp, event, helper) {
        console.log('%s, time: %f', 'formSubmit', helper.timeStamp());
        event.preventDefault();
        if (cmp.find('loanProduct').get('v.value')) {
            let formSuccess = cmp.get('c.formSuccess');
            formSuccess.setParams({
                cmp: cmp,
                event: event,
                helper: helper
            });
            $A.enqueueAction(formSuccess);
        }
    },

    formSuccess: function (cmp, event, helper) {
        console.log('%s, time: %f', 'formSuccess', helper.timeStamp());
        console.log('loanProductId=' + cmp.get('v.loanProductId'));
        cmp.set('v.isNewLoan', true);
    },

    closeModal: function (cmp, event, helper) {
        console.log('%s, time: %f', 'closeModal', helper.timeStamp());
        let homeEvt = $A.get('e.force:navigateToObjectHome');
        homeEvt.setParams({
            'scope': helper['callBackObject']
        });
        homeEvt.fire();
    },

    showModal: function (cmp, event, helper) {
        console.group('%s, time: %f', 'showModal', helper.timeStamp());
        cmp.set('v.loanProductId', null);
        helper.showModal(cmp, 'v.isNewLoanProduct');
        console.groupEnd();
    }
})