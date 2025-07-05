public class SimpleWorkflowTestClass {
    
    /**
     * Simple method that returns a greeting message
     * @return String - A simple greeting message
     */
    public static String getGreetingMessage() {
        return 'Hello from Simple Workflow Test Class!';
    }
    
    /**
     * Method that displays a message in debug log
     */
    public static void displayGreeting() {
        System.debug('Simple Workflow Test: Hello World!');
    }
}
