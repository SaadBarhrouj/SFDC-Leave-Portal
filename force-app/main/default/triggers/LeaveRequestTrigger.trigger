trigger LeaveRequestTrigger on Leave_Request__c (before insert, before update, after insert, after update, after delete, after undelete) {
    
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            for (Leave_Request__c request : Trigger.new) {
                if (request.Status__c == null || request.Status__c == '') {
                    request.Status__c = 'Submitted';
                }
                if (request.Requester__c == null) {
                    request.Requester__c = UserInfo.getUserId();
                }
            }
            LeaveRequestUtils.validateNoOverlappingRequests(Trigger.new, null);
            LeaveRequestUtils.validateNoticePeriod(Trigger.new, null);
            
        }
        if (Trigger.isUpdate) {
            LeaveRequestUtils.validateNoOverlappingRequests(Trigger.new, Trigger.oldMap);
            LeaveRequestUtils.validateNoticePeriod(Trigger.new, Trigger.oldMap);
            
        }
            
        Set<Id> requesterIds = new Set<Id>();
        for (Leave_Request__c request : Trigger.new) {
            if (request.Requester__c != null) {
                requesterIds.add(request.Requester__c);
            }
        }
        
        Map<Id, User> requesterMap = new Map<Id, User>();
        if (!requesterIds.isEmpty()) {
            requesterMap = new Map<Id, User>([SELECT Work_Country__c FROM User WHERE Id IN :requesterIds]);
        }
        
        for (Leave_Request__c request : Trigger.new) {
            if (request.Requester__c != null) {
                User theRequester = requesterMap.get(request.Requester__c);
                String countryCode = (theRequester != null) ? theRequester.Work_Country__c : null;
                
                if (request.Start_Date__c != null && request.End_Date__c != null && countryCode != null) {
                    Decimal days = LeaveRequestUtils.calculateRequestedDays(request.Start_Date__c, request.End_Date__c, countryCode);
                    request.Number_of_Days_Requested__c = days;
                }
            }
        }
        
        if (Trigger.isInsert) {
            for (Leave_Request__c request : Trigger.new) {
                if (request.Leave_Type__c != null && request.Leave_Type__c != 'Sick Leave' && request.Leave_Type__c != 'Training' && request.Leave_Type__c != 'Unpaid Leave') {
                    try {
                        Leave_Balance__c balance = [SELECT Id FROM Leave_Balance__c WHERE Employee__c = :request.Requester__c AND Leave_Type__c = :request.Leave_Type__c LIMIT 1];
                        request.Leave_Balance__c = balance.Id;
                    } catch (QueryException e) {
                        request.addError('No valid leave balance found for the selected leave type. Please contact HR.');
                    }
                }
            }
        }
    }
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            LeaveRequestUtils.submitForApproval(Trigger.new);
        }
        
        if (Trigger.isUpdate) {
            LeaveBalanceHistoryHelper.createHistoryOnStatusChange(Trigger.new, Trigger.oldMap);
        }
        
        Set<Id> leaveBalanceIds = new Set<Id>();
        List<Leave_Request__c> records = Trigger.isDelete ? Trigger.old : Trigger.new;
        for (Leave_Request__c req : records) {
            if (req.Leave_Balance__c != null) {
                leaveBalanceIds.add(req.Leave_Balance__c);
            }
        }
        LeaveRequestUtils.updateUsedDays(leaveBalanceIds);
    }
}