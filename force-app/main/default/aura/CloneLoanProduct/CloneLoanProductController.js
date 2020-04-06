({

    doInit : function(component, event, helper) {

        window.setTimeout(
            $A.getCallback(function() {
                $A.get("e.force:closeQuickAction").fire();

            }),100
        );

        var recordId = component.get("v.recordId");
        var newEvent = $A.get("e.force:navigateToComponent");
        newEvent.setParams({
            componentDef: "c:OverriddenLoanProductNewEdit",
            componentAttributes: {
             //   sNavigateComVal1 :recordId
            }
        });
        newEvent.fire();
    }
});