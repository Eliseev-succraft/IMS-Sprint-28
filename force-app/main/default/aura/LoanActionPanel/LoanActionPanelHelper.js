({
    getButtonAccess: function (cmp) {
        this.begin('getButtonAccess');
        let that = this;
        if ($A.util.isEmpty(cmp.get('v.recordId'))) {
            cmp.find('message').showErrorMessage('Record Id was not received.');
            that.end();
            return;
        }
        let spinner = cmp.find('spinner').showSpinner();
        let action = cmp.get('c.getButtonAccess');
        action.setParams({
            loanId: cmp.get('v.recordId')
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.begin('getButtonAccess-SUCCESS');
                let result = response.getReturnValue();
                that.log(result);
                if (result.hasOwnProperty('customPermissions') && result.hasOwnProperty('visible')) {
                    that['buttons'].forEach(function (btn) {
                        if (result['customPermissions'].hasOwnProperty(btn.actionAPI) && !result['customPermissions'][btn.actionAPI]) {
                            btn.access = false;
                        }
                        if (result['visible'].hasOwnProperty(btn.actionAPI) && !result['visible'][btn.actionAPI]) {
                            btn.display = false;
                        }
                    });
                }
                if (cmp.get('v.isRender')) {
                    that.formatButtons(cmp);
                } else {
                    cmp.set('v.isLoadRecordData', true);
                }
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
            else {
                that.begin('getButtonAccess-ERROR');
                cmp.find('message').showErrorMessage(cmp.find('system').getAuraErrorsFromRequest(response.getError()));
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
        });
        $A.enqueueAction(action);
        this.end();
    },

    reloadRecordData: function (cmp) {
        this.begin('reloadRecordData');
        cmp.find('spinner').showSpinner('loadingRecordData');
        let recordData = cmp.find('recordData');
        if (recordData) {
            recordData.reloadRecord(true);
        } else {
            cmp.find('message').showErrorMessage('RecordData has not been found.');
        }
        this.end();
    },

    formatButtons: function (cmp) {
        this.begin('formatButtons');
        let cnt = 0;
        let actionPanel = cmp.find('actionPanel');
        if (!actionPanel) {
            cmp.find('message').showErrorMessage('Action Panel container was not found.');
            this.end();
            return;
        }
        let element = actionPanel.getElement();
        if (!element) {
            cmp.find('message').showErrorMessage('Action Panel element was not found.');
            this.end();
            return;
        }
        let width = Math.trunc(element.getBoundingClientRect().width) - 144;
        let countActiveButtons = Number(cmp.get('v.countActiveButtons'));
        let buttonsBottom = [];
        let buttonsAdditionalMenu = [];
        this['buttons'].forEach(function (btn) {
            if (btn['display']) {
                cnt++;
                btn['length'] = (btn['label'].length * 7) + 32;
                width -= btn['length'];
                if (width - 48 > 0 && cnt <= countActiveButtons) {
                    buttonsBottom.push(btn);
                } else {
                    buttonsAdditionalMenu.push(btn);
                }
            }
        });
        cmp.set('v.buttonsBottom', buttonsBottom);
        cmp.set('v.buttonsAdditionalMenu', buttonsAdditionalMenu);
        this.log('buttons', this['buttons']);
        cmp.set('v.buttons', this['buttons']);
        this.end();
    },

    begin: function (name) {
        if (this['isDebugLog']) {
            console.group('%s, time: %f', name, this.timeStamp());
        }
    },

    end: function () {
        if (this['isDebugLog']) {
            console.groupEnd();
        }
    },

    log: function (label, values, style) {
        if (this['isDebugLog']) {
            style = style || this['debugLogStyle'];
            if (values === undefined) {
                values = label;
                label = null;
            }
            if (Array.isArray(values)) {
                if (label !== null) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else if (typeof values === 'object') {
                if (label !== null) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else {
                if (label !== null) {
                    console.log('%c' + label + ' - ' + values, style);
                } else {
                    console.log('%c' + values, style);
                }
            }
        }
    },

    timeStamp: function () {
        return performance.now() / 1000;
    }
});