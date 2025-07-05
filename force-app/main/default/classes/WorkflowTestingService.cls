public class WorkflowTestingService {
    
    /**
     * Simple method to test the CI/CD workflow
     * @return String - A simple testing message
     */
    public static String getWorkflowMessage() {
        return 'Workflow testing is successful!';
    }
    
    /**
     * Method to validate workflow functionality
     * @param testValue - The value to validate
     * @return Boolean - True if validation passes
     */
    public static Boolean validateWorkflow(String testValue) {
        return String.isNotBlank(testValue);
    }
}
