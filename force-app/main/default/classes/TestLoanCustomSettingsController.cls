/** LoanCustomSettings functionality * @author Alexey Eliseev * @date 10/31/19 **/
@IsTest
private with sharing class TestLoanCustomSettingsController {
    @IsTest static void test_LoanCustomSettingsController() {
        Test.startTest();
        Map<String, String> dataMap = LoanCustomSettingsController.apexGetObjectFields('sfims__Investment__c');
        System.assertEquals(true, dataMap.containsKey('getObjectFields'), 'The data has not been got.');
        System.assertEquals(true, dataMap.containsKey('getCustomSettings'), 'The data has not been got.');
        System.assertEquals(true, String.isNotBlank(dataMap.get('getObjectFields')), 'The data has not been got.');
        System.assertEquals(true, String.isNotBlank(dataMap.get('getCustomSettings')), 'The data has not been got.');
        Map<String, String> settingValues = new Map<String, String>{
                'sfims__CBO_Day_Count_Convention__c' => 'true',
                'sfims__CBO_Early_Payment_Method__c' => 'false',
                'sfims__CBO_Flat_Amount__c' => 'false',
                'sfims__CBO_Late_Repayment_Calculation_Method__c' => 'false',
                'sfims__CBO_Late_Repayment_Interest_Rate__c' => 'false',
                'sfims__CBO_Late_Repayment_Tolerance_Period__c' => 'false',
                'sfims__CBO_Percent_Of_Disbursement_Amount__c' => 'false',
                'sfims__CBO_Repayment_Frequency_Unit__c' => 'false',
                'sfims__CBO_Repayment_Frequency__c' => 'false',
                'sfims__CBO_Setup_Fee_Charging_Method__c' => 'false',
                'sfims__CBO_Setup_Fee__c' => 'false',
                'sfims__Day_Count_Convention__c' => '',
                'sfims__Early_Payment_Method__c' => '',
                'sfims__Flat_Amount__c' => '0',
                'sfims__Late_Repayment_Calculation_Method__c' => '',
                'sfims__Late_Repayment_Interest_Rate__c' => '0',
                'sfims__Late_Repayment_Tolerance_Period__c' => '0',
                'sfims__Percent_Of_Disbursement_Amount__c' => '0',
                'sfims__Repayment_Frequency_Unit__c' => '',
                'sfims__Repayment_Frequency__c' => '0',
                'sfims__Setup_Fee_Charging_Method__c' => '',
                'sfims__Setup_Fee__c' => '1234'
        };
        Boolean resultSave = LoanCustomSettingsController.apexSaveCustomSettings(settingValues);
        System.assertEquals(true, resultSave, 'The data have not been saved.');
        try {
            resultSave = LoanCustomSettingsController.apexSaveCustomSettings(new Map<String, String>{
                    'notCorrect' => 'true'
            });
            System.assertEquals(true, false, 'Invalid exception message');
        } catch (Exception err) {

        }
        Loan_Settings__c response = Loan_Settings__c.getOrgDefaults();
        System.assertEquals(settingValues.get('sfims__Setup_Fee__c'), response.get('sfims__Setup_Fee__c'), 'The data has not been saved.');
        Test.stopTest();
    }
}