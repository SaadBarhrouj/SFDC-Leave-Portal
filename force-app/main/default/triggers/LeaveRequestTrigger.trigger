trigger LeaveRequestTrigger on Leave_Request__c (before insert, before update) {

    // Step 1: Populate Leave Balance ID using LeaveBalanceHandler
    LeaveBalanceHandler.populateLeaveBalanceId(Trigger.new);

    // Step 2: Calculate requested days using existing logic
    Set<Id> requesterIds = new Set<Id>();
    for (Leave_Request__c request : Trigger.new) {
        if (request.Requester__c != null) {
            requesterIds.add(request.Requester__c);
        }
    }

    Map<Id, User> requesterMap = new Map<Id, User>();
    if (!requesterIds.isEmpty()) {
        requesterMap = new Map<Id, User>([
            SELECT Country_Code__c 
            FROM User 
            WHERE Id IN :requesterIds
        ]);
    }

    for (Leave_Request__c request : Trigger.new) {
        if (request.Requester__c != null) {
            User theRequester = requesterMap.get(request.Requester__c);
            String countryCode = (theRequester != null) ? theRequester.Country_Code__c : null;
            
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