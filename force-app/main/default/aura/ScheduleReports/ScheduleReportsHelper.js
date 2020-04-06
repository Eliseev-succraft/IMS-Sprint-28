/*
 * @description         This is helper for the component SheduleReports
 * @author              Alexey Eliseev
 * @component           SheduleReports
 * @date                1/16/19
*/

({
    // custom required field for reportTemplate
    lookupValid: function (cmp, event) {
        var reportTemplateId = event.getSource().get("v.value");
        if ((reportTemplateId != null) && (this.trim(reportTemplateId).length > 0)) {
            $A.util.removeClass(cmp.find("reportTemplate"), "error");
            $A.util.removeClass(cmp.find("reportTemplate"), "slds-has-error");
        } else {
            $A.util.addClass(cmp.find("reportTemplate"), "error");
            $A.util.addClass(cmp.find("reportTemplate"), "slds-has-error");
        }
    },

    generateProgressReports: function (cmp, event) {
        console.log('generateProgressReports');
        var formFields = ['reportTemplate', 'date', 'frequency', 'number'];
        var fieldsSize = formFields.length;
        var validForm = true;

        for (var i = 0; i < fieldsSize; i++) {
            var validItem = cmp.find(formFields[i]);
            // custom check for required field Report Template
            if (i == 0) {
                if ((validItem.get("v.value") == null) || (this.trim(validItem.get("v.value")).length == 0)) {
                    validForm = false;
                    $A.util.addClass(cmp.find(formFields[i]), "error");
                    $A.util.addClass(cmp.find(formFields[i]), "slds-has-error");
                }
                continue;
            }
            // check for another fields
            validItem.showHelpMessageIfInvalid();
            if ((!validItem.get('v.validity').valid) && (validForm)) {
                validForm = false;
            }
        }

        if (validForm) {
            var action = cmp.get('c.generatedProgressReport');
            action.setParams({
                application: cmp.get('v.recordId'),
                reportTemplate: cmp.find('reportTemplate').get("v.value"),
                prDate: cmp.find('date').get("v.value"),
                prFrequency: cmp.find('frequency').get("v.value"),
                prNumber: cmp.find('number').get("v.value")
            });
            action.setCallback(this, function (response) {
                var state = response.getState();
                if (state === 'SUCCESS') {
                    var responseValue = response.getReturnValue();
                    if (responseValue.length > 0) {
                        this.showMessage(null, 'Progress Report was created.', 'success');
                        this.cancel(cmp, event);
                    }
                }
                else {
                    var errors = response.getError();
                    var message = 'Unknown error';

                    if (errors && Array.isArray(errors) && errors.length > 0) {
                        message = errors[0].message;
                    }
                    this.showMessage(null, errors[0].message, 'error');
                    console.error(message);
                }
            });
            $A.enqueueAction(action);
        }
    },

    cancel: function (cmp, event) {
        console.log('cancel');
        var recordId = cmp.get('v.recordId');
        // navigation back to Application
        if (recordId != null) {
            var navEvt = $A.get("e.force:navigateToSObject");
            navEvt.setParams({
                "recordId": recordId,
                "slideDevName": "related"
                //"isredirect": true
            });
            navEvt.fire();
            setTimeout(function(){ location.reload(true) }, 100);
        } else {
            var homeEvent = $A.get('e.force:navigateToObjectHome');
            homeEvent.setParams({
                'scope': 'sfims__Application__c'
            });
            homeEvent.fire();
            setTimeout(function(){ location.reload(true) }, 100);
        }
    },

    // custom function to remove spaces
    trim: function (str) {
        console.log('trim');
        return str.replace(/^\s+|\s+$/g, '');
    },

    showMessage: function (title, message, type) {
        console.log('showMessage');
        var toast = $A.get('e.force:showToast');
        if (toast != null) {
            toast.setParams({
                'title': title,
                'message': message,
                'type': type
            });
            toast.fire();
        }
        else {
            alert(message);
        }
    }
})