@IsTest
public class TestWorkflow2Test {
    
    @IsTest
    static void testDisplayMessage() {
        Test.startTest();
        String result = TestWorkflow2.displayMessage();
        Test.stopTest();
        
        System.assertEquals('Bonjour, ceci est un test de workflow simple!!!', result, 'Le message devrait être correct');
    }
    
    @IsTest
    static void testDisplayCustomMessage() {
        String customMsg = 'Test message personnalisé';
        
        Test.startTest();
        String result = TestWorkflow2.displayCustomMessage(customMsg);
        Test.stopTest();
        
        String expected = 'Message personnalisé: ' + customMsg;
        System.assertEquals(expected, result, 'Le message personnalisé devrait être correct');
    }
}
