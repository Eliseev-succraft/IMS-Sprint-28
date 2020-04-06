({
    doInit: function (cmp, event, helper) {
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['debugLogStyle'] = 'background: green; color: white;';
        helper.begin('doInit');
        if (helper['isDebugLog'] === undefined) {
            cmp.find('message').showErrorMessage('The "isDebugLog" attribute was not found in the component markup.');
            return;
        }
        let spinner = cmp.find('spinner').showSpinner();
        helper.end();
    },

    handleSave: function (cmp, event, helper) {
        helper.begin('handleCancel');
        cmp.find('edit').get('e.recordSave').fire();
        helper.end();
    },

    handleSaveSuccess: function (cmp, event, helper) {
        helper.begin('handleSaveSuccess');
        if (cmp.get('v.successMessage')) {
            cmp.find('message').showSuccessMessage(cmp.get('v.successMessage'));
        }
        let action = cmp.get('c.handleCancel');
        action.setParams({cmp: cmp, event: event, helper: helper});
        $A.enqueueAction(action);
        helper.end();
    },

    handleCancel: function (cmp, event, helper) {
        helper.begin('handleCancel');
        if (cmp.get('v.objectApiName')) {
            cmp.find('navigation').navigateToObjectHome(cmp.get('v.objectApiName'));
        } else {
            cmp.find('message').showErrorMessage('The "objectApiName" attribute was not found in the component markup.');
        }
        helper.end();
    }
});