({
    showMessage: function (cmp, event, helper) {
        cmp.find('message').showErrorMessage('This button is no longer used.');
        $A.get("e.force:closeQuickAction").fire();
    }
});