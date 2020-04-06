({
    afterRender: function (cmp, helper) {
        this.superAfterRender();
        helper.begin('afterRender');
        if (cmp.get('v.isLoadRecordData')) {
            helper.formatButtons(cmp);
        } else {
            cmp.set('v.isRender', true);
        }
        helper.end();
    }
});