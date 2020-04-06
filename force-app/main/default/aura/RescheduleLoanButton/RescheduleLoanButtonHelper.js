({
    cancelFromOverlayLib: function (cmp) {
        this.begin('cancelFromOverlayLib');
        let overlayLib = cmp.find('overlayLib');
        if (overlayLib) {
            overlayLib.notifyClose();
        }
        this.end();
    },

    setRescheduleDate: function (cmp) {
        this.begin('setRescheduleDate');
        let today = $A.localizationService.formatDate(new Date(), "YYYY-MM-DD");
        cmp.set('v.rescheduleDate', today);
        this.end();
    },

    fetchData: function (cmp) {
        this.begin('fetchData');
        let that = this;
        if ($A.util.isEmpty(cmp.get('v.recordId'))) {
            cmp.find('message').showErrorMessage('Record Id was not received.');
            window.setTimeout(
                $A.getCallback(function () {
                    that.cancelFromOverlayLib(cmp);
                }), 100);
            that.end();
            return;
        }
        let spinner = cmp.find('spinner').showSpinner();
        cmp.set('v.firstRepaymentDateValue', null);
        that['firstRepaymentDateLimit'] = null;
        let action = cmp.get('c.getLoan');
        action.setParams({
            loanId: cmp.get('v.recordId')
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.begin('getLoan-SUCCESS');
                let result = response.getReturnValue();
                that.log('simple record', result);
                cmp.set('v.simpleRecord', result);
                if (result['sfims__Open_Ended_Loan__c']) {
                    cmp.find('message').showErrorMessage('Not available for Open Ended loans.');
                    that.cancelFromOverlayLib(cmp);
                    that.end();
                    return;
                } else {
                    if (result['sfims__Status__c'] !== 'Active') {
                        cmp.find('message').showErrorMessage('Only Loans with status \'Active\' can be rescheduled.');
                        that.cancelFromOverlayLib(cmp);
                        that.end();
                        return;
                    }
                }
                if (result['sfims__Loan_Product__r']) {
                    if (result['sfims__Loan_Product__r']['sfims__Grace_Period_Types__c']) {
                        let periodsFromLoanProduct = [];
                        let options = result['sfims__Loan_Product__r']['sfims__Grace_Period_Types__c'].split(';');
                        that.log('grace period', options);
                        if (options.length !== 1) {
                            periodsFromLoanProduct = [{
                                label: '--None--',
                                value: ''
                            }];
                        }
                        options.forEach(function (elm) {
                            let value = elm;
                            switch (elm) {
                                case 'No Grace':
                                    value = 'None';
                                    break;
                                case 'Pay Admin Fees Only':
                                    value = 'Admin';
                                    break;
                                case 'Pay Interest Only':
                                    value = 'Interest';
                                    break;
                                case 'Full Grace':
                                    value = 'Full';
                                    break;
                            }
                            periodsFromLoanProduct.push({
                                label: elm,
                                value: value
                            })
                        });
                        cmp.set('v.graceTypesFromLoanProduct', periodsFromLoanProduct);
                    }
                }
                if (result.hasOwnProperty('sfims__Repayment_Schedules__r')) {
                    if (result.sfims__Repayment_Schedules__r[0] !== undefined) {
                        cmp.set('v.firstRepaymentDateValue', result.sfims__Repayment_Schedules__r[0]['sfims__Due_Date__c']);
                    }
                    if (result.sfims__Repayment_Schedules__r[1] !== undefined) {
                        that['firstRepaymentDateLimit'] = result.sfims__Repayment_Schedules__r[1]['sfims__Due_Date__c'];
                    }
                }
                that.setRescheduleDate(cmp);
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
            else {
                that.begin('getLoan-ERROR');
                cmp.find('message').showErrorMessage(cmp.find('system').getAuraErrorsFromRequest(response.getError()));
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
        });
        $A.enqueueAction(action);
        this.end();
    },

    generateData: function (cmp) {
        this.begin('generateData');
        let selectedType = cmp.get('v.selectedType');
        let amount = Number(cmp.get('v.rescheduleAmount'));
        let isClosePrm = false;
        if (amount === 0 && selectedType === 'Manual Reschedule' && cmp.get('v.baseOnValue') === 'Number of Instalments' && Number(cmp.find('numberOfInstalments').get('v.value')) === 0) {
            isClosePrm = true;
        }
        if (amount === 0 && selectedType === 'Manual Reschedule' && !isClosePrm) {
            cmp.find('message').showErrorMessage('You can\'t write off the full loan through a Loan Rescheduling action.\n' +
                'Please use the Write Off button to fully write off a loan.');
            this.end();
            return;
        }
        let dataMap = {};
        let rec = cmp.get('v.simpleRecord');
        dataMap['recordId'] = cmp.get('v.recordId');
        dataMap['selectedType'] = selectedType;
        dataMap['totalPrincipalWrittenOff'] = Number(cmp.get('v.totalPrincipalWrittenOff'));
        dataMap['totalInterestWrittenOff'] = Number(cmp.get('v.totalInterestWrittenOff'));
        dataMap['totalFeesWrittenOff'] = Number(cmp.get('v.totalFeesWrittenOff'));
        dataMap['totalPenaltiesWrittenOff'] = Number(cmp.get('v.totalPenaltiesWrittenOff'));
        let rationale = cmp.find('rationale');
        if (rationale) {
            dataMap['rationale'] = rationale.get('v.value');
        }
        dataMap['action'] = 'Reschedule';
        dataMap['rescheduleDate'] = cmp.get('v.rescheduleDate');
        if (selectedType === 'Change Payment Date' || selectedType === 'Introduce Grace Period' || selectedType === 'Change Periodic Repayment Amount') {
            amount = rec['sfims__Principal_Remaining__c'] + rec['sfims__Fees_Remaining__c'];
        }
        rec['sfims__Disbursement_Date__c'] = cmp.get('v.rescheduleDate');
        if (rec['sfims__Loan_Product__r.sfims__Interest_Rate_Source__c'] === 'Variable Interest') {
            if (rec['sfims__Variable_Interest_Spread__c'] === '') rec['sfims__Variable_Interest_Spread__c'] = 0;
        } else {
            if (rec['sfims__Interest_Rate__c'] === '') rec['sfims__Interest_Rate__c'] = 0;
        }
        let numberOfInstalments = cmp.find('numberOfInstalments');
        if (numberOfInstalments) {
            if (cmp.get('v.baseOnValue') === 'Number of Instalments') {
                rec['sfims__Number_of_Instalments__c'] = Number(numberOfInstalments.get('v.value'));
            } else {
                rec['sfims__Number_of_Instalments__c'] = null;
            }
        } else {
            if (selectedType === 'Change Payment Date') {
                rec['sfims__Number_of_Instalments__c'] = rec['sfims__Repayment_Schedules__r'].length;
            } else if (selectedType === 'Introduce Grace Period') {
                rec['sfims__Number_of_Instalments__c'] = rec['sfims__Repayment_Schedules__r'].length + Number(cmp.find('sfims__Number_of_Grace_Periods__c').get('v.value'));
            } else if (selectedType === 'Change Periodic Repayment Amount') {
                rec['sfims__Number_of_Instalments__c'] = null;
            }
        }
        let firstRepaymentDate = cmp.find('firstRepaymentDate');
        if (firstRepaymentDate) {
            rec['sfims__First_Repayment_Date__c'] = firstRepaymentDate.get('v.value');
        } else {
            if (selectedType === 'Introduce Grace Period' || selectedType === 'Change Periodic Repayment Amount') {
                rec['sfims__First_Repayment_Date__c'] = cmp.get('v.firstRepaymentDateValue');
            }
        }
        if (rec['sfims__Setup_Fee_Charging_Method__c'] === 'Capitalized') {
            // set a new value to Capitalized Fee Amount based on the Fees Written Off value deducted from the Fees Remaining value
            rec['sfims__Capitalized_Fee_Amount__c'] = rec['sfims__Fees_Remaining__c'] - cmp.get('v.totalFeesWrittenOff');
            // set a new value to Capitalize Amount that is Total Remaining minus Total Written Off
            rec['sfims__Capitalized_Amount__c'] = amount;
            rec['sfims__Amount__c'] = rec['sfims__Capitalized_Amount__c'] - rec['sfims__Capitalized_Fee_Amount__c'];
        } else {
            rec['sfims__Capitalized_Amount__c'] = amount;
            rec['sfims__Amount__c'] = amount;
        }
        let gracePeriodType = cmp.find('sfims__Grace_Period_Type__c');
        if (gracePeriodType) {
            rec['sfims__Grace_Period_Type__c'] = gracePeriodType.get('v.value');
        }
        let recTmp = JSON.parse(JSON.stringify(rec));
        this.log(recTmp);
        // delete system fields
        delete recTmp['sfims__Repayment_Schedules__r'];
        delete recTmp['CreatedBy'];
        delete recTmp['CreatedById'];
        delete recTmp['CreatedDate'];
        delete recTmp['LastModifiedBy'];
        delete recTmp['LastModifiedById'];
        delete recTmp['LastModifiedDate'];
        delete recTmp['Owner'];
        delete recTmp['OwnerId'];
        delete recTmp['SystemModstamp'];
        dataMap['loan'] = JSON.stringify(recTmp);
        if (isClosePrm) {
            dataMap['close'] = true;
        }
        if (selectedType === 'Change Periodic Repayment Amount' || selectedType === 'Manual Reschedule') {
            let element = cmp.find('newPeriodicRepaymentAmount');
            if (element) {
                console.log(element.get('v.value'));
                if (!$A.util.isEmpty(element.get('v.value'))) {
                    dataMap['pmtValue'] = element.get('v.value');
                }
            }
        }
        this.end();
        return dataMap;
    },

    preview: function (cmp) {
        this.begin('preview');
        let dataMap = this.generateData(cmp);
        this.log('dataMap', dataMap);
        if ($A.util.isEmpty(dataMap)) {
            console.error('Required attributes were not received.');
            this.end();
            return;
        }
        let that = this;
        let spinner = cmp.find('spinner').showSpinner();
        let action = cmp.get('c.generateSchedulePreview');
        action.setParams({
            dataMap: dataMap
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.begin('getLoan-SUCCESS');
                let records = response.getReturnValue();
                that.log('generateSchedulePreview', records);
                for (let rs in records) {
                    if (records.hasOwnProperty(rs)) {
                        records[rs]['sfims__Total_Expected__c'] = Number(records[rs]['sfims__Principal_Expected__c']) + Number(records[rs]['sfims__Interest_Expected_Standard_Loan__c']) + Number(records[rs]['sfims__Fees_Expected__c']);
                    }
                }
                cmp.set('v.repaymentSchedules', records);
                cmp.set('v.columns', [
                    {
                        label: 'Due Date',
                        fieldName: 'sfims__Due_Date__c',
                        type: 'date-local',
                        cellAttributes: {alignment: 'right'}
                    },
                    {
                        label: 'Total Due',
                        fieldName: 'sfims__Total_Expected__c',
                        type: 'currency',
                        cellAttributes: {alignment: 'right'},
                        typeAttributes: {minimumFractionDigits: '2'}
                    },
                    {
                        label: 'Principal Due',
                        fieldName: 'sfims__Principal_Expected__c',
                        type: 'currency',
                        cellAttributes: {alignment: 'right'},
                        typeAttributes: {minimumFractionDigits: '2'}
                    },
                    {
                        label: 'Interest Due',
                        fieldName: 'sfims__Interest_Expected_Standard_Loan__c',
                        type: 'currency',
                        cellAttributes: {alignment: 'right'},
                        typeAttributes: {minimumFractionDigits: '2'}
                    },
                    {
                        label: 'Fees Due',
                        fieldName: 'sfims__Fees_Expected__c',
                        type: 'currency',
                        cellAttributes: {alignment: 'right'},
                        typeAttributes: {minimumFractionDigits: '2'}
                    }
                ]);
                cmp.set('v.isOpenPreview', true);
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
            else {
                that.begin('generateSchedulePreview-ERROR');
                cmp.find('message').showErrorMessage(cmp.find('system').getAuraErrorsFromRequest(response.getError()));
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
        });
        $A.enqueueAction(action);
        this.end();
    },

    reschedule: function (cmp) {
        this.begin('reschedule');
        let dataMap = this.generateData(cmp);
        if ($A.util.isEmpty(dataMap)) {
            console.error('Required attributes were not received.');
            this.cancelFromOverlayLib(cmp);
            this.end();
            return;
        }
        let that = this;
        let spinner = cmp.find('spinner').showSpinner();
        let action = cmp.get('c.rescheduleLoan');
        action.setParams({
            dataMap: dataMap
        });
        action.setCallback(this, function (response) {
            let state = response.getState();
            if (state === 'SUCCESS') {
                that.begin('rescheduleLoan-SUCCESS');
                cmp.find('message').showSuccessMessage('Rescheduling was completed.');
                cmp.find('spinner').hideSpinner(spinner);
                $A.get('e.force:refreshView').fire();
                that.cancelFromOverlayLib(cmp);
                that.end();
            }
            else {
                that.begin('rescheduleLoan-ERROR');
                cmp.find('message').showErrorMessage(cmp.find('system').getAuraErrorsFromRequest(response.getError()));
                cmp.find('spinner').hideSpinner(spinner);
                that.end();
            }
        });
        $A.enqueueAction(action);
        this.end();
    },

    isValidForm: function (cmp) {
        this.begin('isValidForm');
        let selectedType = cmp.get('v.selectedType');
        let that = this;
        switch (selectedType) {
            case 'Change Payment Date': {
                that['errFields'] = [];
                /* standard fields validation */
                let standardValidationFields = [
                    {name: 'rescheduleDate'},
                    {name: 'firstRepaymentDate'}
                ];
                standardValidationFields.forEach(function (item) {
                    if (!item.hasOwnProperty('label')) {
                        item['label'] = cmp.find(item.name).get('v.label');
                    }
                });
                let isStandardValid = true;
                standardValidationFields.forEach(function (field) {
                    cmp.find(field.name).setCustomValidity('');
                    if (!that.elementValidationStandard(cmp, field.name, field.label)) {
                        isStandardValid = false;
                    }
                });
                if (isStandardValid) {
                    if ($A.util.isEmpty(cmp.get('v.firstRepaymentDateValue')) || $A.util.isEmpty(that['firstRepaymentDateLimit'])) {
                        cmp.find('message').showErrorMessage('Repayment Schedules were not received.');
                        that.end();
                        return;
                    }
                    if (cmp.get('v.firstRepaymentDateValue') > that['firstRepaymentDateLimit']) {
                        cmp.find('message').showErrorMessage('First Repayment Date cannot be after ' + that['firstRepaymentDateLimit']);
                        that.end();
                        return;
                    }
                    if (cmp.get('v.rescheduleDate') > cmp.get('v.firstRepaymentDateValue')) {
                        let rescheduleDate = cmp.find('rescheduleDate');
                        rescheduleDate.setCustomValidity('Reschedule Date cannot be after First Repayment Date (' + cmp.get('v.firstRepaymentDateValue') + ')');
                        rescheduleDate.reportValidity();
                        cmp.find('message').showErrorMessage('Reschedule Date cannot be after First Repayment Date (' + cmp.get('v.firstRepaymentDateValue') + ')');
                        that.end();
                        return;
                    }
                }
                if (!isStandardValid) {
                    if (that['errFields']) {
                        let size = that['errFields'].length;
                        let msg = '';
                        if (size > 0) {
                            for (let i = 0; i < size; i++) {
                                msg += '- ' + that['errFields'][i] + '\n';
                            }
                        }
                        if (msg !== '') {
                            cmp.find('message').showErrorMessage('Please check and fill in the required fields' + ': \n' + msg);
                        }
                    } else {
                        cmp.find('message').showErrorMessage('Please check and fill in the required fields.');
                    }
                } else {
                    that.end();
                    return true;
                }
                break;
            }
            case 'Introduce Grace Period': {
                that['errFields'] = [];
                /* standard fields validation */
                let standardValidationFields = [
                    {name: 'rescheduleDate'}
                ];
                standardValidationFields.forEach(function (item) {
                    if (!item.hasOwnProperty('label')) {
                        item['label'] = cmp.find(item.name).get('v.label');
                    }
                });
                let isStandardValid = true;
                standardValidationFields.forEach(function (field) {
                    cmp.find(field.name).setCustomValidity('');
                    if (!that.elementValidationStandard(cmp, field.name, field.label)) {
                        isStandardValid = false;
                    }
                });
                if (isStandardValid) {
                    if ($A.util.isEmpty(cmp.get('v.firstRepaymentDateValue'))) {
                        cmp.find('message').showErrorMessage('Repayment Schedules were not received.');
                        that.end();
                        return;
                    }
                    console.log(cmp.get('v.rescheduleDate'));
                    console.log(cmp.get('v.firstRepaymentDateValue'));
                    if (cmp.get('v.rescheduleDate') > cmp.get('v.firstRepaymentDateValue')) {
                        let rescheduleDate = cmp.find('rescheduleDate');
                        rescheduleDate.setCustomValidity('Reschedule Date cannot be after First Repayment Date (' + cmp.get('v.firstRepaymentDateValue') + ')');
                        rescheduleDate.reportValidity();
                        cmp.find('message').showErrorMessage('Reschedule Date cannot be after First Repayment Date (' + cmp.get('v.firstRepaymentDateValue') + ')');
                        that.end();
                        return;
                    }
                }
                /* custom fields validation */
                let customValidationFields = [
                    {name: 'sfims__Grace_Period_Type__c'}
                ];
                if (cmp.find('sfims__Grace_Period_Type__c').get('v.value') !== 'None' && cmp.find('sfims__Grace_Period_Type__c').get('v.value') !== '') {
                    customValidationFields.push({
                        name: 'sfims__Number_of_Grace_Periods__c'
                    });
                }
                let recordUiFields = {};
                if (that['recordUi']) {
                    if (that['recordUi'].hasOwnProperty('recordUi')) {
                        if (that['recordUi']['recordUi'].hasOwnProperty('objectInfo')) {
                            if (that['recordUi']['recordUi']['objectInfo'].hasOwnProperty('fields')) {
                                recordUiFields = that['recordUi']['recordUi']['objectInfo']['fields'];
                            }
                        }
                    }
                }
                customValidationFields.forEach(function (item) {
                    if (!item.hasOwnProperty('label')) {
                        item['label'] = '';
                    }
                    if (recordUiFields.hasOwnProperty(item.name)) {
                        if (recordUiFields[item.name].hasOwnProperty('label')) {
                            item['label'] = recordUiFields[item.name].label;
                        }
                    }
                });
                that.log('customValidationFields', customValidationFields);
                if (!that.formValidation(cmp, customValidationFields) || !isStandardValid) {
                    if (that['errFields']) {
                        let size = that['errFields'].length;
                        let msg = '';
                        if (size > 0) {
                            for (let i = 0; i < size; i++) {
                                msg += '- ' + that['errFields'][i] + '\n';
                            }
                        }
                        if (msg !== '') {
                            cmp.find('message').showErrorMessage('Please check and fill in the required fields' + ': \n' + msg);
                        }
                    } else {
                        cmp.find('message').showErrorMessage('Please check and fill in the required fields.');
                    }
                } else {
                    that.end();
                    return true;
                }
                break;
            }
            case 'Change Periodic Repayment Amount': {
                that['errFields'] = [];
                /* standard fields validation */
                let standardValidationFields = [
                    {name: 'rescheduleDate'},
                    {name: 'currentPeriodicRepaymentAmount'},
                    {name: 'newPeriodicRepaymentAmount'}
                ];
                standardValidationFields.forEach(function (item) {
                    if (!item.hasOwnProperty('label')) {
                        item['label'] = cmp.find(item.name).get('v.label');
                    }
                });
                let isStandardValid = true;
                standardValidationFields.forEach(function (field) {
                    cmp.find(field.name).setCustomValidity('');
                    if (!that.elementValidationStandard(cmp, field.name, field.label)) {
                        isStandardValid = false;
                    }
                });
                if (isStandardValid) {
                    if ($A.util.isEmpty(cmp.get('v.firstRepaymentDateValue'))) {
                        cmp.find('message').showErrorMessage('Repayment Schedules were not received.');
                        that.end();
                        return;
                    }
                    if (cmp.get('v.rescheduleDate') > cmp.get('v.firstRepaymentDateValue')) {
                        let rescheduleDate = cmp.find('rescheduleDate');
                        rescheduleDate.setCustomValidity('Reschedule Date cannot be after First Repayment Date (' + cmp.get('v.firstRepaymentDateValue') + ')');
                        rescheduleDate.reportValidity();
                        cmp.find('message').showErrorMessage('Reschedule Date cannot be after First Repayment Date (' + cmp.get('v.firstRepaymentDateValue') + ')');
                        that.end();
                        return;
                    }
                }
                if (!isStandardValid) {
                    if (that['errFields']) {
                        let size = that['errFields'].length;
                        let msg = '';
                        if (size > 0) {
                            for (let i = 0; i < size; i++) {
                                msg += '- ' + that['errFields'][i] + '\n';
                            }
                        }
                        if (msg !== '') {
                            cmp.find('message').showErrorMessage('Please check and fill in the required fields' + ': \n' + msg);
                        }
                    } else {
                        cmp.find('message').showErrorMessage('Please check and fill in the required fields.');
                    }
                } else {
                    that.end();
                    return true;
                }
                break;
            }
            case 'Manual Reschedule': {
                let that = this;
                this['errFields'] = [];
                /* standard fields validation */
                let standardValidationFields = [
                    {name: 'currentPeriodicRepaymentAmount'},
                    {name: 'firstRepaymentDate'},
                    {name: 'rescheduleDate'}
                ];
                let baseOnValue = cmp.get('v.baseOnValue');
                if (!baseOnValue) {
                    cmp.find('message').showErrorMessage('The required attribute was not received.');
                    that.end();
                    return;
                }
                if (cmp.find('numberOfInstalments').get('v.required')) {
                    standardValidationFields.push({name: 'numberOfInstalments'});
                }
                if (cmp.find('newPeriodicRepaymentAmount').get('v.required')) {
                    standardValidationFields.push({name: 'newPeriodicRepaymentAmount'});
                }
                standardValidationFields.forEach(function (item) {
                    if (!item.hasOwnProperty('label')) {
                        item['label'] = cmp.find(item.name).get('v.label');
                    }
                });
                console.log(standardValidationFields);
                let isStandardValid = true;
                standardValidationFields.forEach(function (field) {
                    cmp.find(field.name).setCustomValidity('');
                    if (!that.elementValidationStandard(cmp, field.name, field.label)) {
                        isStandardValid = false;
                    }
                });
                if (isStandardValid) {
                    if (cmp.get('v.rescheduleDate') > cmp.get('v.firstRepaymentDateValue')) {
                        let rescheduleDate = cmp.find('rescheduleDate');
                        rescheduleDate.setCustomValidity('Reschedule Date cannot be after First Repayment Date (' + cmp.get('v.firstRepaymentDateValue') + ')');
                        rescheduleDate.reportValidity();
                        cmp.find('message').showErrorMessage('Reschedule Date cannot be after First Repayment Date (' + cmp.get('v.firstRepaymentDateValue') + ')');
                        that.end();
                        return;
                    }
                }
                /* custom fields validation */
                let customValidationFields = [
                    {name: 'sfims__Repayment_Frequency_Unit__c'},
                    {name: 'sfims__Repayment_Frequency__c'},
                    {name: 'sfims__Grace_Period_Type__c'}
                ];
                if (cmp.find('sfims__Grace_Period_Type__c').get('v.value') !== 'None' && cmp.find('sfims__Grace_Period_Type__c').get('v.value') !== '') {
                    customValidationFields.push({name: 'sfims__Number_of_Grace_Periods__c'});
                }
                let recordUiFields = {};
                if (that['recordUi']) {
                    if (that['recordUi'].hasOwnProperty('recordUi')) {
                        if (that['recordUi']['recordUi'].hasOwnProperty('objectInfo')) {
                            if (that['recordUi']['recordUi']['objectInfo'].hasOwnProperty('fields')) {
                                recordUiFields = that['recordUi']['recordUi']['objectInfo']['fields'];
                            }
                        }
                    }
                }
                customValidationFields.forEach(function (item) {
                    if (!item.hasOwnProperty('label')) {
                        item['label'] = '';
                    }
                    if (recordUiFields.hasOwnProperty(item.name)) {
                        if (recordUiFields[item.name].hasOwnProperty('label')) {
                            item['label'] = recordUiFields[item.name].label;
                        }
                    }
                });
                if (!that.formValidation(cmp, customValidationFields) || !isStandardValid) {
                    if (that['errFields']) {
                        let size = that['errFields'].length;
                        let msg = '';
                        if (size > 0) {
                            for (let i = 0; i < size; i++) {
                                msg += '- ' + that['errFields'][i] + '\n';
                            }
                        }
                        if (msg !== '') {
                            cmp.find('message').showErrorMessage('Please check and fill in the required fields' + ': \n' + msg);
                        }
                    } else {
                        cmp.find('message').showErrorMessage('Please check and fill in the required fields.');
                    }
                } else {
                    that.end();
                    return true;
                }
                break;
            }
        }
        this.end();
        return false;
    },

    elementValidationStandard: function (cmp, element, label) {
        this.begin('elementValidationStandard');
        this.log('element: ' + element + ', label: ' + label);
        let response = false;
        let item = cmp.find(element);
        if (item) {
            item.showHelpMessageIfInvalid();
            response = item.get('v.validity').valid;
            if (response) {
                if ($A.util.isEmpty(item.get('v.value'))) {
                    response = false;
                }
            }
            if (!response) {
                this['errFields'].push(label);
            }
        } else {
            cmp.find('message').showErrorMessage('The element "' + element + '" was not found in the component markup.');
        }
        this.end();
        return response;
    },

    elementValidationCustom: function (cmp, element, label) {
        this.begin('elementValidationCustom');
        this.log('element: ' + element + ', label: ' + label);
        let response = false;
        let item = cmp.find(element);
        if (!$A.util.isEmpty(item)) {
            if ($A.util.isEmpty(item.get('v.value'))) {
                $A.util.addClass(item, 'error');
                $A.util.addClass(item, 'slds-has-error');
                if (label) {
                    this['errFields'].push(label);
                }
            } else {
                response = true;
                $A.util.removeClass(item, 'error');
                $A.util.removeClass(item, 'slds-has-error');
            }
        } else {
            cmp.find('message').showErrorMessage('The element "' + element + '" was not found in the component markup.');
        }
        this.end();
        return response;
    },

    formValidation: function (cmp, fields) {
        this.begin('formValidation');
        let response = true;
        let that = this;
        fields.forEach(function (field) {
            if (!that.elementValidationCustom(cmp, field.name, field.label)) {
                response = false;
            }
        });
        this.end();
        return response;
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
                console.log(values);
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