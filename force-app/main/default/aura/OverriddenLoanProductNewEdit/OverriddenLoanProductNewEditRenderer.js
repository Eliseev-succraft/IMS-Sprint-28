({
    afterRender: function (cmp, helper) {
        this.superAfterRender();
        helper.begin('afterRender');
        let goToScroll = cmp.find('goToFocus'); // goToScroll
        if (goToScroll) {
            const timer = setInterval(
                $A.getCallback(function () {
                    if (!cmp.get('v.isLoading')) {
                        clearInterval(timer);
                        window.setTimeout(
                            $A.getCallback(function () {
                                goToScroll.getElement().focus();
                                //goToScroll.getElement().scrollIntoView(true);
                            }), 100);
                    }
                }), 100);
        }
        helper.end();
    }
});