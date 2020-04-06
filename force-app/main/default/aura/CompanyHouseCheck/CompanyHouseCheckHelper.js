({
    updateCompanyInfHelper : function (cmp, recordId) {
        cmp.set('v.loading', true);
        var action = cmp.get("c.updateCompanyInformation");
        action.setParams({
            "recordId": recordId
        });
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state === 'SUCCESS') {
                var res =  response.getReturnValue();
                this.showToastEvent(res.message, res.type);
                $A.get('e.force:refreshView').fire();

            }
            cmp.set('v.loading', false);
        });
        $A.enqueueAction(action);
    },
    getLastUpdateHelper : function (cmp, recordId) {
        var action = cmp.get("c.getLastUpdate");
        action.setParams({
            "recordId": recordId
        });
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state === 'SUCCESS') {
                cmp.set('v.lastUpdate', response.getReturnValue());


            }
        });
        $A.enqueueAction(action);
    },
    showToastEvent: function (toastMessage, toastType){
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            message: toastMessage,
            type: toastType
        });
        toastEvent.fire();
    }
})