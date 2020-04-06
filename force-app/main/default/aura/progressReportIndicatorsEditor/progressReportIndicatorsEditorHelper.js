/*
 * @description         This is helper for component Progress Report Indicators Editor
 * @author              Alexey Eliseev
 * @component           progressReportIndicatorsEditor
 * @date                2/15/19
*/

({
    fetchData: function (cmp, event) {
        console.log('fetchData');
        this.showSpinner(cmp, 'v.isLoading');
        var recordId = cmp.get('v.recordId');
        var getProgressReportIndicators = cmp.get('c.getProgressReportIndicators');
        getProgressReportIndicators.setParams({
            progressReportId: recordId
        });
        getProgressReportIndicators.setCallback(this, function (response) {
            var state = response.getState();
            if (state === 'SUCCESS') {
                var objValues = [];
                var availabelFields = [
                    'Actual',
                    'Target',
                    'Variance'
                ];
                var associasTypeTbl = {
                    'Number': '_Value_Number__c',
                    'Currency': '_Value_Currency__c',
                    'Text': '_Value_Text__c',
                    'Percentage': '_Value_Percentage__c',
                    'Text Area (Long)': '_Value_Text_Area_Long__c'
                };
                var availabelFieldsSize = availabelFields.length;
                var responseValue = JSON.parse(response.getReturnValue());
                // console.log(responseValue);
                var that = this;
                responseValue.forEach(function (record) {
                    var fields = [];
                    if (!$A.util.isEmpty(record['sfims__Indicator_Catalogue__c'])) {
                        for (var k = 0; k < availabelFieldsSize; k++) {
                            var value = '';
                            var fieldName = '';
                            if (associasTypeTbl[record['sfims__Indicator_Catalogue__r']['sfims__Indicator_Type__c']] != null) {
                                fieldName = 'sfims__' + availabelFields[k] + associasTypeTbl[record['sfims__Indicator_Catalogue__r']['sfims__Indicator_Type__c']];
                                if (record['sfims__' + availabelFields[k] + associasTypeTbl[record['sfims__Indicator_Catalogue__r']['sfims__Indicator_Type__c']]] != null) {
                                    value = record['sfims__' + availabelFields[k] + associasTypeTbl[record['sfims__Indicator_Catalogue__r']['sfims__Indicator_Type__c']]];
                                }
                                if (value == '') {
                                    if (record['sfims__Indicator_Catalogue__r']['sfims__Indicator_Type__c'] != 'Text' &&
                                        record['sfims__Indicator_Catalogue__r']['sfims__Indicator_Type__c'] != 'Text Area (Long)'
                                    ) {
                                        value = '0';
                                    }
                                } else {

                                }
                                fields.push({
                                    'name': fieldName,
                                    'value': value,
                                    'reset': value
                                })
                            } else {
                                fields.push({
                                    'name': '',
                                    'value': '',
                                    'reset': ''
                                })
                            }
                        }
                        fields.push({
                            'name': 'sfims__Comment__c',
                            'value': (record['sfims__Comment__c'] == null ? '' : record['sfims__Comment__c']),
                            'reset': (record['sfims__Comment__c'] == null ? '' : record['sfims__Comment__c'])
                        });
                        objValues.push(
                            {
                                'id': record['Id'],
                                'type': record['sfims__Indicator_Catalogue__r']['sfims__Indicator_Type__c'],
                                'name': record['sfims__Indicator_Catalogue__r']['sfims__Indicator_Name__c'],
                                'cols': fields
                            }
                        )
                    } else {
                        that.showMessage(null, 'Not all indicators were displayed.', 'warning');
                    }
                });
                cmp.set('v.objValues', objValues);
                this.hideSpinner(cmp, 'v.isLoading');
            }
            else {
                var errors = response.getError();
                var message = 'Unknown error';
                if (errors && Array.isArray(errors) && errors.length > 0) {
                    message = errors[0].message;
                }
                this.showMessage(null, message, 'error');
                this.hideSpinner(cmp, 'v.isLoading');
            }
        });
        $A.enqueueAction(getProgressReportIndicators);
    },

    save: function (cmp, event) {
        console.log('save');
        var objValues = cmp.get('v.objValues');

        var saveProgressReportIndicators = cmp.get('c.saveProgressReportIndicators');
        saveProgressReportIndicators.setParams({
            progressReportIndicatorsJSON: JSON.stringify(objValues)
        });

        saveProgressReportIndicators.setCallback(this, function (response) {
            var state = response.getState();
            if (state === 'SUCCESS') {
                if (response.getReturnValue() == true) {
                    this.fetchData(cmp, event)
                    cmp.set('v.isEditMode', false);
                    this.showMessage(null, 'Progress Report Indicators was saved.', 'success');
                } else {
                    this.showMessage(null, 'Progress Report Indicators was not saved.', 'error');
                }
            }
            else {
                var errors = response.getError();
                var message = 'Unknown error';
                if (errors && Array.isArray(errors) && errors.length > 0) {
                    message = errors[0].message;
                }
                this.showMessage(null, errors[0].message, 'error');
                console.error(message);
            }
        });
        $A.enqueueAction(saveProgressReportIndicators);
    },

    reset: function (cmp, event) {
        console.log('reset');
        var objValues = cmp.get('v.objValues');
        var objValuesSize = objValues.length;

        for (var i = 0; i < objValuesSize; i++) {
            for (var j in objValues[i].cols) {
                objValues[i].cols[j].value = objValues[i].cols[j].reset;
            }
        }
        cmp.set('v.objValues', objValues);
    },

    showSpinner: function (cmp, attribute) {
        console.log('showSpinner');
        if (!cmp.get(attribute)) {
            cmp.set(attribute, true);
            var that = this;
            window.setTimeout(
                $A.getCallback(function () {
                    if (cmp.get(attribute)) {
                        that.hideSpinner(cmp, attribute);
                    }
                }), 5000);
        }
    },

    hideSpinner: function (cmp, attribute) {
        console.log('hideSpinner');
        cmp.set(attribute, false);
    },

    showMessage: function (title, message, type) {
        console.log('showMessage');
        var mode = 'pester';
        switch (type) {
            case 'error':
                console.error(message);
                mode = 'sticky';
                break;
            case 'warning':
                console.warn(message);
                break;
            default:
                console.log(type + ' ' + message);
        }
        var toast = $A.get('e.force:showToast');
        if (toast != 'undefined') {
            toast.setParams({
                'title': title,
                'message': message,
                'type': type,
                'mode': mode
            });
            toast.fire();
        }
        else {
            alert(message);
        }
    }
})