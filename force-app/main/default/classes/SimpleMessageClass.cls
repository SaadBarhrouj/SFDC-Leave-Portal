public class SimpleMessageClass {
    
    public static String getMessage() {
        return 'Hello World from Apex!';
    }
    
    public static void displayMessage() {
        System.debug(getMessage());
    }
    
    public static String getCustomMessage(String name) {
        return 'Hello ' + name + ' from Apex!';
    }
}
