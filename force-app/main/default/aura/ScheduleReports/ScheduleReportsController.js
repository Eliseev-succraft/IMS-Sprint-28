/*
 * @description         This is controller for the component SheduleReports
 * @author              Alexey Eliseev
 * @component           SheduleReports
 * @date                1/16/19
*/

({
    init: function (cmp, event, helper) {
        console.log('init');
        // set Application Id
        console.log(JSON.stringify(cmp.get('v.pageReference')));
        if (!$A.util.isEmpty(cmp.get('v.pageReference').state['fragment'])) {
            var recordId = cmp.get('v.pageReference').state['fragment'];
            if (recordId) {
                recordId = recordId.replace('recordId=', '');
                cmp.set('v.recordId', recordId);
            }
        }
        if ($A.util.isEmpty(cmp.get('v.recordId'))) {
            helper.showMessage(null, 'Application Id has been not get', 'error');
        }
    },

    // check field report template
    handlerChange: function (cmp, event, helper) {
        console.log('handlerChange');
        helper.lookupValid(cmp, event);
    },

    // button ScheduleReports
    handlerScheduleReports: function (cmp, event, helper) {
        console.log('handlerScheduleReports');
        helper.generateProgressReports(cmp, event);
    },

    // button Cancel
    handlerCancel: function (cmp, event, helper) {
        console.log('handlerCancel');
        helper.cancel(cmp, event);
    },

    hideSpinner: function (cmp, event, helper) {
        console.log('hideSpinner');
        cmp.set('v.isLoading', false);
    }
})