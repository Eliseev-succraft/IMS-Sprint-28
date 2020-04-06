({
    doInit: function (cmp, event, helper) {
        helper.showSpinner(cmp, 'v.isLoading', 10000, 'doInit');
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['logSettings'] = {
            style1: {
                value: 'background: blue; color: white;'
            }
        };
        helper.startMethod(cmp, 'doInit');
        helper.log('initialization');
        helper.fetchData(cmp);
        helper.stopMethod(cmp);
    },

    handleCloseModal: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleCloseModal');
        helper.cancel(cmp);
        helper.stopMethod(cmp);
    },

    flowStatusChange: function (cmp, event, helper) {
        helper.startMethod(cmp, 'flowStatusChange' + ', ' + event.getParam('status'));
        // helper.hideSpinner(cmp, 'v.isLoading', 'startFlow');
        if (event.getParam('status') === 'STARTED') {
            helper.hideSpinner(cmp, 'v.isLoading', 'doInit');
            $A.util.addClass(cmp.find('FlowShowModal'), 'slds-fade-in-open');
        } else if (event.getParam('status') === 'FINISHED') {
            let changeStatusFlag = false;
            let outputVariables = event.getParam('outputVariables');
            helper.log('Return flow variables', outputVariables);
            if (outputVariables) {
                let size = outputVariables.length;
                for (let i = 0; i < size; i++) {
                    if (outputVariables[i].name === 'return' && outputVariables[i].value === 'completed') {
                        changeStatusFlag = true;
                        break;
                    }
                }
            }
            if (changeStatusFlag) {
                if (!$A.util.isEmpty(cmp.get('v.taskId'))) {
                    if (helper['classResponse']['taskListTemplateItem'].hasOwnProperty('sfims__Approval_Required__c')) {
                        if (helper['classResponse']['taskListTemplateItem']['sfims__Approval_Required__c'] === true ) {
                            helper.changeStatusTask(cmp, cmp.get('v.taskId'), 'Pending Approval');
                        } else {
                            helper.changeStatusTask(cmp, cmp.get('v.taskId'), 'Done');
                        }
                    }
                } else {
                    helper.showErrMessage('The required attribute \'taskId\' is empty.');
                    helper.cancel(cmp);
                }
            } else {
                helper.showWarningMessage('The flow did not return \'completed\' status.\n The flow has not been completed yet. Please, try again.');
                helper.cancel(cmp);
            }
        } else if (event.getParam('status') === 'ERROR') {
        }
        helper.stopMethod(cmp);
    }
});