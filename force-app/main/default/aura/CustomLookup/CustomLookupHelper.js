({
    showHelpMessageIfInvalid: function (cmp) {
        this.begin('showHelpMessageIfInvalid');
        if (cmp.get('v.required')) {
            let inputLookup = cmp.find('inputLookup');
            if ($A.util.isEmpty(cmp.get('v.value'))) {
                $A.util.addClass(inputLookup, 'custom-required-field__error');
                cmp.set('v.isValid', false);
            } else {
                $A.util.removeClass(inputLookup, 'custom-required-field__error');
                cmp.set('v.isValid', true);
            }
        }
        this.end();
    },

    searchRecordsHelper: function (cmp, value) {
        this.begin('searchRecordsHelper');
        cmp.set('v.message', '');
        cmp.set('v.recordsList', null);
        let that = this;
        if ($A.util.isEmpty(cmp.get('v.objectName')) || $A.util.isEmpty(cmp.get('v.fields')) || $A.util.isEmpty(cmp.get('v.fieldName')) || $A.util.isEmpty(cmp.get('v.maxRecordCount'))) {
            cmp.find('message').showErrorMessage('Required parameters were not received.');
            that.end();
            return;
        }
        let spinner = cmp.find('spinner').showSpinner();
        let action = cmp.get('c.fetchRecords');
        action.setParams({
            objectName: cmp.get('v.objectName'),
            filterField: cmp.get('v.fieldName'),
            searchString: cmp.get('v.searchString'),
            fields: cmp.get('v.fields'),
            additionalWhere: (cmp.get('v.where') ? ' AND ' + cmp.get('v.where') : ''),
            recordCount: cmp.get('v.maxRecordCount')
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.begin('searchRecordsHelper-SUCCESS');
                let results = response.getReturnValue();
                that.log(results);
                if (results.length > 0) {
                    that['results'] = results;
                    let values = [];
                    let fieldName = cmp.get('v.fieldName');
                    results.forEach(function (res) {
                        values.push({
                            label: res[fieldName],
                            value: res['Id']
                        })
                    });
                    if ($A.util.isEmpty(value)) {
                        cmp.set('v.recordsList', values);
                    } else {
                        let index = values.findIndex(x => x.value === value);
                        let selectedRecord;
                        if (index !== -1) {
                            selectedRecord = values[index];
                        }
                        if (that['results']) {
                            let index = that['results'].findIndex(x => x.Id === value);
                            if (index !== -1) {
                                selectedRecord['fields'] = that['results'][index];
                            }
                        }
                        cmp.set('v.selectedRecord', selectedRecord);
                        that.log(selectedRecord);
                    }
                } else {
                    cmp.set('v.message', 'No Records Found');
                }
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
            else {
                that.begin('searchRecordsHelper-ERROR');
                cmp.find('message').showErrorMessage(cmp.find('system').getAuraErrorsFromRequest(response.getError()));
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
            if ($A.util.isEmpty(value)) {
                $A.util.addClass(cmp.find('resultsDiv'), 'slds-is-open');
            }
        });
        $A.enqueueAction(action);
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