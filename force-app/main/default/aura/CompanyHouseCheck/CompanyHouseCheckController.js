({
    doInit: function(cmp, event, helper){
        helper.getLastUpdateHelper(cmp, cmp.get('v.recordId'));
    },
    updateCompanyInf: function (cmp, event, helper) {
        helper.updateCompanyInfHelper(cmp, cmp.get('v.recordId'));
    }
})