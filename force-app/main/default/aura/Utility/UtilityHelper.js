({
	displayToast : function(type, message) {
        console.log('entering displayToast');
        var toastEvent = $A.get('e.force:showToast');
        toastEvent.setParams({
            type: type,
            message: message,
            mode: (type=="error"?"sticky":"")
        });
        toastEvent.fire();
   	},  
    
    handleErrors : function(errors) {
        let helper=this;
        
        var errorString = "";
        if (errors) {
            if (errors[0] && errors[0].message) {
                errorString += errors[0].message;
            } else if (errors[0] && errors[0].fieldErrors) {
                // DML Error on field level
                for(var a in errors[0].fieldErrors){
                    for(var msg in errors[0].fieldErrors[a]){
                        errorString += errors[0].fieldErrors[a][msg].message;  
                    }
                }
            } else if (errors[0] && errors[0].pageErrors[0] && errors[0].pageErrors[0].message) {
                // DML Error on page level
                errorString += errors[0].pageErrors[0].message;
            }
        } else {
            errorString = "Unknown error";
        }
    	helper.displayToast('error', 'An error occurred: '+errorString);
    }
    
})