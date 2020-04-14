({
    doInit: function (cmp, event, helper) {
        let evt = $A.get("e.force:navigateToComponent");
        evt.setParams({
            componentDef: 'c:OverriddenInvestmentNewEdit',
            componentAttributes: {
                pageReference1: cmp.get('v.pageReference')
            }
        });
      //  evt.fire();
    }
});