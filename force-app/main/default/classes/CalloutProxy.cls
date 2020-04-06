public with sharing class CalloutProxy {

    private static final String ACCESS_KEY = 'vsLkyWQnR9hG0XClizsA';

    @TestVisible
    private static final String PROXY_ENDPOINT = 'https://singlify.herokuapp.com/';
    @TestVisible
    private static final String PROXY_DEV_ENDPOINT = 'https://singlify-dev.herokuapp.com/';

    public static HttpResponse doCallout(HttpRequest request) {
        Proxy_Settings__c proxySettings = Proxy_Settings__c.getOrgDefaults();

        String endpoint = '';
        if (proxySettings != null && proxySettings.Use_Dev_Version__c) {
            endpoint = PROXY_DEV_ENDPOINT;
        } else {
            endpoint = PROXY_ENDPOINT;
        }

        request.setEndpoint(endpoint + request.getEndpoint());

        Id orgId = UserInfo.getOrganizationId();
        Decimal timestamp = DateTime.now().getTime();
        String accessKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(timestamp + String.valueOf(orgId) + ACCESS_KEY)));

        request.setHeader('timestamp', String.valueOf(timestamp));
        request.setHeader('access-key', accessKey);
        request.setHeader('org-id', orgId);

        if (!Test.isRunningTest()) {
            return new Http().send(request);
        } else {
            return new HttpResponse();
        }
    }

}