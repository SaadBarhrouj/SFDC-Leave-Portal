@isTest
public class WorkflowTestingServiceTest {
    
    @isTest
    static void testGetWorkflowMessage() {
        // Test the workflow message method
        String result = WorkflowTestingService.getWorkflowMessage();
        System.assertEquals('Workflow testing is successful!', result, 'Workflow message should match expected value');
    }
    
    @isTest
    static void testValidateWorkflow_WithValidValue() {
        // Test validation with valid value
        Boolean result = WorkflowTestingService.validateWorkflow('Valid Test Value');
        System.assert(result, 'Validation should pass for valid value');
    }
    
    @isTest
    static void testValidateWorkflow_WithBlankValue() {
        // Test validation with blank value
        Boolean result = WorkflowTestingService.validateWorkflow('');
        System.assert(!result, 'Validation should fail for blank value');
    }
    
    @isTest
    static void testValidateWorkflow_WithNullValue() {
        // Test validation with null value
        Boolean result = WorkflowTestingService.validateWorkflow(null);
        System.assert(!result, 'Validation should fail for null value');
    }
}
