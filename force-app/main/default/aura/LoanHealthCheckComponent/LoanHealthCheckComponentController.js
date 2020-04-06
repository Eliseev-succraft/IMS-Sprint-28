({
	doInit: function(cmp, event, helper) {
        var action = cmp.get("c.getLoanData");
        action.setParams({ 
            loanId : cmp.get("v.recordId") 
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            console.log(state);
            if (state === "SUCCESS") {
                console.log(response.getReturnValue());
                cmp.set("v.issues", response.getReturnValue()); 
                $A.get('e.force:refreshView').fire();   
            }
            else if (state === "ERROR") {
                console.log("Failed with state: " + state);
            }
        });

        $A.enqueueAction(action);
    },
    
    handleRecordUpdated: function (cmp, event, helper) {
        console.log('handleRecordUpdated');
        let eventParams = event.getParams();
        if (eventParams.changeType === 'LOADED' || eventParams.changeType === 'CHANGED') {
            console.log('CHANGED');
            let doInit = cmp.get('c.doInit');
            doInit.setParams({cmp: cmp, event: event, helper: helper});
            $A.enqueueAction(doInit);
        } 
    }
})