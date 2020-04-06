public with sharing class OverriddenLoanProductPageController {

    @AuraEnabled
    public static Boolean getAccessLoanProduct() {
        try {
            return Loan_Product__c.SObjectType.getDescribe().isCreateable();
        } catch (Exception err) {
            throw new AuraHandledException(err.getMessage());
        }
    }

    // @AuraEnabled
    // public static Map<String, SObject> getUserProfileInfo() {
    //     try {
    //         Map<String, SObject> response = new Map<String, SObject>();
    //         response.put('user', OverriddenLoanProductPageController.getUserInfo());
    //         response.put('profile', OverriddenLoanProductPageController.getProfileInfo());
    //         return response;
    //     } catch (Exception e) {
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }

    // @AuraEnabled
    // public static Profile getProfileInfo() {
    //     try {
    //         Id profileId = UserInfo.getProfileId();
    //         Profile profile = [SELECT Id, Name FROM Profile WHERE Id = :profileId];
    //         return profile;
    //     } catch (Exception e) {
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }

    // @AuraEnabled
    // public static User getUserInfo() {
    //     try {
    //         Id userId = UserInfo.getUserId();
    //         User user = [SELECT Id, Name FROM User WHERE Id = :userId];
    //         return user;
    //     } catch (Exception e) {
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }

    @AuraEnabled
    public static String getFieldSets(String mode) {
        return JSON.serialize(OverriddenLoanProductPageController.formFieldMap(Schema.SObjectType.Loan_Product__c.fieldSets.getMap(), 'loan_product', mode));
    }

    public static Map<String, List<Utility.FieldSetWrapper>> formFieldMap(Map<String, Schema.FieldSet> fsMap, String obj, String mode) {
        Map<String, List<Utility.FieldSetWrapper>> returnMap = new Map<String, List<Utility.FieldSetWrapper>>();
        for (String key : fsMap.keySet()) {
            if (key.containsIgnoreCase(obj + '_top')) {
                if (!returnMap.containsKey('top')) returnMap.put('top', new List<Utility.FieldSetWrapper>());

                returnMap.get('top').add(OverriddenLoanProductPageController.formFieldMap(fsMap.get(key), mode));
                continue;
            }
            if (key.containsIgnoreCase(obj + '_bottom')) {
                if (!returnMap.containsKey('bottom')) returnMap.put('bottom', new List<Utility.FieldSetWrapper>());

                returnMap.get('bottom').add(OverriddenLoanProductPageController.formFieldMap(fsMap.get(key), mode));
            }
        }
        return returnMap;
    }

    public static Utility.FieldSetWrapper formFieldMap(Schema.FieldSet fs, String mode) {
        System.debug(fs);
        List<String> fieldAPINames = new List<String>();
        for (Schema.FieldSetMember fsm : fs.getFields()) {
            // System.debug(mode);
            // System.debug(fsm.getSObjectField().getDescribe().isAccessible());
            // System.debug(fsm.getSObjectField().getDescribe().isCreateable());
            // System.debug(fsm.getSObjectField().getDescribe().isUpdateable());
            switch on mode {
                when 'new' {
                    if (fsm.getSObjectField().getDescribe().isCreateable()) fieldAPINames.add(fsm.getFieldPath());
                }
                when 'edit' {
                    if (fsm.getSObjectField().getDescribe().isUpdateable()) fieldAPINames.add(fsm.getFieldPath());
                }
                when 'view' {
                    if (fsm.getSObjectField().getDescribe().isAccessible()) fieldAPINames.add(fsm.getFieldPath());
                }
            }
        }
        Utility.FieldSetWrapper fsw = new Utility.FieldSetWrapper();
        fsw.Label = fs.getLabel();
        fsw.Fields = fieldAPINames;
        return fsw;
    }

    @AuraEnabled
    public static Map<String, Object> getOrgSettings() {
        Map<String, Object> settingsMap = new Map<String, Object>();
        Loan_Settings__c settings = Loan_Settings__c.getOrgDefaults();
        for (Schema.SObjectField fieldAPIName : Schema.SObjectType.Loan_Settings__c.fields.getMap().values()) {
            // System.debug(fieldAPIName);
            // System.debug(settings.get(fieldAPIName));
            if (settings.get(fieldAPIName) != null && String.valueOf(settings.get(fieldAPIName)).trim() != '') {
                settingsMap.put(String.valueOf(fieldAPIName), settings.get(fieldAPIName));
            } else {
                settingsMap.put(String.valueOf(fieldAPIName), '');
            }
        }
        return settingsMap;
    }

}