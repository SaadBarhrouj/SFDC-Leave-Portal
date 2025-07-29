
public with sharing class LeaveBalanceController {

    
    public class BalanceOverview {
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public Decimal remaining { get; set; }
        @AuraEnabled public Decimal consumed { get; set; }
    }

  
    @AuraEnabled
    public static List<BalanceOverview> getLeaveBalanceOverviews() {
        try {
            List<BalanceOverview> overviews = new List<BalanceOverview>();
            Id currentUserId = UserInfo.getUserId();

            for (Leave_Balance__c balance : [
                SELECT Leave_Type__c, Remaining_Days__c, Used_Days__c
                FROM Leave_Balance__c
                WHERE Employee__c = :currentUserId AND Leave_Type__c IN ('RTT', 'Paid Leave')
                And Year__c = :Date.today().year()
            ]) {
                BalanceOverview overview = new BalanceOverview();
                overview.type = balance.Leave_Type__c;
                overview.remaining = balance.Remaining_Days__c == null ? 0 : balance.Remaining_Days__c;
                overview.consumed = balance.Used_Days__c;
                overviews.add(overview);
            }

            Map<String, Decimal> consumedMap = new Map<String, Decimal>();

            for (AggregateResult ar : [
                SELECT SUM(Number_of_Days_Requested__c) totalDays, Leave_Type__c
                FROM Leave_Request__c
                WHERE Requester__c = :currentUserId
                  AND Leave_Type__c IN ('Sick Leave', 'Training')
                  AND (Status__c = 'Approved' OR Status__c = 'Cancellation Requested')
                  AND CALENDAR_YEAR(Start_Date__c) = :Date.today().year()
                GROUP BY Leave_Type__c
            ]) {
                String leaveType = (String)ar.get('Leave_Type__c');
                Decimal totalDays = (Decimal)ar.get('totalDays');
                consumedMap.put(leaveType, totalDays == null ? 0 : totalDays);
            }

            BalanceOverview sickLeave = new BalanceOverview();
            sickLeave.type = 'Sick Leave';
            sickLeave.remaining = null; 
            sickLeave.consumed = consumedMap.containsKey('Sick Leave') ? consumedMap.get('Sick Leave') : 0;
            overviews.add(sickLeave);

            BalanceOverview training = new BalanceOverview();
            training.type = 'Training';
            training.remaining = null; 
            training.consumed = consumedMap.containsKey('Training') ? consumedMap.get('Training') : 0;
            overviews.add(training);

            return overviews;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving balance overviews: ' + e.getMessage());
        }
    }
    

    
    @AuraEnabled(cacheable=true)
    public static List<Leave_Balance_History__c> getBalanceHistoryForCurrentUser() {
        try {
            return [
                SELECT Name, Movement_Date__c, Movement_Type__c, Leave_Type__c,
                       Source_of_Movement__c, Number_of_Days__c, New_Balance__c
                FROM Leave_Balance_History__c
                WHERE Employee__c = :UserInfo.getUserId()
                ORDER BY Movement_Date__c DESC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving balance history: ' + e.getMessage());
        }
    }
}