({
    afterRender: function (cmp, helper) {
        this.superAfterRender();
        helper.begin('afterRender');
        let goToScroll = cmp.find('goToFocus'); // goToScroll
        if (goToScroll) {
            cmp.find('spinner').showSpinner('setFieldSetFields');
            const timer = setInterval(
                $A.getCallback(function () {
                    if (!cmp.get('v.isLoading')) {
                        clearInterval(timer);
                        window.setTimeout(
                            $A.getCallback(function () {
                                goToScroll.getElement().focus();
                                //goToScroll.getElement().scrollIntoView(true);
                            }), 100);
                        window.setTimeout(
                            $A.getCallback(function () {
                                cmp.find('spinner').hideSpinner('setFieldSetFields');
                            }), 200);
                    }
                }), 100);
        }
        helper.end();
    }
});