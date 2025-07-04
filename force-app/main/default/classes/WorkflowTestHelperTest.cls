@IsTest
private class WorkflowTestHelperTest {

    @IsTest
    static void testGetGreeting() {
        String expectedGreeting = 'Hello from WorkflowTestHelper!';
        String actualGreeting = WorkflowTestHelper.getGreeting();

        System.assertEquals(expectedGreeting, actualGreeting, 'Le message de salutation ne correspond pas.');
    }
}