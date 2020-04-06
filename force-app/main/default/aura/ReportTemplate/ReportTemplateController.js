({
    doInit: function (cmp, event, helper) {
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper.startMethod(cmp, 'doInit');
        helper.log('initialization');
        helper.stopMethod(cmp);
    },

    customForceRefresh: function (cmp, event, helper) {
        helper.startMethod(cmp, 'customForceRefresh');
        $A.get('e.force:refreshView').fire();
        helper.stopMethod(cmp);
    }
});