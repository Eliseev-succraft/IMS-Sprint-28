({
    doInit: function (cmp, event, helper) {
        console.group('%s, time: %f', 'doInit', helper.timeStamp());
        helper.showSpinner(cmp, 'v.isLoading', 40000, 'doInit');
        console.groupEnd();
    },

    handleCancel: function (cmp, event, helper) {
        console.log('%s, time: %f', 'handleCancel', helper.timeStamp());
        helper.closeQuickAction(cmp);
    },

    handleRecordUpdated: function (cmp, event, helper) {
        console.log('%s, time: %f', 'handleRecordUpdated', helper.timeStamp());
        let eventParams = event.getParams();
        if (eventParams['changeType'] === 'LOADED') {
            helper.hideSpinner(cmp, 'v.isLoading', 'doInit');
            console.log('Record is loaded successfully.');
            let rec = cmp.get('v.simpleRecord');
            if (rec.sfims__Status__c !== 'Inactive') {
                helper.showErrMessage($A.get("$Label.c.js_error_message_8"));
                helper.closeQuickAction(cmp);
            } else {
                helper.showModal(cmp, 'v.isForm');
            }
        } else if (eventParams['changeType'] === 'CHANGED') {
            // record is changed
        } else if (eventParams['changeType'] === 'REMOVED') {
            // record is deleted
        } else if (eventParams['changeType'] === 'ERROR') {
            helper.showErrMessage($A.get("$Label.c.js_error_message_1"));
        }
    },

    handleRecalculate: function (cmp, event, helper) {
        console.group('%s, time: %f', 'handleRecalculate', helper.timeStamp());
        let spinner = helper.showSpinner(cmp, 'v.isLoading');
        let action = cmp.get('c.recalculateLoanSchedule');
        action.setParams({
            loanId: cmp.get('v.recordId')
        });
        action.setCallback(this, function (response) {
            helper.hideSpinner(cmp, 'v.isLoading', spinner);
            let state = response.getState();
            if (state === 'SUCCESS') {
                console.group('%s, time: %f', 'fetchData-SUCCESS', helper.timeStamp());
                helper.showSuccessMessage($A.get("$Label.c.js_success_message_2"));
                $A.get('e.force:refreshView').fire();
                helper.closeQuickAction(cmp);
                console.groupEnd();
            }
            else {
                let errors = response.getError();
                let message = $A.get("$Label.c.js_error_message_5");
                if (errors && Array.isArray(errors) && errors.length > 0) {
                    message = errors[0].message;
                }
                helper.showErrMessage(message);
            }
        });
        $A.enqueueAction(action);
        console.groupEnd();
    }
})