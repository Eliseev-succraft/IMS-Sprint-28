({
    doInit: function (cmp, event, helper) {
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['debugLogStyle'] = 'background: green; color: white;';
        helper.begin('doInit');
        helper['isRecordUpdated'] = false;
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
        let params = event.getParams();
        helper.log('change type', params['changeType']);
        if (params['changeType'] === 'LOADED') {
            let simpleRecord = cmp.get('v.simpleRecord');
            helper.log('simpleRecord', simpleRecord);
            if (simpleRecord.sfims__Status__c !== 'Active') {
                cmp.find('message').showErrorMessage('Only Loans with status \'Active\' can be paid off.');
                cmp.find('overlayLib').notifyClose();
                helper.end();
                return;
            }
            cmp.set('v.earlyRepaymentDate', $A.localizationService.formatDate(new Date(), "YYYY-MM-DD"));
        }
        else if (params['changeType'] === 'CHANGED') {
            helper.reloadRecordData(cmp);
        }
        else if (params['changeType'] === 'ERROR') {
            cmp.find('message').showErrorMessage('RecordData has not been loaded.');
        }
        cmp.find('spinner').hideSpinner('loadingRecordData');
        helper.end();
    },

    handlePayOff: function (cmp, event, helper) {
        helper.begin('handlePayOff');
        let dataMap = {};
        dataMap['recordId'] = cmp.get("v.recordId");
        dataMap['totalPrincipalWrittenOff'] = Number(cmp.get("v.totalPrincipalWrittenOff"));
        dataMap['totalInterestWrittenOff'] = Number(cmp.get("v.totalInterestWrittenOff"));
        dataMap['totalFeesWrittenOff'] = Number(cmp.get("v.totalFeesWrittenOff"));
        dataMap['totalPenaltiesWrittenOff'] = Number(cmp.get("v.totalPenaltiesWrittenOff"));
        dataMap['totalEarlyRepaymentAmount'] = Number(cmp.get("v.totalEarlyRepaymentAmount"));
        dataMap['earlyRepaymentDate'] = cmp.get("v.earlyRepaymentDate");
        helper.log(dataMap);
        helper.payOff(cmp, dataMap);
        helper.end();
    },

    handleCancel: function (cmp, event, helper) {
        helper.begin('handleCancel');
        cmp.find('overlayLib').notifyClose();
        helper.end();
    }
});