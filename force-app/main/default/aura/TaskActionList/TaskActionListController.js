({
    doInit: function (cmp, event, helper) {
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['logSettings'] = {
            style1: {
                value: 'background: blue; color: white;'
            }
        };
        helper.startMethod(cmp, 'doInit');
        helper.log('initialization');
        helper.stopMethod(cmp);
    },

    handleEventStartTask: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleEventStartTask');
        let taskId = event.getParam('taskId');
        helper.log(taskId);
        if (taskId) {
            cmp.set('v.taskId', taskId);
            helper.closeModal(cmp, 'v.isRunTaskFlow');
            helper.showModal(cmp, 'v.isRunTaskFlow');
        } else {
            helper.showErrMessage('TaskId was not received from LWC.')
        }
        helper.stopMethod(cmp);
    },

    completedFlow: function (cmp, event, helper) {
        helper.startMethod(cmp, 'completedFlow');
        if (event.getParam('value') === true) {
            cmp.find('lwcTaskActionList').refreshView();
        }
        helper.stopMethod(cmp);
    },

    handleEventNewTask: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleEventNewTask');
        let recordTypeId = event.getParam('recordTypeId');
        helper.log(recordTypeId);
        if (recordTypeId) {
            let createRecordEvent = $A.get("e.force:createRecord");
            createRecordEvent.setParams({
                entityApiName: 'Task',
                recordTypeId: recordTypeId
            });
            createRecordEvent.fire();
        } else {
            helper.showErrMessage('RecordTypeId was not received from LWC.')
        }
        helper.stopMethod(cmp);
    }
});