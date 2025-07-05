public class DemoApexClass {
    
    /**
     * Returns a demo message
     * @return String - A demo message
     */
    public static String getDemoMessage() {
        return 'Welcome to Demo Apex Class!';
    }
    
    /**
     * Returns a personalized demo message
     * @param name - The name to include in the message
     * @return String - A personalized demo message
     */
    public static String getPersonalizedMessage(String name) {
        return 'Hello ' + name + ', this is a demo message!';
    }
    
    /**
     * Displays a demo message in the debug log
     */
    public static void displayDemoMessage() {
        System.debug('Demo: Testing the workflow process!');
    }
}
