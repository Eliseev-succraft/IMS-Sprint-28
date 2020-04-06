@IsTest
public with sharing class CalloutProxyTest {

    @IsTest
    private static void testProduction() {
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint('http://test.test');
        CalloutProxy.doCallout(request);
    }

    @IsTest
    private static void testDev() {
        insert new Proxy_Settings__c(
            Use_Dev_Version__c = true
        );

        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint('http://test.test');
        CalloutProxy.doCallout(request);
    }

}