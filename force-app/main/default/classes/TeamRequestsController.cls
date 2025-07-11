public with sharing class TeamRequestsController {
    
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getTeamRequests() {
        Id currentUserId = UserInfo.getUserId();
        
        List<User> teamMembers = [SELECT Id FROM User WHERE ManagerId =: currentUserId];
        if (teamMembers.isEmpty()) {
            return new List<Leave_Request__c>();
        }
        
        Set<Id> teamMembersIds = (new Map<Id,User>(teamMembers)).keySet();
        
        return [
            SELECT 
                Id, Name, Start_Date__c, End_Date__c, Leave_Type__c, 
                Number_of_Days_Requested__c, Status__c, Requester__r.Name
            FROM Leave_Request__c
            WHERE Requester__c IN :teamMembersIds
            AND Status__c = 'Pending Approval'
            ORDER BY Start_Date__c ASC
        ];
    }

    @AuraEnabled
    public static void approveLeaveRequest(String leaveRequestId) {
        try {
            Leave_Request__c request = [
                SELECT Id, Status__c 
                FROM Leave_Request__c 
                WHERE Id = :leaveRequestId 
            ];
            
            request.Status__c = 'Approved';
            update request;

        } catch (Exception e) {
            throw new AuraHandledException('Error approving request: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static void rejectLeaveRequest(String leaveRequestId, String rejectionReason, String approverComment) {
        if (String.isBlank(rejectionReason)) {
            throw new AuraHandledException('A reason for rejection is required.');
        }
        try {
            Leave_Request__c request = [
                SELECT Id, Status__c, Rejection_Reason__c, Approver_Comments__c 
                FROM Leave_Request__c 
                WHERE Id = :leaveRequestId 
            ];

            request.Status__c = 'Rejected';
            request.Rejection_Reason__c = rejectionReason;
            request.Approver_Comments__c = approverComment;
            update request;

        } catch (Exception e) {
            throw new AuraHandledException('Error rejecting request: ' + e.getMessage());
        }
    }
}