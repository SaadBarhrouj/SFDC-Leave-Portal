public with sharing class LeaveRequestActions {
    @InvocableMethod(label='Process Leave Request Approval')
    public static void approveRequests(List<String> ids) {
        List<Leave_Request__c> requests = [SELECT Id, Status__c FROM Leave_Request__c WHERE Id IN :ids];
        for (Leave_Request__c req : requests) {
            req.Status__c = 'Approved';
        }
        update requests;
    }
}