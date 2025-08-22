public without sharing class LeaveRequestController {
    
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
    
    @AuraEnabled
    public static String recallAndUpdate(Id recordId, Date startDate, Date endDate, String comments) {
        System.debug('--- recallAndUpdate START ---');
        System.debug('Parameters: recordId=' + recordId);
        
        try {
            ProcessInstanceWorkitem workItem;
            try {
                workItem = [
                    SELECT Id FROM ProcessInstanceWorkitem
                    WHERE ProcessInstance.TargetObjectId = :recordId AND ProcessInstance.Status = 'Pending'
                    LIMIT 1
                ];
            } catch (Exception e) {
            }
            
            if (workItem != null) {
                System.debug('Recalling request...');
                Approval.ProcessWorkitemRequest recallReq = new Approval.ProcessWorkitemRequest();
                recallReq.setWorkitemId(workItem.Id);
                recallReq.setAction('Removed');
                recallReq.setComments('Recalled by user for modification.');
                Approval.process(recallReq);
                System.debug('Request recalled.');
            }
            
            System.debug('Updating Leave Request record...');
            Leave_Request__c requestToUpdate = new Leave_Request__c(Id = recordId);
            requestToUpdate.Start_Date__c = startDate;
            requestToUpdate.End_Date__c = endDate;
            requestToUpdate.Employee_Comments__c = comments;
            Leave_Request__c request = [
                SELECT 
                    Id, 
                    Status__c, 
                    Approver__c, 
                    Requester__r.ManagerId,
                    Requester__r.Manager.ManagerId,
                    Last_Approver__c
                FROM Leave_Request__c 
                WHERE Id = :recordId 
                LIMIT 1
            ];

            if (request.Status__c == 'Approved') {
                update requestToUpdate;

                return 'Request was successfully updated.';
            }

            
            if (request.Status__c != 'Escalated to Senior Manager') {
                requestToUpdate.Status__c = 'Submitted';
            }

            
            if (request.Status__c == 'Pending HR Approval') {
                if (request.Last_Approver__c != null) {
                    if (request.Last_Approver__c == request.Requester__r.ManagerId) {
                        requestToUpdate.Status__c = 'Submitted';
                        System.debug('Status updated to "Submitted".');
                    }
                    else if (request.Last_Approver__c == request.Requester__r.Manager.ManagerId) {
                        requestToUpdate.Status__c = 'Escalated to Senior Manager';
                        System.debug('Status updated to "Escalated to Senior Manager".');
                    }
                }
                else {
                    requestToUpdate.Status__c = 'Pending Manager Approval';
                    System.debug('Status updated to "Pending Manager Approval" because Last_Approver__c is null.');
                }
            }
            
            update requestToUpdate;
            System.debug('Leave Request record updated.');
            
            System.debug('Calling future method to resubmit...');
            resubmitForApproval(recordId);
            
            System.debug('--- recallAndUpdate END (Success) ---');
            return 'Request updated. Resubmission initiated.';
            
        } catch (Exception e) {
            System.debug('--- recallAndUpdate END (Exception) ---');
            System.debug('Error: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static void resubmitForApproval(Id recordId) {
        System.debug('--- @future resubmitForApproval START for recordId: ' + recordId + ' ---');
        
        Leave_Request__c requestToSubmit = [SELECT Id FROM Leave_Request__c WHERE Id = :recordId];
        
        if (requestToSubmit != null) {
            Approval.ProcessSubmitRequest submitReq = new Approval.ProcessSubmitRequest();
            submitReq.setObjectId(requestToSubmit.Id);
            submitReq.setComments('Request resubmitted after modification.');
            
            try {
                Approval.ProcessResult result = Approval.process(submitReq);
                if (result.isSuccess()) {
                    System.debug('Future resubmission successful.');
                } else {
                    System.debug('Future resubmission failed: ' + result.getErrors()[0].getMessage());
                }
            } catch (Exception e) {
                System.debug('Exception in future resubmission: ' + e.getMessage());
            }
        }
        System.debug('--- @future resubmitForApproval END ---');
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getMyLeaves() {
        try {
            return [
                SELECT Id, Name, Leave_Type__c, Start_Date__c, End_Date__c, 
                       Number_of_Days_Requested__c, Status__c, Employee_Comments__c,
                       Approver_Comments__c, Rejection_Reason__c, CreatedDate,
                       Requester__r.Name, Leave_Balance__r.Leave_Type__c, LastModifiedDate
                FROM Leave_Request__c
                WHERE Requester__c = :UserInfo.getUserId()
                ORDER BY LastModifiedDate DESC
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
    
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getAbsentEmployees() {
        Date today = Date.today();
        return [
            SELECT Id, Requester__c, Requester__r.Name, Requester__r.FullPhotoUrl, Leave_Type__c, Start_Date__c, End_Date__c
            FROM Leave_Request__c
            WHERE (Status__c = 'Approved' OR Status__c = 'Cancellation Requested')
            AND Start_Date__c <= :today
            AND End_Date__c >= :today
        ];
    }
}
