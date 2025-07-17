public with sharing class TeamRequestsController {
    
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getTeamRequests() {
        Id currentUserId = UserInfo.getUserId();
        Set<Id> actorIds = new Set<Id>();
        actorIds.add(currentUserId);

        // Récupérer les queues dont l'utilisateur est membre
        for (GroupMember gm : [
            SELECT GroupId
            FROM GroupMember
            WHERE UserOrGroupId = :currentUserId
        ]) {
            actorIds.add(gm.GroupId);
        }

        Set<Id> leaveRequestIds = new Set<Id>();
        for (ProcessInstanceWorkitem workItem : [
            SELECT ProcessInstance.TargetObjectId, ActorId
            FROM ProcessInstanceWorkitem
            WHERE ActorId IN :actorIds AND ProcessInstance.Status = 'Pending'
        ]) {
            if (String.valueOf(workItem.ProcessInstance.TargetObjectId).startsWith(Leave_Request__c.SObjectType.getDescribe().getKeyPrefix())) {
                leaveRequestIds.add(workItem.ProcessInstance.TargetObjectId);
            }
        }
        if (leaveRequestIds.isEmpty()) {
            return new List<Leave_Request__c>();
        }
        return [
            SELECT 
                Id, Name, Start_Date__c, End_Date__c, Leave_Type__c,
                Number_of_Days_Requested__c, Status__c, Requester__r.Name
            FROM Leave_Request__c
            WHERE Id IN :leaveRequestIds
            ORDER BY Start_Date__c ASC
        ];
    }
    
    @AuraEnabled
    public static void approveLeaveRequest(String leaveRequestId) {
        processApprovalRequest(leaveRequestId, 'Approve', null);
    }
    
    @AuraEnabled
    public static void rejectLeaveRequest(String leaveRequestId, String rejectionReason, String approverComment) {
        if (String.isBlank(rejectionReason)) {
            throw new AuraHandledException('A reason for rejection is required.');
        }
        Leave_Request__c req = [SELECT Id FROM Leave_Request__c WHERE Id = :leaveRequestId LIMIT 1];
        req.Rejection_Reason__c = rejectionReason;
        req.Approver_Comments__c = approverComment;
        update req;

        processApprovalRequest(leaveRequestId, 'Reject', null);
    }
    
    private static void processApprovalRequest(String leaveRequestId, String action, String comment) {
        try {
            Id currentUserId = UserInfo.getUserId();
            // Récupérer les queues dont l'utilisateur est membre
            Set<Id> actorIds = new Set<Id>();
            actorIds.add(currentUserId);
            for (GroupMember gm : [
                SELECT GroupId
                FROM GroupMember
                WHERE UserOrGroupId = :currentUserId
            ]) {
                actorIds.add(gm.GroupId);
            }

            // Chercher le workitem assigné à l'utilisateur OU à une queue dont il est membre
            ProcessInstanceWorkitem workItem = [
                SELECT Id, ActorId
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :leaveRequestId
                  AND ActorId IN :actorIds
                  AND ProcessInstance.Status = 'Pending'
                LIMIT 1
            ];

            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(workItem.Id);
            req.setAction(action);
            if (comment != null) {
                req.setComments(comment);
            }
            Approval.ProcessResult result = Approval.process(req);
            if (!result.isSuccess()) {
                String errorMessage = '';
                for (Database.Error err : result.getErrors()) {
                    errorMessage += err.getMessage() + '. ';
                }
                throw new AuraHandledException(errorMessage);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error processing request: ' + e.getMessage());
        }
    }
}