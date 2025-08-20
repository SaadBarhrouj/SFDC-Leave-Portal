public without sharing class LeaveBalanceController {

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
                  AND Leave_Type__c IN ('Sick Leave', 'Training', 'Unpaid Leave')
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

            BalanceOverview unpaidLeave = new BalanceOverview();
            unpaidLeave.type = 'Unpaid Leave';
            unpaidLeave.remaining = null; 
            unpaidLeave.consumed = consumedMap.containsKey('Unpaid Leave') ? consumedMap.get('Unpaid Leave') : 0;
            overviews.add(unpaidLeave);

            return overviews;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving balance overviews: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Leave_Policy_Settings__c getLeavePolicySettings() {
        return Leave_Policy_Settings__c.getOrgDefaults();
    }

        @AuraEnabled(cacheable=true)
        public static List<Leave_Balance__c> getBalances() {
            try {
                return [
                    SELECT Id, Employee__c, Employee__r.Name, Employee__r.FullPhotoUrl, 
                        Leave_Type__c, Allocated_Days__c, Used_Days__c, 
                        Remaining_Days__c, Year__c, LastModifiedDate
                    FROM Leave_Balance__c
                    WHERE Leave_Type__c IN ('RTT', 'Paid Leave')
                    ORDER BY Employee__r.Name, Leave_Type__c
                ];
            } catch (Exception e) {
                throw new AuraHandledException('Error retrieving balances: ' + e.getMessage());
            }
        }

    @AuraEnabled(cacheable=true)
    public static List<Leave_Balance_History__c> getAllBalanceHistory() {
        try {
            return [
                SELECT Name, Movement_Date__c, Movement_Type__c, Leave_Type__c,
                       Source_of_Movement__c, Number_of_Days__c, New_Balance__c, Justification__c,
                       Employee__c, Employee__r.Name, Employee__r.FullPhotoUrl
                FROM Leave_Balance_History__c
                ORDER BY Movement_Type__c DESC
                LIMIT 2000
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving all balance history: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Leave_Balance_History__c> getBalanceHistoryForCurrentUser() {
        try {
            return [
                SELECT Name, Movement_Date__c, Movement_Type__c, Leave_Type__c,
                       Source_of_Movement__c, Number_of_Days__c, New_Balance__c, Justification__c,
                       Employee__c, Employee__r.Name, Employee__r.FullPhotoUrl
                FROM Leave_Balance_History__c
                WHERE Employee__c = :UserInfo.getUserId()
                ORDER BY CreatedDate DESC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving balance history: ' + e.getMessage());
        }
    }

   
    @AuraEnabled
    public static void deleteBalanceWithJustification(Id balanceId, String justification) {
        if (String.isBlank(justification)) {
            throw new AuraHandledException('Justification is mandatory for balance deletion.');
        }

        try {
            Leave_Balance__c balanceToDelete = [
                SELECT Id, Employee__c, Leave_Type__c, Remaining_Days__c 
                FROM Leave_Balance__c 
                WHERE Id = :balanceId
                LIMIT 1
            ];

            Leave_Balance_History__c history = new Leave_Balance_History__c(
                Employee__c = balanceToDelete.Employee__c,
                Leave_Type__c = balanceToDelete.Leave_Type__c,
                Movement_Date__c = Date.today(),
                Movement_Type__c = 'Correction',
                Number_of_Days__c = -balanceToDelete.Remaining_Days__c,
                New_Balance__c = 0,
                Source_of_Movement__c = 'Balance record deleted by ' + UserInfo.getName(),
                Justification__c = justification
            );
            insert history;

            delete balanceToDelete;

        } catch (DmlException e) {
            throw new AuraHandledException('This balance cannot be deleted because it is associated with existing leave requests.');
        } catch (Exception e) {
            throw new AuraHandledException('An error occurred during balance deletion: ' + e.getMessage());
        }
    }

    @AuraEnabled
public static void updateBalanceWithJustification(Id balanceId, Decimal newAllocatedDays, String justification) {
    if (String.isBlank(justification)) {
        throw new AuraHandledException('Justification is mandatory for any manual correction.');
    }

    Leave_Balance__c balance = [
        SELECT Id, Allocated_Days__c, Remaining_Days__c, Employee__c, Leave_Type__c 
        FROM Leave_Balance__c 
        WHERE Id = :balanceId
    ];
    
    Decimal oldRemainingBalance = balance.Remaining_Days__c;

    balance.Allocated_Days__c = newAllocatedDays;
    update balance;

    Leave_Balance__c updatedBalance = [SELECT Remaining_Days__c FROM Leave_Balance__c WHERE Id = :balanceId];
    Decimal daysChanged = updatedBalance.Remaining_Days__c - oldRemainingBalance;
    
    Leave_Balance_History__c history = new Leave_Balance_History__c(
        Employee__c = balance.Employee__c,
        Leave_Type__c = balance.Leave_Type__c,
        Movement_Date__c = Date.today(),
        Movement_Type__c = 'Correction',
        Number_of_Days__c = daysChanged,
        New_Balance__c = updatedBalance.Remaining_Days__c,
        Source_of_Movement__c = 'Manual correction by ' + UserInfo.getName(),
        Justification__c = justification
    );
    insert history;
}
}