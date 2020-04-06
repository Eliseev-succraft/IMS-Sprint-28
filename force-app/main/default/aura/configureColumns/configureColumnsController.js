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
        helper['objRecordType'] = {
            'availableFields': [],
            'recordTypes': {}
        };
        let defaultFields = [
            {'label': 'Indicator Name', 'value': 'sfims__Indicator_Name__c'},
            {'label': 'Indicator Type', 'value': 'sfims__Indicator_Type__c'},
            {'label': 'Library', 'value': 'RecordTypeId'},
            {'label': 'Definition', 'value': 'sfims__Definition__c'},
            {'label': 'Outcome Area', 'value': 'sfims__Outcome_Area__c'}
        ];
        cmp.set('v.defaultFields', defaultFields);
        helper.stopMethod(cmp);
    },


    handleOpenConfigureColumn: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleOpenConfigureColumn');
        helper.showModal(cmp, 'v.isShowConfigureColumns');
        helper.fetchData(cmp);
        helper.stopMethod(cmp);
    },

    handleChangeViewConfigureDualListBox: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleChangeViewConfigureDualListBox');
      //  console.log(helper['onlyRefresh']);
    //    if (!helper['onlyRefresh']) {
            helper.saveViewConfigure(cmp, event);
     //   }
    //    helper['onlyRefresh'] = false;
        helper.stopMethod(cmp);
    },

    handleActive: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleActive');
        if (!$A.util.isEmpty(event.currentTarget.id)) {
            let recordTypeIndex = event.currentTarget.id;
            helper.log('record type index', recordTypeIndex);
            let allRecordTypes = cmp.get('v.allRecordTypes');
            if (recordTypeIndex === '0') {
                let setActive = !allRecordTypes[recordTypeIndex].active;
                allRecordTypes.forEach(function (recordType) {
                    recordType.active = setActive;
                    helper['objRecordType'].recordTypes[recordType.value].active = setActive;
                    if (recordType.value !== '0') {
                        recordType.disabled = (recordType.active);
                    }
                });
            } else {
                allRecordTypes[recordTypeIndex].active = !allRecordTypes[recordTypeIndex].active;
                helper['objRecordType'].recordTypes[allRecordTypes[recordTypeIndex].value].active = allRecordTypes[recordTypeIndex].active;
                let activeCount = 0;
                allRecordTypes.forEach(function (recordType) {
                    if (recordType.active && recordType.value !== '0') {
                        activeCount++;
                    }
                });
                if (activeCount === allRecordTypes.length - 1) {
                    allRecordTypes.forEach(function (recordType) {
                        if (recordType.value !== '0') {
                            recordType.disabled = true;
                        }
                    });
                    allRecordTypes[0].active = true;
                }
            }
            cmp.set('v.allRecordTypes', allRecordTypes);
        }
        event.preventDefault();
        event.stopPropagation();
        helper.stopMethod(cmp);
    },

    handleCloseModal: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleCloseModal');
        helper.closeModal(cmp, 'v.isShowConfigureColumns');
        helper.stopMethod(cmp);
    },

    handleSave: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleSave');
        helper.saveConfigures(cmp);
        helper.stopMethod(cmp);
    },

    clickEvent: function (cmp, event, helper) {
        let element = cmp.find('comboBoxWithActive');
        if (!$A.util.hasClass(element, 'slds-is-open')) {
            $A.util.addClass(element, 'slds-is-open');
        } else {
            $A.util.removeClass(element, 'slds-is-open');
        }
    },

    blurEvent: function (cmp, event, helper) {
        $A.util.removeClass(cmp.find('comboBoxWithActive'), 'slds-is-open');
    },

    handleSelectItem: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleSelectItem');
        if (!$A.util.isEmpty(event.currentTarget.id)) {
            helper.log('record type Id', event.currentTarget.id);
            let id = event.currentTarget.id;
            if (id !== '0') {
                cmp.set('v.selectedRecordType', id);
                helper.refreshViewConfigure(cmp);
            }
        }
        helper.stopMethod(cmp);
    }
});