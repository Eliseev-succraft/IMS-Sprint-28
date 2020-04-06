({
    handleErrorsAction : function(component, event, helper) {
        var params = event.getParam('arguments');
        if (params) {
            helper.handleErrors(params.errors);
        }
    },
    
    displayToastAction : function(component, event, helper) {
        var args = event.getParam("arguments");
        var type = args.type;
        var message = args.message;        

        if (type) {
            helper.displayToast(type, message);
        }
    },

    showSpinner : function(component,event,helper){
        $A.util.removeClass(
          component.find('spinner'), 
          "slds-hide"
        );
    },
    hideSpinner : function(component,event,helper){
        $A.util.addClass(
            component.find('spinner'), 
            "slds-hide"
        );
    },  

    waiting: function(component, event, helper) {
        component.set("v.HideSpinner", false);
    },
    doneWaiting: function(component, event, helper) {
        component.set("v.HideSpinner", true);
    }
    
})