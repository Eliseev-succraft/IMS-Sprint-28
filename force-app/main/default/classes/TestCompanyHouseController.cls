@isTest
public with sharing class TestCompanyHouseController {
    
    @isTest
    public static void updateCompanyInformationTest(){
        Company_House_API_Settings__c setting = new Company_House_API_Settings__c();
        setting.Name = 'Company House Token';
        setting.Value__c = 'test4';
        insert setting;

        Account testAccount = new Account(
            Name = 'test',
            Company_Number__c = '033586'
        );
        insert testAccount;

        Test.startTest();
        CompanyHouseController.updateCompanyInformation(testAccount.Id);
        Test.stopTest();

        System.assertEquals('test', [SELECT Name FROM Account WHERE Id = : testAccount.Id].Name);
    }

    @isTest
    public static void updateCompanyInformationNotNumberCompanyTest(){
        Company_House_API_Settings__c setting = new Company_House_API_Settings__c();
        setting.Name = 'Company House Token';
        setting.Value__c = 'test';
        insert setting;

        Account testAccount = new Account(
            Name = 'test'
        );
        insert testAccount;

        Test.startTest();
        Map <String, String> result = CompanyHouseController.updateCompanyInformation(testAccount.Id);
        Test.stopTest();

        System.assertEquals('ERROR', result.get('type'));
    }
    @isTest
    public static void updateCompanyInformationNotAccountTest(){
        Company_House_API_Settings__c setting = new Company_House_API_Settings__c();
        setting.Name = 'Company House Token';
        setting.Value__c = 'test';
        insert setting;

        Test.startTest();
        Map <String, String> result = CompanyHouseController.updateCompanyInformation('id123456789');
        Test.stopTest();

        System.assertEquals('ERROR', result.get('type'));
    }
    @isTest
    public static void getLastUpdateTest(){
        Datetime dt = Datetime.now();
        Account testAccount = new Account(
            Name = 'test',
            Company_Number__c = '033586',
            Last_Companies_House_check_date__c = dt
        );
        insert testAccount;

        Test.startTest();
        String result = CompanyHouseController.getLastUpdate(testAccount.Id);
        Test.stopTest();

        System.assertEquals(String.valueOf(dt), result);
    }

    @isTest
    public static void updateCompanyInformationNotCustomSettingTest(){
        Account testAccount = new Account(
            Name = 'test',
            Company_Number__c = '033586'
        );
        insert testAccount;

        Test.startTest();
        CompanyHouseController.updateCompanyInformation(testAccount.Id);
        Test.stopTest();
        
        System.assertEquals('test', [SELECT Name FROM Account WHERE Id = : testAccount.Id].Name);
    }

}