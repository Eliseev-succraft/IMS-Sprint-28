@isTest
private class TestOverriddenLoanPageController {
    @isTest static void test_preview() {
        // create a new interest rate source
        Interest_Rate_Source__c irs = new Interest_Rate_Source__c(Name = 'Test Interest Rate Source');
        insert irs;

        // create interest rates
        Interest_Rate__c ir = TestUtils.createNewInterestRate(irs.Id, System.today(), 1);
        
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct('Test Loan Product');
        lp.Interest_Rate_Source__c = 'Variable Interest';
        lp.Interest_Reference_Rate__c = irs.Id;
        lp.Interest_Rate_Review_Frequency__c = 'Monthly';
        lp.CBO_Default_Variable_Interest_Spread__c = true;

        insert new List<SObject>{ir, lp};
        
        // create a new loan
        Investment__c i = TestUtils.createNewLoan(System.today(), System.today().addMonths(1));
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Variable_Interest_Spread__c = 5;
        i.Interest_Rate__c = null;

        Map<String, String> result = OverriddenLoanPageController.generateSchedule(JSON.serialize(i), true);
        System.assert(!result.containsKey('error'));
        System.assert(result.containsKey('schedules'));
        System.assert(result.containsKey('variableInterest'));
        List<Repayment_Schedule__c> rsToPreview = (List<Repayment_Schedule__c>) JSON.deserialize(result.get('schedules'), List<Repayment_Schedule__c>.class);
        System.assertEquals(rsToPreview.size(), i.Number_of_Instalments__c);
    }

    @isTest static void test_save_and_generate_schedule() {
        // create a new interest rate source
        Interest_Rate_Source__c irs = new Interest_Rate_Source__c(Name = 'Test Interest Rate Source');
        insert irs;

        // create interest rates
        Interest_Rate__c ir = TestUtils.createNewInterestRate(irs.Id, System.today(), 1);
        
        // create a new loan product
        Loan_Product__c lp = TestUtils.createNewLoanProduct('Test Loan Product');
        lp.Interest_Rate_Source__c = 'Variable Interest';
        lp.Interest_Reference_Rate__c = irs.Id;
        lp.Interest_Rate_Review_Frequency__c = 'Monthly';
        lp.CBO_Default_Variable_Interest_Spread__c = true;

        insert new List<SObject>{ir, lp};
        
        // create a new loan
        Investment__c i = TestUtils.createNewLoan(System.today(), System.today().addMonths(1));
        i.Loan_Product__c = lp.Id;
        i.Disbursement_Method__c = 'Full disbursement at start';
        i.Variable_Interest_Spread__c = 5;
        i.Interest_Rate__c = null;

        List<Investment__c> loans = [
            SELECT Id, 
            (
                SELECT Id
                FROM Repayment_Schedules__r
            )
            FROM Investment__c 
        ];
        System.assertEquals(loans.size(), 0);

        Map<String, String> result = OverriddenLoanPageController.generateSchedule(JSON.serialize(i), false);
        System.assert(!result.containsKey('error'));
        System.assert(result.containsKey('success'));

        List<Investment__c> loans2 = [
            SELECT Id, 
            (
                SELECT Id
                FROM Repayment_Schedules__r
            )
            FROM Investment__c 
        ];
        System.assertEquals(loans2.size(), 1);
        System.assertEquals(loans2[0].Repayment_Schedules__r.size(), i.Number_of_Instalments__c);
    }

    @isTest static void test_getFieldSets() {
        
        Map<String, Schema.FieldSet> fsMap = Schema.SObjectType.Investment__c.fieldSets.getMap();
        String resultNew = OverriddenLoanPageController.getFieldSets('new');
        String resultEdit = OverriddenLoanPageController.getFieldSets('edit');
        String resultView = OverriddenLoanPageController.getFieldSets('view');

        Integer numberOfTop = 0;
        Integer numberOfBottom = 0;
        for (String key : fsMap.keySet()) {
            if (key.containsIgnoreCase('loan_top')) {
                numberOfTop++;
                continue;
            }
            if (key.containsIgnoreCase('loan_bottom')) {
                numberOfBottom++;
            }
        }
        
        Map<String, List<Utility.FieldSetWrapper>> resultNewMap = (Map<String, List<Utility.FieldSetWrapper>>) JSON.deserialize(resultNew, Map<String, List<Utility.FieldSetWrapper>>.class);
        if (!resultNewMap.isEmpty()) {
            if (resultNewMap.containsKey('top')) System.assertEquals(resultNewMap.get('top').size(), numberOfTop);
            if (resultNewMap.containsKey('bottom')) System.assertEquals(resultNewMap.get('bottom').size(), numberOfBottom);
        } else {
            System.assertEquals(resultNewMap.size(), 0);
        }

        Map<String, List<Utility.FieldSetWrapper>> resultEditMap = (Map<String, List<Utility.FieldSetWrapper>>) JSON.deserialize(resultEdit, Map<String, List<Utility.FieldSetWrapper>>.class);
        if (!resultEditMap.isEmpty()) {
            if (resultEditMap.containsKey('top')) System.assertEquals(resultEditMap.get('top').size(), numberOfTop);
            if (resultEditMap.containsKey('bottom')) System.assertEquals(resultEditMap.get('bottom').size(), numberOfBottom);
        } else {
            System.assertEquals(resultEditMap.size(), 0);
        }

        Map<String, List<Utility.FieldSetWrapper>> resultViewMap = (Map<String, List<Utility.FieldSetWrapper>>) JSON.deserialize(resultView, Map<String, List<Utility.FieldSetWrapper>>.class);
        if (!resultViewMap.isEmpty()) {
            if (resultViewMap.containsKey('top')) System.assertEquals(resultViewMap.get('top').size(), numberOfTop);
            if (resultViewMap.containsKey('bottom')) System.assertEquals(resultViewMap.get('bottom').size(), numberOfBottom);
        } else {
            System.assertEquals(resultViewMap.size(), 0);
        }
    }

    @isTest static void test_getLoanProductSettings() { 
        String dayCountConvention = 'Actual/365';
        Decimal repaymentFrequency = 1;
        
        Loan_Product__c lp = TestUtils.createNewLoanProduct();
        lp.Day_Count_Convention__c = dayCountConvention;
        lp.Repayment_Frequency__c = repaymentFrequency;
        insert lp;
        
        String stringResult = OverriddenLoanPageController.getLoanProductSettings(lp.Id, null);
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(stringResult);
        
        System.assertEquals(dayCountConvention, (String)result.get('sfims__Day_Count_Convention__c'));
        System.assertEquals(repaymentFrequency, (Decimal)result.get('sfims__Repayment_Frequency__c'));

        Investment__c i = TestUtils.createNewLoan();
        i.Loan_Product__c = lp.Id;
        insert i;
        
        String stringResult2 = OverriddenLoanPageController.getLoanProductSettings(null, i.Id);
        Map<String, Object> result2 = (Map<String, Object>) JSON.deserializeUntyped(stringResult2);
        
        System.assertEquals(dayCountConvention, (String)result2.get('sfims__Day_Count_Convention__c'));
        System.assertEquals(repaymentFrequency, (Decimal)result2.get('sfims__Repayment_Frequency__c'));

    }

}