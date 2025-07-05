@isTest
public class DemoApexClassTest {
    
    @isTest
    static void testGetDemoMessage() {
        // Test the demo message method
        String result = DemoApexClass.getDemoMessage();
        System.assertEquals('Welcome to Demo Apex Class!', result);
    }
    
    @isTest
    static void testGetPersonalizedMessage() {
        // Test the personalized message method
        String result = DemoApexClass.getPersonalizedMessage('John');
        System.assertEquals('Hello John, this is a demo message!', result);
    }
    
    @isTest
    static void testDisplayDemoMessage() {
        // Test the display demo message method - Fixed Test methods
        Test.startTest();
        DemoApexClass.displayDemoMessage();
        Test.stopTest();
        // No assertion needed for debug statements
    }
}
