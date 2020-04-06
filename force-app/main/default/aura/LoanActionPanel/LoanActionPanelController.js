({
    doInit: function (cmp, event, helper) {
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['debugLogStyle'] = 'background: green; color: white;';
        helper.begin('doInit');
        helper['isRecordUpdated'] = false;
        helper['buttons'] = [
            {
                access: true,
                messageNoAccess: 'You have insufficient privileges for this action.',
                label: 'Edit',
                actionAPI: 'Edit',
                display: true
            }, {
                access: true,
                messageNoAccess: $A.get('$Label.c.error_message_25'),
                label: 'Generate Schedule',
                actionAPI: 'GenerateSchedule',
                display: true
            }, {
                access: true,
                messageNoAccess: 'You have insufficient privileges for this action.',
                label: 'Edit Schedule',
                actionAPI: 'EditSchedule',
                display: true
            }, {
                access: true,
                messageNoAccess: $A.get('$Label.c.error_message_34'),
                label: 'Reschedule',
                actionAPI: 'Reschedule',
                display: true
            }, {
                access: true,
                messageNoAccess: $A.get('$Label.c.error_message_7'),
                label: 'Disburse',
                actionAPI: 'Disburse',
                display: true
            }, {
                access: true,
                messageNoAccess: $A.get('$Label.c.error_message_30'),
                label: 'Recalculate',
                actionAPI: 'Recalculate',
                display: true
            }, {
                access: true,
                messageNoAccess: $A.get('$Label.c.error_message_35'),
                label: 'Write Off',
                actionAPI: 'WriteOff',
                display: true
            }, {
                access: true,
                messageNoAccess: $A.get('$Label.c.error_message_23'),
                label: 'Early Repayment',
                actionAPI: 'EarlyRepayment',
                display: true
            }, {
                access: true,
                messageNoAccess: $A.get('$Label.c.error_message_1'),
                label: 'Schedule Balloon Repayment',
                actionAPI: 'ScheduleBalloonRepayment',
                display: true
            }];
        helper.end();
    },

    customForceRefresh: function (cmp, event, helper) {
        helper.begin('customForceRefresh');
        let data = event.getParams();
        helper.log(data);
        if (data.hasOwnProperty('message')) {
            if (data.message === 'Record was deleted.') {
                $A.get('e.force:refreshView').fire();
            }
        }
        /*
        if (event.hasOwnProperty('messageTemplateData') && event.hasOwnProperty('message')) {
            if (event.messageTemplateData[0] === 'Loan Event' && event.message === 'Record was deleted.') {
                $A.get('e.force:refreshView').fire();
            }
        }*/
        helper.end();
    },

    showSpinner: function (cmp, event, helper) {
        helper.begin('showSpinner');
        if (!helper['isRecordUpdated']) {
            cmp.find('spinner').showSpinner('loadingRecordData');
        }
        helper.end();
    },

    handleRecordUpdated: function (cmp, event, helper) {
        helper.begin('handleRecordUpdated');
        helper['isRecordUpdated'] = true;
        cmp.find('spinner').hideSpinner('loadingRecordData');
        let params = event.getParams();
        helper.log('change type', params['changeType']);
        if (params['changeType'] === 'LOADED') {
            let simpleRecord = cmp.get('v.simpleRecord');
            helper.log('simpleRecord', simpleRecord);
            let buttons = helper['buttons'];
            if (simpleRecord['sfims__Recalculation_Status__c'] === 'Pending Recalculation' || simpleRecord['sfims__Recalculation_Status__c'] === 'In Progress') {
                buttons.forEach(function (btn) {
                    if (btn['display']) {
                        btn['display'] = (btn['label'] === 'Recalculate');
                    }
                });
            }
            if (simpleRecord['sfims__Status__c'] === 'Inactive') {
                buttons.forEach(function (btn) {
                    if (btn['display']) {
                        btn['display'] = (btn['label'] === 'Edit' || btn['label'] === 'Generate Schedule' || btn['label'] === 'Disburse' || btn['label'] === 'Edit Schedule');
                    }
                });
            }
            if (simpleRecord['sfims__Status__c'] === 'Active') {
                buttons.forEach(function (btn) {
                    if (btn['display']) {
                        btn['display'] = !(btn['label'] === 'Generate Schedule'); // allow all but Generate Schedule
                    }
                });
            }
            if (['Closed - All Obligations Met', 'Closed - Written Off', 'Closed - Early Repayment', 'Closed'].indexOf(simpleRecord['sfims__Status__c']) !== -1) {
                buttons.forEach(function (btn) {
                    if (btn['display']) {
                        btn['display'] = (btn['label'] === 'Edit'); // allow only Edit
                    }
                });
            }
            if (simpleRecord['sfims__Open_Ended_Loan__c'] === true) {
                buttons.forEach(function (btn) {
                    if (btn['display']) {
                        btn['display'] = !(btn['label'] === 'Reschedule' || btn['label'] === 'Schedule Balloon Repayment' || btn['label'] === 'Early Repayment');
                    }
                });
            }
            helper['buttons'] = buttons;
            helper.getButtonAccess(cmp);
        }
        else if (params['changeType'] === 'CHANGED') {
            let doInit = cmp.get('c.doInit');
            doInit.setParams({
                cmp: cmp, event: event, helper: helper
            });
            $A.enqueueAction(doInit);
            helper.reloadRecordData(cmp);
        }
        else if (params['changeType'] === 'ERROR') {
            cmp.find('message').showErrorMessage('RecordData has not been loaded.');
        }
        helper.end();
    },

    handleCustomActionClick: function (cmp, event, helper) {
        helper.begin('handleCustomActionClick');
        let spinner = cmp.find('mainActionSpinner').showSpinner();
        let action = event.getSource().get('v.value');
        helper.log('action attribute', action);

        let isRescheduleAccess = true;
        let rescheduleMessageNoAccess = '';
        if (action) {
            for (let key in helper['buttons']) {
                if (helper['buttons'].hasOwnProperty(key)) {
                    let btn = helper['buttons'][key];
                    if (btn.actionAPI === action && !btn.access) {
                        if (action !== 'Reschedule') {
                            cmp.find('message').showInfoMessage(btn.messageNoAccess);
                            cmp.find('mainActionSpinner').hideSpinner(spinner);
                            helper.end();
                            return;
                        } else {
                            isRescheduleAccess = false;
                            rescheduleMessageNoAccess = btn.messageNoAccess;
                        }
                    }
                }
            }
            let modalBody;
            switch (action) {
                case 'Edit':
                    let customActions = {};
                    customActions[action] = true;
                    cmp.set('v.customActions', customActions);
                    cmp.find('mainActionSpinner').hideSpinner(spinner);
                    break;
                case 'GenerateSchedule':
                    $A.createComponent('c:GenerateScheduleButton', {
                            recordId: cmp.get('v.recordId')
                        },
                        function (content, status) {
                            if (status === 'SUCCESS') {
                                modalBody = content;
                                cmp.find('overlayLib').showCustomModal({
                                    body: modalBody,
                                    cssClass: 'custom-modal',
                                    showCloseButton: true,
                                    closeCallback: function () {
                                    }
                                });
                                cmp.find('mainActionSpinner').hideSpinner(spinner);
                            }
                        });
                    break;
                case 'EditSchedule': {
                    let customActions = {};
                    customActions[action] = true;
                    cmp.set('v.customActions', customActions);
                    $A.createComponent('c:lwcLoanScheduleEditor', {
                            recordId: cmp.get('v.recordId')
                        },
                        function (content, status) {
                            if (status === 'SUCCESS') {
                                modalBody = content;
                                cmp.find('overlayLib').showCustomModal({
                                    body: modalBody,
                                    cssClass: 'schedule-modal custom-modal',
                                    showCloseButton: true,
                                    closeCallback: function () {
                                    }
                                });
                                cmp.find('mainActionSpinner').hideSpinner(spinner);
                            }
                        });
                    break;
                }
                case 'Disburse':
                    $A.createComponent('c:DisburseLoanButton', {
                            recordId: cmp.get('v.recordId')
                        },
                        function (content, status) {
                            if (status === 'SUCCESS') {
                                modalBody = content;
                                cmp.find('overlayLib').showCustomModal({
                                    body: modalBody,
                                    cssClass: 'custom-modal',
                                    showCloseButton: true,
                                    closeCallback: function () {
                                    }
                                });
                                cmp.find('mainActionSpinner').hideSpinner(spinner);
                            }
                        });
                    break;
                case 'Reschedule':
                    $A.createComponent('c:RescheduleLoanButton', {
                            recordId: cmp.get('v.recordId'),
                            access: isRescheduleAccess,
                            messageNoAccess: rescheduleMessageNoAccess
                        },
                        function (content, status) {
                            if (status === 'SUCCESS') {
                                modalBody = content;
                                cmp.find('overlayLib').showCustomModal({
                                    body: modalBody,
                                    cssClass: 'custom-modal',
                                    showCloseButton: true,
                                    closeCallback: function () {
                                    }
                                });
                                cmp.find('mainActionSpinner').hideSpinner(spinner);
                            }
                        });
                    break;
                case 'Recalculate':
                    $A.createComponent('c:RecalculateLoanScheduleButton', {
                            recordId: cmp.get('v.recordId')
                        },
                        function (content, status) {
                            if (status === 'SUCCESS') {
                                modalBody = content;
                                cmp.find('overlayLib').showCustomModal({
                                    body: modalBody,
                                    cssClass: 'custom-modal',
                                    showCloseButton: true,
                                    closeCallback: function () {
                                    }
                                });
                                cmp.find('mainActionSpinner').hideSpinner(spinner);
                            }
                        });
                    break;
                case 'Refinance':
                    $A.createComponent('c:RefinanceLoanButton', {
                            recordId: cmp.get('v.recordId')
                        },
                        function (content, status) {
                            if (status === 'SUCCESS') {
                                modalBody = content;
                                cmp.find('overlayLib').showCustomModal({
                                    body: modalBody,
                                    cssClass: 'custom-modal',
                                    showCloseButton: true,
                                    closeCallback: function () {
                                    }
                                });
                                cmp.find('mainActionSpinner').hideSpinner(spinner);
                            }
                        });
                    break;
                case 'WriteOff':
                    $A.createComponent('c:LoanWriteOffButton', {
                            recordId: cmp.get('v.recordId')
                        },
                        function (content, status) {
                            if (status === 'SUCCESS') {
                                modalBody = content;
                                cmp.find('overlayLib').showCustomModal({
                                    body: modalBody,
                                    cssClass: 'custom-modal',
                                    showCloseButton: true,
                                    closeCallback: function () {
                                    }
                                });
                                cmp.find('mainActionSpinner').hideSpinner(spinner);
                            }
                        });
                    break;
                case 'EarlyRepayment':
                    $A.createComponent('c:LoanEarlyRepaymentButton', {
                            recordId: cmp.get('v.recordId')
                        },
                        function (content, status) {
                            if (status === 'SUCCESS') {
                                modalBody = content;
                                cmp.find('overlayLib').showCustomModal({
                                    body: modalBody,
                                    cssClass: 'custom-modal',
                                    showCloseButton: true,
                                    closeCallback: function () {
                                    }
                                });
                                cmp.find('mainActionSpinner').hideSpinner(spinner);
                            }
                        });
                    break;
                case 'ScheduleBalloonRepayment':
                    $A.createComponent('c:ScheduleBalloonRepaymentButton', {
                            recordId: cmp.get('v.recordId')
                        },
                        function (content, status) {
                            if (status === 'SUCCESS') {
                                modalBody = content;
                                cmp.find('overlayLib').showCustomModal({
                                    body: modalBody,
                                    cssClass: 'custom-modal',
                                    showCloseButton: true,
                                    closeCallback: function () {
                                    }
                                });
                                cmp.find('mainActionSpinner').hideSpinner(spinner);
                            }
                        });
                    break;
            }
        }
        helper.end();
    }
});