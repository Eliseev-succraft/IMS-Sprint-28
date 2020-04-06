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
        // this list will be replaced in fetchData
        cmp.set('v.columns', [
            {label: 'Indicator Name', fieldName: 'sfims__Indicator_Name__c', type: 'url'},
            {label: 'Indicator Type', fieldName: 'sfims__Indicator_Type__c', type: 'text'},
            {label: 'Library', fieldName: 'RecordTypeId', type: 'text'},
            {label: 'Definition', fieldName: 'sfims__Definition__c', type: 'text'},
            {label: 'Outcome Area', fieldName: 'sfims__Outcome_Area__c', type: 'text'},
        ]);
        helper.fetchData(cmp);
        helper.stopMethod(cmp);
    },

    handleShowHideMoreFilters: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleShowHideMoreFilters');
        helper.showHideMoreFilters(cmp);
        helper.stopMethod(cmp);
    },

    handleRefresh: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleRefresh');
        let flag = event.getParam('value');
        if (flag) {
            helper.fetchData(cmp);
        }
        cmp.set('v.isRefresh', false);
        helper.stopMethod(cmp);
    },

    handleAddSelected: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleAddSelected');
        if (event.getSource().get('v.value') !== undefined) {
            cmp.set('v.setActiveTab', 'tab2');
            helper.showSpinner(cmp, 'v.isLoading', 5000, 'handleAddSelected');
            setTimeout($A.getCallback(() =>
                helper.addSelected(cmp, event)), 10);
        }
        else {
            helper.showWarningMessage('Please select indicators.');
        }
        helper.stopMethod(cmp);
    },

    navigateToSobject: function (cmp, event, helper) {
        helper.startMethod(cmp, 'navigateToSobject');
        let element = event.currentTarget;
        let id = element.dataset.value;
        if (id) {
            helper.navigateToSObject(cmp, id);
        }
        helper.stopMethod(cmp);
    }
});