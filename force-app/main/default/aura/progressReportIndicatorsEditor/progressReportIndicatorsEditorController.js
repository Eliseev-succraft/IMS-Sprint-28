/*
 * @description         This is controller for component Progress Report Indicators Editor
 * @author              Alexey Eliseev
 * @component           progressReportIndicatorsEditor
 * @date                2/15/19
*/

({
    init: function (cmp, event, helper) {
        console.log('init');
        helper.fetchData(cmp, event);
    },

    handlerClickEditMode: function (cmp, event, helper) {
        console.log('handlerClickEditMode');
        cmp.set('v.isEditMode', true);
    },

    handlerClickCancelEditMode: function (cmp, event, helper) {
        console.log('handlerClickCancelEditMode');
        helper.reset(cmp, event);
        cmp.set('v.isEditMode', false);
    },

    handlerClickSave: function (cmp, event, helper) {
        console.log('handlerClickSave');
        helper.save(cmp, event);
    }

})