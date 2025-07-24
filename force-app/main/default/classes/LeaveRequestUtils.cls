public class LeaveRequestUtils {
    
    public static Decimal calculateRequestedDays(Date startDate, Date endDate, String countryCode) {
        if (startDate == null || endDate == null || startDate > endDate) {
            return 0;
        }
        
        Map<Date, Holiday__c> holidaysMap = new Map<Date, Holiday__c>();
        for (Holiday__c holiday : [
            SELECT Holiday_Date__c, Deduction_Value__c 
            FROM Holiday__c
            WHERE Holiday_Date__c >= :startDate 
              AND Holiday_Date__c <= :endDate
              AND Country_Code__c = :countryCode
        ]) {
            holidaysMap.put(holiday.Holiday_Date__c, holiday);
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
}