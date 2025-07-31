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
    public static List<Leave_Request__c> getMyLeavesForCalendar() {
        return getMyLeaves();
    }
    
    @AuraEnabled(cacheable=true)
    public static Decimal getNumberOfDaysRequested(Date startDate, Date endDate) {
        if (startDate == null || endDate == null || startDate > endDate) {
            return 0;
        }
        
        User u = [SELECT Work_Country__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.Work_Country__c == null || String.isBlank(u.Work_Country__c)) {
            return 0;
        }
        return LeaveRequestUtils.calculateRequestedDays(startDate, endDate, u.Work_Country__c);
    }
    
    
    
    @AuraEnabled
    public static String cancelLeaveRequest(Id requestId) {
        Set<String> cancellableStatuses = new Set<String>{'Submitted', 'Pending Manager Approval', 'Pending HR Approval', 'Escalated to Senior Manager'};
        
        try {
            Leave_Request__c request = [
                SELECT Id, Status__c 
                FROM Leave_Request__c 
                WHERE Id = :requestId 
            ];
            
            if (!cancellableStatuses.contains(request.Status__c)) {
                throw new AuraHandledException('This request cannot be cancelled. Its current status is: ' + request.Status__c);
            }
            
            if (request.Status__c == 'Pending Manager Approval' || request.Status__c == 'Pending HR Approval') {
                List<ProcessInstanceWorkitem> workItems = [
                    SELECT Id 
                    FROM ProcessInstanceWorkitem 
                    WHERE ProcessInstance.TargetObjectId = :requestId
                ];
                
                if (!workItems.isEmpty()) {
                    Approval.ProcessWorkitemRequest pwr = new Approval.ProcessWorkitemRequest();
                    pwr.setWorkitemId(workItems[0].Id);
                    pwr.setAction('Removed');
                    pwr.setComments('Request recalled by user.');
                    Approval.ProcessResult result = Approval.process(pwr);
                    
                    if (!result.isSuccess()) {
                        throw new AuraHandledException('Failed to recall the request from approval. Please contact your administrator.');
                    }
                }
            }
            
            request.Status__c = 'Cancelled';
            update request;
            
            return 'The leave request has been successfully cancelled.';
            
        } catch (Exception e) {
            throw new AuraHandledException('An error occurred during cancellation: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void requestCancellation(Id leaveRequestId) {
        Leave_Request__c req = [SELECT Id, Status__c FROM Leave_Request__c WHERE Id = :leaveRequestId LIMIT 1];
        if (req.Status__c == 'Approved') {
            req.Status__c = 'Cancellation Requested';
            try {
                update req;
            } catch (DmlException e) {
                if (e.getMessage().contains('UNABLE_TO_LOCK_ROW')) {
                    throw new AuraHandledException('This request is locked and cannot be modified. Please contact an administrator.');
                }
                throw e;
            }
        } else {
            throw new AuraHandledException('Cancellation can only be requested for approved leaves.');
        }
    }

    @AuraEnabled
    public static void withdrawCancellationRequest(Id leaveRequestId) {
        try {
            Leave_Request__c request = [
                SELECT Id, Status__c 
                FROM Leave_Request__c 
                WHERE Id = :leaveRequestId
            ];

            if (request.Status__c != 'Cancellation Requested') {
                throw new AuraHandledException('You can only withdraw a cancellation request if the status is "Cancellation Requested".');
            }

            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id 
                FROM ProcessInstanceWorkitem 
                WHERE ProcessInstance.TargetObjectId = :leaveRequestId
            ];
            
            if (!workItems.isEmpty()) {
                Approval.ProcessWorkitemRequest pwr = new Approval.ProcessWorkitemRequest();
                pwr.setWorkitemId(workItems[0].Id);
                pwr.setAction('Removed'); 
                pwr.setComments('Cancellation request withdrawn by user.');
                
                Approval.ProcessResult result = Approval.process(pwr);
                
                if (!result.isSuccess()) {
                    throw new AuraHandledException('Failed to withdraw the cancellation request from approval process.');
                }
            }

            request.Status__c = 'Approved';
            update request;
            
        } catch (Exception e) {
            throw new AuraHandledException('An error occurred: ' + e.getMessage());
        }
    }
}