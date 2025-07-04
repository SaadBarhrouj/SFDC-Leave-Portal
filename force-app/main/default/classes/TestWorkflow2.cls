public class TestWorkflow2 {
    
    public static String displayMessage() {
        String message = 'Bonjour, ceci est un test de workflow simple!! !';
        System.debug(message);
        return message;
    }
    
    public static String displayCustomMessage(String customMessage) {
        String message = 'Message personnalisé: ' + customMessage;
        System.debug(message);
        return message;
    }
}
