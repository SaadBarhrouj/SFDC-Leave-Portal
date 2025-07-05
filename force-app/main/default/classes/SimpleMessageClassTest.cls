@isTest
public class SimpleMessageClassTest {
    
    @isTest
    static void testGetMessage() {
        String result = SimpleMessageClass.getMessage();
        System.assertEquals('Hello World from Apex!', result);
    }
    
    @isTest
    static void testDisplayMessage() {
        Test.startTest();
        SimpleMessageClass.displayMessage();
        Test.stopTest();
    }
    
    @isTest
    static void testGetCustomMessage() {
        String result = SimpleMessageClass.getCustomMessage('Developer');
        System.assertEquals('Hello Developer from Apex!', result);
    }
}
