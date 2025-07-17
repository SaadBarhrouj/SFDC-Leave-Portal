public with sharing class LeaveRequestController {
    
    @AuraEnabled
    public static Id getLeaveBalanceId(Id employeeId, String leaveType) {
        try {
            Leave_Balance__c balance = [
                SELECT Id
                FROM Leave_Balance__c
                WHERE Employee__c = :employeeId
                AND Leave_Type__c = :leaveType
                AND Year__c = :Date.today().year()
                LIMIT 1
            ];
            return balance.Id;
        } catch (Exception e) {
            throw new AuraHandledException('No leave balance found for ' + leaveType + ' for this year');
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getMyLeaves() {
        try {
            return [
                SELECT Id, Name, Leave_Type__c, Start_Date__c, End_Date__c, 
                       Number_of_Days_Requested__c, Status__c, Employee_Comments__c,
                       Approver_Comments__c, Rejection_Reason__c, CreatedDate,
                       Requester__r.Name, Leave_Balance__r.Leave_Type__c
                FROM Leave_Request__c
                WHERE Requester__c = :UserInfo.getUserId()
                ORDER BY CreatedDate DESC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving leave requests: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String submitForApproval(String requestId) {
        Leave_Request__c requestToSubmit = [
            SELECT Id, Requester__c, Requester__r.ManagerId 
            FROM Leave_Request__c 
            WHERE Id = :requestId 
            LIMIT 1
        ];

        if (requestToSubmit.Requester__r.ManagerId == null) {
            throw new AuraHandledException('Submission failed: You do not have a manager assigned in Salesforce. Please contact your administrator.');
        }

        List<ProcessInstance> existingInstances = [
            SELECT Id 
            FROM ProcessInstance 
            WHERE TargetObjectId = :requestId AND Status = 'Pending'
        ];

        if (!existingInstances.isEmpty()) {
            return 'This request is already pending approval.';
        }

        try {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(requestId);
            req.setComments('Submitted via LWC by ' + UserInfo.getName());
            Approval.ProcessResult result = Approval.process(req);

            if (result.isSuccess()) {
                return 'Request successfully submitted for approval!';
            } else {
                String errors = '';
                for (Database.Error error : result.getErrors()) {
                    if(error.getMessage().contains('NO_APPLICABLE_PROCESS')){
                        errors += 'No applicable approval process was found. Please check the request status or contact an admin. ';
                    } else {
                        errors += error.getMessage() + '. ';
                    }
                }
                throw new AuraHandledException(errors);
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }


     @InvocableMethod(label='Reassign Approval Process to New Approver' description='Reassigns the approval process to the new approver after Approver__c is changed.')
    public static void reassignApproval(List<Id> leaveRequestIds) {
        List<ProcessInstanceWorkitem> workItemsToUpdate = new List<ProcessInstanceWorkitem>();
        List<Leave_Request__c> requests = [SELECT Id, Approver__c FROM Leave_Request__c WHERE Id IN :leaveRequestIds];
        Map<Id, Id> requestToApprover = new Map<Id, Id>();
        for (Leave_Request__c req : requests) {
            if (req.Approver__c != null) {
                requestToApprover.put(req.Id, req.Approver__c);
            }
        }
        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id, ProcessInstance.TargetObjectId 
            FROM ProcessInstanceWorkitem 
            WHERE ProcessInstance.TargetObjectId IN :leaveRequestIds
        ];
        for (ProcessInstanceWorkitem wi : workItems) {
            Id newApproverId = requestToApprover.get(wi.ProcessInstance.TargetObjectId);
            if (newApproverId != null) {
                wi.ActorId = newApproverId;
                workItemsToUpdate.add(wi);
            }
        }
        if (!workItemsToUpdate.isEmpty()) {
            update workItemsToUpdate;
        }
    }
}