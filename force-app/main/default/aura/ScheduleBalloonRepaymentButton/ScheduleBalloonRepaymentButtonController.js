({
    doInit: function (cmp, event, helper) {
        console.group('%s, time: %f', 'doInit', helper.timeStamp());
        helper.fetchData(cmp);
        console.groupEnd();
    },

    handleChange: function (cmp, event, helper) {
        console.log('%s, time: %f', 'handleChange', helper.timeStamp());
        let index = event.getSource().get('v.value');
        if (helper['schedules'] !== undefined && index) {
            helper['scheduleNumber'] = index;
            $A.util.removeClass(cmp.find('period'), 'slds-has-error'); // remove red border
            $A.util.addClass(cmp.find('parent'), 'hide-error-message'); // hide error message
            let size = helper['schedules'].length;
            let amount = helper['schedules'][index]['sfims__Total_Expected__c'];
            index++; // after
            for (let i = index; i < size; i++) {
                amount += helper['schedules'][i]['sfims__Principal_Expected__c'] + helper['schedules'][i]['sfims__Fees_Expected__c'];
            }
            cmp.set('v.amount', amount);
        }
    },

    handleConfirm: function (cmp, event, helper) {
        console.log('%s, time: %f', 'handleConfirm', helper.timeStamp());
        if (cmp.find('period').get('v.value')) {
            helper.confirm(cmp);
        }
    },

    handleCancel: function (cmp, event, helper) {
        console.log('%s, time: %f', 'handleCancel', helper.timeStamp());
        helper.closeQuickAction(cmp);
    }
})