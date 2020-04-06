({
    doInit: function (cmp, event, helper) {
        helper['customRefresh'] = false;
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['debugLogStyle'] = 'background: green; color: white;';
        helper['defaultFieldValues'] = '';
        helper['selectedRecordTypeIdFromURL'] = '';
        helper.begin('doInit');
        cmp.find('mainSpinner').showSpinner('init');
        if (helper['isDebugLog'] === undefined) {
            cmp.find('message').showErrorMessage('The "isDebugLog" attribute was not found in the component markup.');
            helper.end();
            return;
        }
        helper['callBackObject'] = 'sfims__Investment__c';
        let pageReference = cmp.get('v.pageReference');
        if (!pageReference) {
            cmp.find('message').showErrorMessage('Required attribute was not received.');
            helper.end();
            return;
        }
        if (!pageReference.hasOwnProperty('attributes')) {
            cmp.find('message').showErrorMessage('Required attribute was not received.');
            helper.end();
            return;
        }
        if (!pageReference.attributes.hasOwnProperty('actionName')) {
            cmp.find('message').showErrorMessage('Required attribute was not received.');
            helper.end();
            return;
        }
        if (pageReference.hasOwnProperty('state')) {
            // from custom URL
            if (pageReference.state.hasOwnProperty('defaultFieldValues')) {
                helper['defaultFieldValues'] = pageReference.state.defaultFieldValues;
                if (helper['defaultFieldValues']) {
                    let defaultFieldValuesMap = {};
                    let params = helper['defaultFieldValues'].split(',');
                    if (params.length > 0) {
                        params.forEach(function (pr) {
                            let elements = pr.split('=');
                            if (elements.length === 2) {
                                elements[0] = elements[0].trim();
                                elements[1] = elements[1].trim();
                                switch (elements[0]) {
                                    case 'objectApiName' : {
                                        helper['callBackObject'] = elements[1];
                                        break;
                                    }
                                    default: {
                                        defaultFieldValuesMap[elements[0]] = elements[1];
                                    }
                                }
                            }
                        });
                    }
                    helper['defaultFieldValuesMap'] = defaultFieldValuesMap;
                }
                // from custom URL
                if (pageReference.state.hasOwnProperty('recordTypeId')) {
                    helper['selectedRecordTypeIdFromURL'] = pageReference.state.recordTypeId;
                }
                cmp.set('v.defaultFieldValues', pageReference.state.defaultFieldValues);
            } else {
                // from related object
                if (pageReference.state.hasOwnProperty('inContextOfRef')) {
                    let base64Context = pageReference.state.inContextOfRef;
                    if (base64Context.startsWith('1\.')) {
                        base64Context = base64Context.substring(2);
                    }
                    let addressableContext = JSON.parse(window.atob(base64Context));
                    helper.log('addressableContext', addressableContext);
                    if (addressableContext) {
                        if (addressableContext.hasOwnProperty('attributes')) {
                            if (addressableContext.attributes.hasOwnProperty('objectApiName')) {
                                helper['callBackObject'] = addressableContext.attributes.objectApiName;
                                if (addressableContext.attributes.hasOwnProperty('recordId')) {
                                    cmp.set('v.defaultFieldValues', helper['callBackObject'] + '=' + addressableContext.attributes.recordId + ',objectApiName=' + addressableContext.attributes.objectApiName);
                                    helper.log('defaultFieldValues', cmp.get('v.defaultFieldValues'));
                                }
                            }
                        }
                    }
                }
            }
        }
        cmp.set('v.actionName', pageReference.attributes.actionName);
        helper.log('action name', pageReference.attributes.actionName);
        helper.log('pageReference', pageReference);
        helper['pageReference'] = JSON.parse(JSON.stringify(pageReference));
        helper.fetchData(cmp);
        helper.end();
    },

    handleRecordUpdated: function (cmp, event, helper) {
        helper.begin('doInit');
        let params = event.getParams();
        helper.log('type', params['changeType']);
        if (params['changeType'] === 'LOADED') {
            let simpleRecord = cmp.get('v.simpleRecord');
            helper['recordTypeId'] = simpleRecord['RecordTypeId'];
        }
        else if (params['changeType'] === 'CHANGED') {
            let recordData = cmp.find('recordData');
            if (recordData) {
                recordData.reloadRecord(true);
            } else {
                cmp.find('message').showErrorMessage('RecordData has not been found.');
            }
        }
        else if (params['changeType'] === 'ERROR') {
            cmp.find('message').showErrorMessage('RecordData has not been loaded.');
        }
        helper.end();
    },

    customRefresh: function (cmp, event, helper) {
        if (!helper['customRefresh']) {
            helper.begin('customRefresh');
            helper['customRefresh'] = true;
            $A.get('e.force:refreshView').fire();
            helper.end();
        }
    },

    handleEventUpdateModals: function (cmp, event, helper) {
        helper.begin('handleEventUpdateModals');
        if (event.getParam('modals')) {
            cmp.set('v.modals', JSON.parse(event.getParam('modals')));
        }
        helper.end();
    },

    handleNext: function (cmp, event, helper) {
        helper.begin('handleNext');
        switch (cmp.get('v.actionName')) {
            case 'new': {
                let selectedRecordTypeId = cmp.get('v.selectedRecordTypeId');
                if (helper['selectedRecordTypeId']) {
                    selectedRecordTypeId
                }

                if (!helper['recordTypes']) {
                    cmp.find('message').showErrorMessage('Record types attribute was not found.');
                    helper.end();
                    return;
                }
                if (!helper['recordTypes'].hasOwnProperty(selectedRecordTypeId)) {
                    cmp.find('message').showErrorMessage('Record types attribute was not found.');
                    helper.end();
                    return;
                }
                switch (helper['recordTypes'][cmp.get('v.selectedRecordTypeId')]) {
                    case 'Loan': {
                        cmp.find('modal').showModal('loan');
                        break;
                    }
                    case 'Equity':
                    case 'Grant': {
                        let defaultFieldValues = '';
                        if (helper['defaultFieldValuesMap']) {
                            for (let key in helper['defaultFieldValuesMap']) {
                                if (helper['defaultFieldValuesMap'].hasOwnProperty(key)) {
                                    defaultFieldValues += ((defaultFieldValues) ? ',' : '') + key + '=' + helper['defaultFieldValuesMap'][key];
                                }
                            }
                        }
                        if (defaultFieldValues) {
                            defaultFieldValues = '&defaultFieldValues=' + defaultFieldValues;
                        }
                        let redirectUrl = '/lightning/o/sfims__Investment__c/new?nooverride=1&backgroundContext=%2Flightning%2Fo%2Fsfims__Investment__c%2Flist&recordTypeId=' + selectedRecordTypeId + defaultFieldValues;
                        helper.log(redirectUrl);
                        cmp.find('navigation').navigateToWebPage(redirectUrl);
                        helper.end();
                        return;
                    }
                }
                break;
            }
            case 'edit': {
                if (!helper['recordTypes']) {
                    cmp.find('message').showErrorMessage('Record types attribute was not found.');
                    helper.end();
                    return;
                }
                if (!helper['recordTypeId']) {
                    cmp.find('message').showErrorMessage('Record type attribute was not found.');
                    helper.end();
                    return;
                }
                if (!helper['recordTypes'].hasOwnProperty(helper['recordTypeId'])) {
                    cmp.find('message').showErrorMessage('Record types attribute was not found.');
                    helper.end();
                    return;
                }
                switch (helper['recordTypes'][helper['recordTypeId']]) {
                    case 'Loan': {
                        cmp.find('modal').showModal('loan');
                        break;
                    }
                    case 'Equity': {
                        cmp.find('modal').showModal('equity');
                        break;
                    }
                    case 'Grant': {
                        cmp.find('modal').showModal('grant');
                        break;
                    }
                }
                break;
            }
        }
        cmp.find('modal').closeModal('selectRecordType');
        helper.end();
    },

    handleCancel: function (cmp, event, helper) {
        helper.begin('handleCancel');
        helper.log(helper['callBackObject']);
        cmp.find('navigation').navigateToObjectHome(helper['callBackObject']);
        helper.end();
    }
});