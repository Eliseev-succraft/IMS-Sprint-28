@isTest
private class TestUtility {
    @isTest static void test_currentUserIsAdmin_as_platform_user() {
        System.runAs(TestUtils.createPlatformUser()){
            System.assert(!Utility.currentUserIsAdmin);
        }
        System.assert(!Utility.currentUserIsAdmin);
    }

    @isTest static void test_currentUserIsAdmin_as_admin() {
        System.runAs(new User(ID = UserInfo.getUserID())){ 
            System.assert(Utility.currentUserIsAdmin);
        }
        System.assert(Utility.currentUserIsAdmin);
    }
}