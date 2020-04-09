@IsTest
private class TestCustomLookupController {
    @IsTest
    private static void TestCustomLookupController() {
        Test.startTest();
        TestUtils.createPlatformUser();
        try {
            CustomLookupController.fetchRecords('User', 'Name', '', '50000');
        } catch (Exception e) {
            System.assertEquals(false, true, 'Invalid exception');
        }
        Test.stopTest();
    }
}