({
    run1: function (cmp) {
        cmp.set('v.loading', true);
        let action = cmp.get('c.method1');
        action.setParams({
            pr1: cmp.get('v.city')
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                let results = response.getReturnValue();
                let testVar = JSON.parse(results['pr1']);
                console.log(testVar);


                cmp.set('v.pr1', results['pr1']);
                cmp.set('v.pr2', results['pr2']);
                cmp.set('v.pr3', results['pr3']);
                cmp.set('v.pr4', results['pr4']);

                cmp.set('v.loading', false);
            }
            else {
                let errors = response.getError();
                let message = 'Unknown error';
                if (errors && Array.isArray(errors) && errors.length > 0) {
                    message = errors[0].message;
                }
                this.showMessage(null, message, 'error');
                cmp.set('v.loading', false);
            }
        });
        $A.enqueueAction(action);
        console.groupEnd();
    },

    showMessage: function (title, message, type) {
        let toast = $A.get('e.force:showToast');
        if (toast !== 'undefined') {
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
});