({
	setTodaysDate: function(component) {
        var today = $A.localizationService.formatDate(new Date(), "YYYY-MM-DD");
        component.set("v.refinanceDate", today);
    },

    generatePreview: function (component, previewType) {
        var rescheduleloanCmp = component.find("rescheduleloan");
        // call the aura:method in the child component
        var dataMap = rescheduleloanCmp.generateData();
        console.log(dataMap);
        if (dataMap == undefined) return;
        
        component.set("v.spinner", true);
        dataMap['transactions'] = JSON.stringify(component.get("v.newTransactions"));
        dataMap['previewType'] = previewType;
        if (previewType === '2') dataMap['allTransactions'] = JSON.stringify(component.get("v.transactions"));
        var action = component.get("c.generateSchedulePreview");
        action.setParams({
            "dataMap" : dataMap
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            console.log(state);
            if (state === "SUCCESS") {
                var records = response.getReturnValue();
                for (var rs in records) {
                    records[rs].sfims__Total_Expected__c = Number(records[rs].sfims__Principal_Expected__c) + Number(records[rs].sfims__Interest_Expected_Standard_Loan__c) + Number(records[rs].sfims__Fees_Expected__c);
                }
                console.log(records);
                component.set("v.showPreview", true);
                component.set("v.repaymentSchedules", records);
                component.set("v.previewColumns", [
                    {label: 'Due Date', fieldName: 'sfims__Due_Date__c', type: 'date'},
                    {label: 'Total Due', fieldName: 'sfims__Total_Expected__c', type: 'currency', typeAttributes: {minimumFractionDigits: '2'}},
                    {label: 'Principal Due', fieldName: 'sfims__Principal_Expected__c', type: 'currency', typeAttributes: {minimumFractionDigits: '2'}},
                    {label: 'Interest Due', fieldName: 'sfims__Interest_Expected_Standard_Loan__c', type: 'currency', typeAttributes: {minimumFractionDigits: '2'}},
                    {label: 'Fees Due', fieldName: 'sfims__Fees_Expected__c', type: 'currency', typeAttributes: {minimumFractionDigits: '2'}}
				]);
				component.set("v.spinner", false);
            }
            else if (state === "ERROR") {
				component.set("v.spinner", false);
                console.log(response.getError()[0].message);
                component.set("v.failedApex", true);
                component.set("v.apexError", response.getError()[0].message);
            }
        });
        $A.enqueueAction(action);
    }
})