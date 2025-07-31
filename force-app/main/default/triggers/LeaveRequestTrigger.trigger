trigger LeaveRequestTrigger on Leave_Request__c (before insert, before update, after insert, after update, after delete, after undelete) {
    
    if(Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        Set<Id> requesterIds = new Set<Id>();
        for (Leave_Request__c request : Trigger.new) {
            if (request.Requester__c != null) {
                requesterIds.add(request.Requester__c);
            }
        }
        
        Map<Id, User> requesterMap = new Map<Id, User>();
        if (!requesterIds.isEmpty()) {
            requesterMap = new Map<Id, User>([
                SELECT Work_Country__c 
                FROM User 
                WHERE Id IN :requesterIds
            ]);
        }
        
        for (Leave_Request__c request : Trigger.new) {
            if (request.Requester__c != null) {
                User theRequester = requesterMap.get(request.Requester__c);
                String countryCode = (theRequester != null) ? theRequester.Work_Country__c : null;
                
                if (request.Start_Date__c != null && request.End_Date__c != null && countryCode != null) {
                    Decimal days = LeaveRequestUtils.calculateRequestedDays(
                        request.Start_Date__c,
                    request.End_Date__c,
                    countryCode
                        );
                    request.Number_of_Days_Requested__c = days;
                }
            }
        }
    }
    
    if(Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate || Trigger.isDelete || Trigger.isUndelete)) {
        Set<Id> leaveBalanceIds = new Set<Id>();
        List<Leave_Request__c> records = Trigger.isDelete ? Trigger.old : Trigger.new;
        for(Leave_Request__c req : records) {
            if(req.Leave_Balance__c != null) {
                leaveBalanceIds.add(req.Leave_Balance__c);
            }
        }
        LeaveRequestUtils.updateUsedDays(leaveBalanceIds);
        if (Trigger.isInsert || Trigger.isUpdate) {
            LeaveRequestUtils.submitForApproval(Trigger.new);
        }
    }

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            LeaveRequestUtils.validateNoOverlappingRequests(Trigger.new, null);
        }
        if (Trigger.isUpdate) {
            LeaveRequestUtils.validateNoOverlappingRequests(Trigger.new, Trigger.oldMap);
        }
    }

        if (Trigger.isAfter && Trigger.isUpdate) {
            LeaveRequestHistoryHelper.createHistoryOnStatusChange(Trigger.new, Trigger.oldMap);
        }
}