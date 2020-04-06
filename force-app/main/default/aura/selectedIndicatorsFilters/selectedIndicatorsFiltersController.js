({
    doInit: function (cmp, event, helper) {
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['logSettings'] = {
            style1: {
                value: 'background: blue; color: white;'
            }
        };
        helper.startMethod(cmp, 'doInit');
        helper.log('initialization');
        cmp.set('v.checkboxGroupValues', {
            'sfims__Indicator_Type__c': [],
            'RecordTypeId': [],
            'sfims__Standard_Custom__c': [],
            'sfims__Outcome_Area__c': []
        });
        helper.fetchData(cmp);
        helper.stopMethod(cmp);
    },

    handleChange: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleChange');
        helper.showSpinner(cmp, 'v.isLoading', 5000, 'handleChange');
        setTimeout($A.getCallback(() =>
            helper.refreshView(cmp)), 10);
        helper.stopMethod(cmp);
    },

    handleResetFilters: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleResetFilters');
        helper.resetFilters(cmp);
        helper.stopMethod(cmp);
    }
});