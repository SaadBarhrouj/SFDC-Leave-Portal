public without sharing class TeamRequestsController {
    @AuraEnabled
    public static List<Leave_Request__c> getApprovedLeavesByManager(Id managerId) {
        if (managerId == null) {
            return new List<Leave_Request__c>();
        }
        List<User> teamMembers = [SELECT Id FROM User WHERE ManagerId = :managerId];
        Set<Id> teamMemberIds = new Set<Id>();
        for (User u : teamMembers) teamMemberIds.add(u.Id);
        
        return [
            SELECT Id, Name, Start_Date__c, End_Date__c, Leave_Type__c, Status__c, Requester__r.Name
            FROM Leave_Request__c
            WHERE Requester__c IN :teamMemberIds
            ORDER BY Start_Date__c ASC
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getTeamRequestsHistory() {
        Set<Id> subordinateIds = new Set<Id>();
        for (User u : [SELECT Id FROM User WHERE ManagerId = :UserInfo.getUserId()]) {
            subordinateIds.add(u.Id);
        }

        if (subordinateIds.isEmpty()) {
            return new List<Leave_Request__c>();
        }

        Set<String> Statuses = new Set<String>{
            'Pending HR Approval',
            'Escalated to Senior Manager',
            'Approved',
            'Rejected',
            'Cancellation Requested'
        };

        return [
            SELECT Id, Name, Requester__c, Requester__r.Name, Requester__r.ManagerId, Requester__r.Manager.Name,
                   Leave_Type__c, Start_Date__c, End_Date__c, Number_of_Days_Requested__c, Status__c, LastModifiedDate
            FROM Leave_Request__c
            WHERE Requester__c IN :subordinateIds
            AND Status__c IN :Statuses
            ORDER BY LastModifiedDate DESC
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getTeamRequests() {
        Id currentUserId = UserInfo.getUserId();
        Set<Id> actorIds = new Set<Id>();
        actorIds.add(currentUserId);
        
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
                Number_of_Days_Requested__c, Status__c, Requester__r.Name, Requester__c,
                Requester__r.ManagerId, Requester__r.Manager.Name, LastModifiedDate
            FROM Leave_Request__c
            WHERE Id IN :leaveRequestIds
            ORDER BY LastModifiedDate DESC
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getTeamLeavesForRequester(Id requesterId) {
        User requester = [SELECT ManagerId FROM User WHERE Id = :requesterId LIMIT 1];
        if (requester.ManagerId == null) {
            return new List<Leave_Request__c>();
        }
        List<User> teamMembers = [SELECT Id FROM User WHERE ManagerId = :requester.ManagerId];
        Set<Id> teamMemberIds = new Set<Id>();
        for (User u : teamMembers) teamMemberIds.add(u.Id);
        
        return [
            SELECT Id, Name, Start_Date__c, End_Date__c, Leave_Type__c, Status__c, Requester__r.Name
            FROM Leave_Request__c
            WHERE Requester__c IN :teamMemberIds
            AND (Status__c = 'Approved' OR Status__c = 'Cancellation Requested')
            ORDER BY Start_Date__c ASC
        ];
    }
    
    @AuraEnabled
    public static void approveLeaveRequest(String leaveRequestId) {
        LeaveRequestUtils.validateRequestOnApproval(leaveRequestId);
        try {
            Leave_Request__c reqToUpdate = [SELECT Id, Last_Approver__c FROM Leave_Request__c WHERE Id = :leaveRequestId LIMIT 1];
            reqToUpdate.Last_Approver__c = UserInfo.getUserId();
            update reqToUpdate;
        } catch (Exception e) {
            throw new AuraHandledException('Could not find the leave request to update. Id: ' + leaveRequestId);
        }
        processApprovalRequest(leaveRequestId, 'Approve', null);
    }
    
    
    @AuraEnabled
    public static void rejectLeaveRequest(String leaveRequestId, String rejectionReason, String approverComment, Boolean isReasonRequired) {
        if (isReasonRequired && String.isBlank(rejectionReason)) {
            throw new AuraHandledException('Rejection reason is required.');
        }
        
        Leave_Request__c req = [SELECT Id FROM Leave_Request__c WHERE Id = :leaveRequestId LIMIT 1];
        
        if (String.isNotBlank(rejectionReason)) {
            req.Rejection_Reason__c = rejectionReason;
        }
        
        if (String.isNotBlank(approverComment)) {
            req.Approver_Comments__c = approverComment;
        }
        update req;
        processApprovalRequest(leaveRequestId, 'Reject', null);
    }
    
    private static void processApprovalRequest(String leaveRequestId, String action, String comment) {
        try {
            Id currentUserId = UserInfo.getUserId();
            Set<Id> actorIds = new Set<Id>();
            actorIds.add(currentUserId);
            for (GroupMember gm : [
                SELECT GroupId
                FROM GroupMember
                WHERE UserOrGroupId = :currentUserId
            ]) {
                actorIds.add(gm.GroupId);
            }
            
            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id, ActorId
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :leaveRequestId
                AND ActorId IN :actorIds
                AND ProcessInstance.Status = 'Pending'
                LIMIT 1
            ];
            if(workItems.isEmpty()){
                throw new AuraHandledException('No pending approval workitem found for this request.');
            }
            ProcessInstanceWorkitem workItem = workItems[0];
            
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(workItem.Id);
            req.setAction(action);
            if (comment != null) {
                req.setComments(comment);
            }
            Approval.ProcessResult result = Approval.process(req);
            if (!result.isSuccess()) {
                throw new AuraHandledException(result.getErrors()[0].getMessage());
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}