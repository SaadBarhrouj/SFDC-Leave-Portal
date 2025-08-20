public without sharing class LeaveRequestUtils {
    
    public static Decimal calculateRequestedDays(Date startDate, Date endDate, String countryCode) {
        if (startDate == null || endDate == null || startDate > endDate) {
            return 0;
        }
        
        Map<Date, Holiday__c> holidaysMap = new Map<Date, Holiday__c>();
        for (Holiday__c holiday : [
            SELECT Start_Date__c, End_Date__c, Deduction_Value__c 
            FROM Holiday__c
            WHERE End_Date__c >= :startDate 
              AND Start_Date__c <= :endDate
              AND Country_Code__c = :countryCode
        ]) {
            Date currentDateInHoliday = holiday.Start_Date__c;
            while(currentDateInHoliday <= holiday.End_Date__c) {
                holidaysMap.put(currentDateInHoliday, holiday);
                currentDateInHoliday = currentDateInHoliday.addDays(1);
            }
        }
        
        Decimal requestedDays = 0;
        Date currentDate = startDate;
        
        while (currentDate <= endDate) {
            
            Datetime dt = Datetime.newInstance(currentDate.year(), currentDate.month(), currentDate.day());
            String dayOfWeek = dt.format('E');
            
            if (dayOfWeek != 'Sat' && dayOfWeek != 'Sun') {
                if (holidaysMap.containsKey(currentDate)) {
                    Decimal deduction = holidaysMap.get(currentDate).Deduction_Value__c;
                    requestedDays += (1 - deduction);
                } else {
                    requestedDays += 1;
                }
            }
            currentDate = currentDate.addDays(1);
        }
        return requestedDays;
    }

    @future
    public static void recalculateAffectedRequests(Set<Id> holidayIds) {
        List<Holiday__c> holidays = [
            SELECT Country_Code__c, Start_Date__c, End_Date__c 
            FROM Holiday__c 
            WHERE Id IN :holidayIds
        ];
        if (holidays.isEmpty()) {
            return;
        }
        Set<String> countryCodes = new Set<String>();
        Date minDate = Date.newInstance(9999, 1, 1);
        Date maxDate = Date.newInstance(1000, 1, 1);
        for (Holiday__c h : holidays) {
            countryCodes.add(h.Country_Code__c);
            if (h.Start_Date__c < minDate) minDate = h.Start_Date__c;
            if (h.End_Date__c > maxDate) maxDate = h.End_Date__c;
        }
        recalcRequestsByRange(countryCodes, minDate, maxDate);
    }
    
    public static void recalcRequestsByRange(Set<String> countryCodes, Date minDate, Date maxDate) {
        if (countryCodes == null || countryCodes.isEmpty() || minDate == null || maxDate == null) return;
        List<Leave_Request__c> requestsToUpdate = [
            SELECT Id, Start_Date__c, End_Date__c, Requester__r.Work_Country__c, Number_of_Days_Requested__c
            FROM Leave_Request__c
            WHERE Status__c IN ('Submitted', 'Pending Manager Approval', 'Pending HR Approval', 'Escalated to Senior Manager')
              AND Requester__r.Work_Country__c IN :countryCodes
              AND Start_Date__c <= :maxDate
              AND End_Date__c >= :minDate
        ];
        if (requestsToUpdate.isEmpty()) return;
        List<Leave_Request__c> updatedRequests = new List<Leave_Request__c>();
        for (Leave_Request__c request : requestsToUpdate) {
            Decimal originalDays = request.Number_of_Days_Requested__c;
            Decimal newDays = calculateRequestedDays(
                request.Start_Date__c,
                request.End_Date__c,
                request.Requester__r.Work_Country__c
            );
            if (originalDays != newDays) {
                request.Number_of_Days_Requested__c = newDays;
                updatedRequests.add(request);
            }
        }
        if (!updatedRequests.isEmpty()) {
            update updatedRequests;
        }
    }
    
    public static void updateUsedDays(Set<Id> leaveBalanceIds) {
        if(leaveBalanceIds == null || leaveBalanceIds.isEmpty()) return;
        Map<Id, Decimal> usedDaysMap = new Map<Id, Decimal>();
        for(AggregateResult ar : [
            SELECT Leave_Balance__c lbId, SUM(Number_of_Days_Requested__c) total
            FROM Leave_Request__c
            WHERE Leave_Balance__c IN :leaveBalanceIds
            AND Status__c IN ('Approved', 'Cancellation Requested')
            GROUP BY Leave_Balance__c
        ]) {
            usedDaysMap.put((Id)ar.get('lbId'), (Decimal)ar.get('total'));
        }
        List<Leave_Balance__c> balancesToUpdate = new List<Leave_Balance__c>();
        for(Leave_Balance__c lb : [
            SELECT Id
            FROM Leave_Balance__c
            WHERE Id IN :leaveBalanceIds
        ]) {
            lb.Used_Days__c = usedDaysMap.containsKey(lb.Id) ? usedDaysMap.get(lb.Id) : 0;
            balancesToUpdate.add(lb);
        }
        if(!balancesToUpdate.isEmpty()) {
            update balancesToUpdate;
        }
    }
    
    public static void submitForApproval(List<Leave_Request__c> requests) {
        for (Leave_Request__c req : requests) {
            if (req.Status__c == 'Submitted' || req.Status__c == 'Cancellation Requested') {
                try {
                    Approval.ProcessSubmitRequest aprReq = new Approval.ProcessSubmitRequest();
                    aprReq.setObjectId(req.Id);
                    Approval.ProcessResult result = Approval.process(aprReq);
                } catch (Exception e) {
                    System.debug('Approval submission failed: ' + e.getMessage());
                }
            }
        }
    }
    
   public static void validateNoOverlappingRequests(List<Leave_Request__c> newRequests, Map<Id, Leave_Request__c> oldMap) {
    Set<Id> requesterIds = new Set<Id>();
    for (Leave_Request__c req : newRequests) {
        Boolean datesChanged = oldMap == null ||
            (req.Start_Date__c != oldMap.get(req.Id).Start_Date__c ||
             req.End_Date__c != oldMap.get(req.Id).End_Date__c);
        
        if (datesChanged) {
            requesterIds.add(req.Requester__c);
        }
    }
    
    if (requesterIds.isEmpty()) {
        return;
    }
    
    List<Leave_Request__c> existingRequests = [
        SELECT Id, Start_Date__c, End_Date__c, Requester__c
        FROM Leave_Request__c
        WHERE Requester__c IN :requesterIds
        AND Status__c NOT IN ('Rejected', 'Cancelled')
    ];
    
    for (Leave_Request__c newReq : newRequests) {
        if (oldMap != null &&
            newReq.Start_Date__c == oldMap.get(newReq.Id).Start_Date__c &&
            newReq.End_Date__c == oldMap.get(newReq.Id).End_Date__c) {
            continue;
        }
        
        for (Leave_Request__c existingReq : existingRequests) {
            if (newReq.Id == existingReq.Id) {
                continue;
            }
          
            if (newReq.Requester__c == existingReq.Requester__c) {
                if (newReq.Start_Date__c <= existingReq.End_Date__c && newReq.End_Date__c >= existingReq.Start_Date__c) {
                    newReq.addError('You already have a leave request that overlaps with the selected dates.');
                }
            }
        }
    }
}
    
    public static void validateRequestOnApproval(Id leaveRequestId) {
        List<Leave_Request__c> requests = [
        SELECT Id, Start_Date__c 
        FROM Leave_Request__c 
        WHERE Id = :leaveRequestId
        ];

        if (requests.isEmpty()) {
            throw new AuraHandledException('Leave request not found.');
        }
        
        Leave_Request__c requestToApprove = requests[0];
        if (requestToApprove.Start_Date__c < Date.today()) {
            throw new AuraHandledException('This leave request cannot be approved because its start date is in the past.');
        }
    }

    public static void validateNoticePeriod(List<Leave_Request__c> newRequests, Map<Id, Leave_Request__c> oldMap) {
    Leave_Policy_Settings__c settings = Leave_Policy_Settings__c.getOrgDefaults();
    Integer minNoticeDays = (settings.Minimum_Notice_Period_Days__c != null) ? 
                           Integer.valueOf(settings.Minimum_Notice_Period_Days__c) : 5;
    
    for (Leave_Request__c request : newRequests) {
        if (request.Leave_Type__c == 'Sick Leave' || request.Status__c != 'Submitted' ) continue;
        
        Boolean isNew = (oldMap == null);
        Boolean dateChanged = !isNew && (request.Start_Date__c != oldMap.get(request.Id).Start_Date__c);
        
        if (isNew || dateChanged) {
            Integer noticeDays = Date.today().daysBetween(request.Start_Date__c);
            
            if (noticeDays < minNoticeDays) {
                request.Start_Date__c.addError('Leave requests must be submitted at least ' + 
                                             minNoticeDays + ' days in advance according to company policy.');
            }
        }
    }
}
}