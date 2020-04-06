({
    doInit: function (cmp, event, helper) {
        helper.group('doInit');
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['logSettings'] = {
            style1: {
                value: 'background: blue; color: white;'
            }
        };
        helper.log('initialization');
        helper.fetchData(cmp);
        helper.groupEnd();
    }
});