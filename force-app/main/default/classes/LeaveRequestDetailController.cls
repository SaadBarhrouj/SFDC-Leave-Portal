public with sharing class LeaveRequestDetailController {
    @AuraEnabled(cacheable=true)
    public static Leave_Request__c getLeaveRequestDetails(Id recordId) {
        if (recordId == null) {
            return null;
        }
        return [
            SELECT
                Id, Name, Status__c, Leave_Type__c, Start_Date__c, End_Date__c,
                Number_of_Days_Requested__c, Employee_Comments__c,
                Approver_Comments__c, Rejection_Reason__c,
                Requester__c, Requester__r.Name,
                Leave_Balance__r.Allocated_Days__c,
                Leave_Balance__r.Used_Days__c,
                Leave_Balance__r.Remaining_Days__c
            FROM Leave_Request__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
    }
}