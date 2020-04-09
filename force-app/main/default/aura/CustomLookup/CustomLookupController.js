({
    doInit: function (cmp, event, helper) {
        helper['isDebugLog'] = cmp.get('v.isDebugLog');
        helper['debugLogStyle'] = 'background: green; color: white;';
        helper.begin('doInit');
        helper.log('initialization');
        $A.util.toggleClass(cmp.find('resultsDiv'), 'slds-is-open', null);
        helper.end();
    },

    validation: function (cmp, event, helper) {
        helper.begin('validation');
        helper.showHelpMessageIfInvalid(cmp);
        helper.end();
    },

    afterLoadingLibraries: function (cmp, event, helper) {
        helper.begin('afterLoadingLibraries');
        if (helper['isDebugLog'] === undefined) {
            cmp.find('message').showErrorMessage('The "isDebugLog" attribute was not found in the component markup.');
            helper.end();
            return;
        }
        if (!$A.util.isEmpty(cmp.get('v.value'))) {
            helper.searchRecordsHelper(cmp, cmp.get('v.value'));
        }
        helper.end();
    },

    handleShowRecordsByClick: function (cmp, event, helper) {
        helper.begin('handleShowRecordsByClick');
        if (cmp.get('v.allowShowRecordsByClick')) {
            helper.searchRecordsHelper(cmp, '');
        }
        helper.end();
    },

    handleSelectItem: function (cmp, event, helper) {
        helper.begin('handleSelectItem');
        let selectedRecord;
        if (!$A.util.isEmpty(event.currentTarget.id)) {
            let recordsList = cmp.get('v.recordsList');
            let index = recordsList.findIndex(x => x.value === event.currentTarget.id);
            if (index !== -1) {
                selectedRecord = recordsList[index];
            }
            if (helper['results']) {
                let index = helper['results'].findIndex(x => x.Id === event.currentTarget.id);
                if (index !== -1) {
                    selectedRecord['fields'] = helper['results'][index];
                }
            }
            cmp.set('v.selectedRecord', selectedRecord);
            helper.log(selectedRecord);
            cmp.set('v.value', selectedRecord.value);
            $A.util.removeClass(cmp.find('resultsDiv'), 'slds-is-open');
        }
        helper.showHelpMessageIfInvalid(cmp);
        helper.end();
    },

    handleRemoveItem: function (cmp, event, helper) {
        helper.begin('handleRemoveItem');
        cmp.set('v.selectedRecord', '');
        cmp.set('v.value', '');
        cmp.set('v.searchString', '');
        setTimeout(function () {
            cmp.find('inputLookup').getElement().focus();
        }, 250);
        helper.showHelpMessageIfInvalid(cmp);
        helper.end();
    },

    handleBlurEvent: function (cmp, event, helper) {
        helper.begin('handleBlurEvent');
        $A.util.removeClass(cmp.find('resultsDiv'), 'slds-is-open');
        helper.showHelpMessageIfInvalid(cmp);
        helper.end();
    },

    handleSearchRecords: function (cmp, event, helper) {
        helper.begin('handleSearchRecords');
        cmp.set('v.searchString', event.currentTarget.value);
        if (!$A.util.isEmpty(cmp.get('v.searchString'))) {
            helper.searchRecordsHelper(cmp, '');
        } else {
            $A.util.removeClass(cmp.find('resultsDiv'), 'slds-is-open');
        }
        helper.end();
    }
});