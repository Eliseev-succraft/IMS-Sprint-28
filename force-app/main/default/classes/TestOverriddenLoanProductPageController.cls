@isTest
private class TestOverriddenLoanProductPageController {
    @isTest static void test_getFieldSets() {
        
        Map<String, Schema.FieldSet> fsMap = Schema.SObjectType.Loan_Product__c.fieldSets.getMap();
        String resultNew = OverriddenLoanProductPageController.getFieldSets('new');
        String resultEdit = OverriddenLoanProductPageController.getFieldSets('edit');
        
        Integer numberOfTop = 0;
        Integer numberOfBottom = 0;
        for (String key : fsMap.keySet()) {
            if (key.containsIgnoreCase('loan_product_top')) {
                numberOfTop++;
                continue;
            }
            if (key.containsIgnoreCase('loan_product_bottom')) {
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
    }

    @isTest static void test_getOrgSettings() {
        String dayCountConvention = 'Actual/365';
        Decimal repaymentFrequency = 1;
        
        Loan_Settings__c settings = Loan_Settings__c.getOrgDefaults();
        settings.Day_Count_Convention__c = dayCountConvention;
        settings.Repayment_Frequency__c = repaymentFrequency;
        upsert settings Loan_Settings__c.Id;

        Map<String, Object> result = OverriddenLoanProductPageController.getOrgSettings();
        
        System.assertEquals(dayCountConvention, (String)result.get('sfims__Day_Count_Convention__c'));
        System.assertEquals(repaymentFrequency, (Decimal)result.get('sfims__Repayment_Frequency__c'));
    }

    @isTest static void test_getAccessLoanProduct() {
        System.assertNotEquals(null, OverriddenLoanProductPageController.getAccessLoanProduct());
    }

    // @isTest static void test_getProfileInfo() {
    //     System.assertNotEquals(null, OverriddenLoanProductPageController.getProfileInfo());
    // }


}