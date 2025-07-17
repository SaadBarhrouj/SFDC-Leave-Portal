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

    @AuraEnabled(cacheable=true)
    public static Decimal getNumberOfDaysRequested(Date startDate, Date endDate) {
        if (startDate == null || endDate == null || startDate > endDate) {
            return 0;
        }
        // Récupérer le code pays de l'utilisateur actuel
        User u = [SELECT Country_Code__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        // Appeler la méthode utilitaire existante
        return LeaveRequestUtils.calculateRequestedDays(startDate, endDate, u.Country_Code__c);
    }

    @AuraEnabled
    public static String submitForApproval(String requestId) {
        /* Leave_Request__c requestToSubmit = [
            SELECT Id, Requester__c, Requester__r.ManagerId 
            FROM Leave_Request__c 
            WHERE Id = :requestId 
            LIMIT 1
        ];

        if (requestToSubmit.Requester__r.ManagerId == null) {
            throw new AuraHandledException('Submission failed: You do not have a manager assigned in Salesforce. Please contact your administrator.');
        } */

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

    @AuraEnabled
    public static String cancelLeaveRequest(Id requestId) {
        Set<String> cancellableStatuses = new Set<String>{'Submitted', 'Pending Manager Approval', 'Pending HR Approval'};

        try {
            Leave_Request__c request = [
                SELECT Id, Status__c 
                FROM Leave_Request__c 
                WHERE Id = :requestId 
                WITH SECURITY_ENFORCED
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
}