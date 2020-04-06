({
	handleRecordUpdated: function(component, event, helper) {

        var eventParams = event.getParams();
        if(eventParams.changeType === "LOADED") {
            // record is loaded
            console.log("Record is loaded successfully.");
            var rec = component.get("v.simpleRecord");
            
            var message;
            var showToast = false;

            $A.get("e.force:closeQuickAction").fire();
            var toastEvent = $A.get("e.force:showToast");
            toastEvent.setParams({
                "title": "Error",
                "type": "error",
                "message": 'Not available in the current version'
            });
            toastEvent.fire();

            // var transactions = component.get("v.transactions");
            // console.log(transactions.length);
            // if (transactions.length > 0) {
            //     for (var tr in transactions) {
            //         if (transactions[tr].sfims__Status__c == 'Disbursed') {
            //             showToast = true;
            //             message = 'Cannot refinance the loan with no disbursements.';
            //         }
            //     }
            // } else {
            //     showToast = true;
            //     message = 'Cannot refinance the loan with no disbursements.';
            // }
            
            // if (rec.sfims__Open_Ended_Loan__c) {
            //     showToast = true;
            //     message = 'Not available for Open Ended loans.';
            // } else {
            //     if (rec.sfims__Status__c != 'Active') {
            //         showToast = true;
            //         message = 'Only Loans with status \'Active\' can be refinanced.';
            //     }
            // }
            
            // if (showToast) {
            //     $A.get("e.force:closeQuickAction").fire();
            //     var toastEvent = $A.get("e.force:showToast");
            //     toastEvent.setParams({
            //         "title": "Error",
            //         "type": "error",
            //         "message": message
            //     });
            //     toastEvent.fire();
            //     return;
            // }
			// component.set("v.newDisbursementAmount", 0);
            // helper.setTodaysDate(component);

            // component.find('overlayLib').notifyClose();

        } else if(eventParams.changeType === "CHANGED") {
            // record is changed
        } else if(eventParams.changeType === "REMOVED") {
            // record is deleted
        } else if(eventParams.changeType === "ERROR") {
            // there’s an error while loading, saving, or deleting the record
        }
    },

    skipTopupDisbursement: function changeState(component) {
        component.set('v.isExpandedTopupDisbursement', !component.get('v.isExpandedTopupDisbursement'));
    },

    recalculateRefinanceAmount: function(component, event, helper) {
        var rescheduleloanCmp = component.find("rescheduleloan");
        // call the aura:method in the child component
        rescheduleloanCmp.countRescheduleAmount();
    },

    openPreview: function(component, event, helper) {
        var disburseloanCmp = component.find("disburseloan");
        // call the aura:method in the child component
        disburseloanCmp.runValidation();
        if (component.get("v.validationDateError")) return;
        helper.generatePreview(component, '1');
    },

    openPreviewWithPlannedDisbursements: function(component, event, helper) {
        helper.generatePreview(component, '2');
    },

    refinance: function(component, event, helper) {
        // run validation
        var disburseloanCmp = component.find("disburseloan");
        // call the aura:method in the child component
        disburseloanCmp.runValidation();
        if (component.get("v.validationDateError")) return;
        var rescheduleloanCmp = component.find("rescheduleloan");
        // call the aura:method in the child component
        var dataMap = rescheduleloanCmp.generateData();
        console.log(dataMap);
        if (dataMap == undefined) return;

        dataMap['transactions'] = JSON.stringify(component.get("v.newTransactions"));
        dataMap['topupAmount'] = component.get("v.newDisbursementAmount");
        component.set("v.spinner", true);
        var action = component.get("c.refinanceLoan");
        action.setParams({
            "dataMap" : dataMap
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            console.log(state);
            if (state === "SUCCESS") {
                component.set("v.spinner", false);
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success",
                    "type": "success",
                    "message": "Refinancing completed"
                });
                toastEvent.fire();
                $A.get("e.force:closeQuickAction").fire();
                $A.get('e.force:refreshView').fire();
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