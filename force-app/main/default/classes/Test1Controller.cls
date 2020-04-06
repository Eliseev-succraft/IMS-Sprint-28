/**
 * Created by user on 3/31/20.
 */

public with sharing class Test1Controller {

    public class CustomException extends Exception {
    }

    /*
    @AuraEnabled
    public static HttpResponse method1(String city) {
        try {
            if (String.isEmpty(city)) {

            } else {


            }

            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('https://th-apex-http-callout.herokuapp.com/animals');
            request.setMethod('GET');
            HttpResponse response = http.send(request);

            if (response.getStatusCode() == 200) {
                // Deserialize the JSON string into collections of primitive data types.
                Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            }

        } catch (Exception err) {
            throw new CustomException(err.getMessage());
        }
    }
*/

}