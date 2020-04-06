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
        cmp.set('v.columns', [
            {label: 'Indicator Name', fieldName: 'sfims__Indicator_Name__c', type: 'url'},
            {label: 'Indicator Type', fieldName: 'sfims__Indicator_Type__c', type: 'text'},
            {label: 'Library', fieldName: 'RecordTypeId', type: 'text'},
            {label: 'Standard - Custom', fieldName: 'sfims__Standard_Custom__c', type: 'text'},
            {label: 'Definition', fieldName: 'sfims__Definition__c', type: 'text'},
            {label: 'Outcome Area', fieldName: 'sfims__Outcome_Area__c', type: 'text'},
        ]);
        if (cmp.get('v.recordId')) {
            helper.fetchData(cmp);
        }
        helper.stopMethod(cmp);
    },

    navigateToSObject: function (cmp, event, helper) {
        helper.startMethod(cmp, 'navigateToSObject');
        let element = event.currentTarget;
        let id = element.dataset.value;
        if (id) {
            helper.navigateToSObject(cmp, id);
        } else {
            helper.showErrMessage('Id was not received.')
        }
        helper.stopMethod(cmp);
    },

    handleShowHideMoreFilters: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleShowHideMoreFilters');
        helper.showHideMoreFilters(cmp);
        helper.stopMethod(cmp);
    },

    handleDeleteSelected: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleDeleteSelected');
        if (event.getSource().get('v.value') !== undefined) {
            helper.showSpinner(cmp, 'v.isLoading', 5000, 'handleDeleteSelected');
            setTimeout($A.getCallback(() =>
                helper.deleteSelected(cmp, event)), 10);
        }
        else {
            helper.showWarningMessage('Please select indicators.');
        }
        helper.stopMethod(cmp);
    },

    handleDragStart: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleDragStart');
        if (event.currentTarget.id) {
            helper['handleDrag'] = event.currentTarget.id;
        } else {
            helper['handleDrag'] = null;
        }
        helper.stopMethod(cmp);
    },

    handleDragOver: function (cmp, event, helper) {
        // helper.startMethod(cmp, 'handleDragOver');
        event.preventDefault();
        // helper.stopMethod(cmp);
    },

    handleDrop: function (cmp, event, helper) {
        helper.startMethod(cmp, 'handleDrop');
        let data = cmp.get('v.data');
        let originalData = cmp.get('v.originalData');
        let oldIndex = helper['handleDrag'];
        let newIndex = event.target.closest('[id]').id;
        if (oldIndex != null && newIndex != null) {
            helper.log(oldIndex + ' - ' + newIndex);
            if (data[newIndex] != null && data[oldIndex] != null) {
                let item = data[newIndex];
                data.splice(newIndex, 1, data[oldIndex]);
                data.splice(oldIndex, 1, item);
                cmp.set('v.data', data);
                let originalIndexNew = originalData.findIndex(function (row) {
                    return row.Id === data[newIndex].Id
                });
                let originalIndexOld = originalData.findIndex(function (row) {
                    return row.Id === data[oldIndex].Id
                });
                if (originalIndexNew !== -1 && originalIndexOld !== -1) {
                    let item = originalData[originalIndexNew];
                    originalData.splice(originalIndexNew, 1, originalData[originalIndexOld]);
                    originalData.splice(originalIndexOld, 1, item);
                    cmp.set('v.originalData', originalData);
                }
            }
        }
        event.preventDefault();
        helper.stopMethod(cmp);
    }
});