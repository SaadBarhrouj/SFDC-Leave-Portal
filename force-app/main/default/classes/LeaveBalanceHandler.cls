public with sharing class LeaveBalanceHandler {
    
    public static void populateLeaveBalanceId(List<Leave_Request__c> requests) {
        
        Set<Id> employeeIds = new Set<Id>();
        Set<String> leaveTypes = new Set<String>();
        
        for (Leave_Request__c request : requests) {
            if (request.Requester__c != null && request.Leave_Type__c != null) {
                employeeIds.add(request.Requester__c);
                leaveTypes.add(request.Leave_Type__c);
            }
        }
        
        if (employeeIds.isEmpty()) {
            return;
        }
        
        Map<String, Id> balanceMap = new Map<String, Id>();
        
        for (Leave_Balance__c balance : [
            SELECT Id, Employee__c, Leave_Type__c, Year__c
            FROM Leave_Balance__c
            WHERE Employee__c IN :employeeIds 
            AND Leave_Type__c IN :leaveTypes 
            AND Year__c = :Date.today().year()
        ]) {
            String key = balance.Employee__c + '-' + balance.Leave_Type__c + '-' + balance.Year__c;
            balanceMap.put(key, balance.Id);
        }
        
        for (Leave_Request__c request : requests) {
            if (request.Requester__c != null && request.Leave_Type__c != null) {
                String key = request.Requester__c + '-' + request.Leave_Type__c + '-' + Date.today().year();
                
                if (balanceMap.containsKey(key)) {
                    Id correctBalanceId = balanceMap.get(key);
                    request.Leave_Balance__c = correctBalanceId;
                } else {
                    request.addError('No Leave Balance found for ' + request.Leave_Type__c + ' for this employee in ' + Date.today().year());
                }
            }
        }
    }
}
