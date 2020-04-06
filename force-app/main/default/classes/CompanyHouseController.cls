public with sharing class CompanyHouseController {
    @AuraEnabled
    public static Map<String, String> updateCompanyInformation(String recordId) {
        Map<String, String> resultMap = new Map<String, String>();
        try {
            List<Account> accountList = [
                SELECT Company_Number__c 
                FROM Account 
                WHERE Id = :recordId
            ];
            if (!accountList.isEmpty()) {
                Account acc = accountList[0];
                if (!String.isBlank(acc.Company_Number__c)) {
                    List<NamedCredential> namedCredentials = [
                        SELECT Endpoint 
                        FROM NamedCredential 
                        WHERE DeveloperName = 'Company_House_API'
                    ];
                    if (!namedCredentials.isEmpty() || Test.isRunningTest()) {
                        Map <String, Company_House_API_Settings__c> settings = Company_House_API_Settings__c.getAll();
                        if (settings.containsKey('Company House Token') && settings.get('Company House Token').Value__c != null){
                            HttpRequest req = new HttpRequest();
                            req.setMethod('GET');
                            req.setHeader('Authorization', settings.get('Company House Token').Value__c);
                            req.setEndpoint(namedCredentials[0].Endpoint + acc.Company_Number__c);
                            
                            HttpResponse res = !Test.isRunningTest() ? CalloutProxy.doCallout(req) : updateCompanyInformationTest();
                            
                            if (res.getStatusCode() == 200) {
                                Map <String, Object> companyInfo = (Map <String, Object>) JSON.deserializeUntyped(res.getBody());
                                Map <String, Object> companyAddress = new Map<String, String>();
                                companyAddress = (Map <String, Object>) companyInfo.get('registered_office_address');
                                acc.Company_Status__c = String.valueOf(companyInfo.get('company_status'));
                                acc.Date_Of_Creation__c = Date.valueOf(String.valueOf(companyInfo.get('date_of_creation')));
                                acc.Name = String.valueOf(companyInfo.get('company_name'));
                                acc.BillingStreet = String.valueOf(companyAddress.get('address_line_1'));
                                acc.BillingCountry = String.valueOf(companyAddress.get('country'));
                                acc.BillingPostalCode = String.valueOf(companyAddress.get('postal_code'));
                                acc.BillingCity = String.valueOf(companyAddress.get('locality'));
                                acc.Last_Companies_House_Check_Date__c = Datetime.now();
                                
                                update acc;

                                return generateResult('SUCCESS', 'SUCCESS');
                            } else {
                                return generateResult('ERROR', res.getBody());
                            }
                        } else {
                            return generateResult('ERROR', System.Label.sfims.error_message_2);
                        }
                    } else {
                        return generateResult('ERROR', System.Label.sfims.error_message_3);
                    }

                } else {
                    return generateResult('ERROR', System.Label.sfims.error_message_4);
                }
            } else {
                return generateResult('ERROR', System.Label.sfims.error_message_5);
            }
        } catch (Exception e) {
            return generateResult('ERROR', e.getMessage());
        }
    }

    public static Map<String, String> generateResult(String type, String message) {
        Map<String, String> resultMap = new Map<String, String>();
        resultMap.put('type', type);
        resultMap.put('message', message);
        return resultMap;
    }

    @AuraEnabled
    public static String getLastUpdate(String recordId) {
        List <Account> accountList = new List<Account>();
        accountList = [SELECT Last_Companies_House_check_date__c FROM Account WHERE Account.Id = :recordId];
        String dateString = String.valueOf(accountList[0].Last_Companies_House_check_date__c);
        return dateString;

    }

    public static HttpResponse updateCompanyInformationTest() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        String body = '{"company_number":"00000006","date_of_creation":"1862-10-25","company_name":"test",' +
                '"registered_office_address":{"postal_code":"EC4N 6AF", "address_line_2":"78 Cannon Street", ' + 
                '"country":"England", "address_line_1":"Cms Cameron Mckenna Llp Cannon Place",' +
                '"locality":"London"}, "company_status":"dissolved"}';

        response.setBody(body);
        return response;
    }

}