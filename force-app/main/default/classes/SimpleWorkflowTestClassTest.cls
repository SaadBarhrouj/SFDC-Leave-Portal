@isTest
public class SimpleWorkflowTestClassTest {
    
    @isTest
    static void testGetGreetingMessage() {
        // Test the greeting message method
        String result = SimpleWorkflowTestClass.getGreetingMessage();
        System.assertEquals('Hello from Simple Workflow Test Class!', result);
    }
    
    @isTest
    static void testDisplayGreeting() {
        // Test the display greeting method
        SimpleWorkflowTestClass.displayGreeting();
        // No assertion needed for debug statements, just verify no exceptions
    }
}
