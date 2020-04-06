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
        helper.fetchData(cmp);
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

    handleRefreshData: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleRefreshData');
        helper.fetchData(cmp);
        helper.stopMethod(cmp);
    },

    handleRefreshView: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleRefreshView');
        helper.showSpinner(cmp, 'v.isLoading', 5000, 'handleRefreshView');
        setTimeout($A.getCallback(() =>
            helper.refreshView(cmp)), 10);
        helper.stopMethod(cmp);
    },

    handleSetActiveSections: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleSetActiveSections');
        helper.setActiveSections(cmp, event);
        helper.stopMethod(cmp);
    },

    handleResetFilters: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleResetFilters');
        helper.resetFilters(cmp);
        helper.stopMethod(cmp);
    }
});