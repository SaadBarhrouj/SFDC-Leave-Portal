public without sharing class LeaveBalanceHistoryHelper {

    public static void createHistoryOnStatusChange(List<Leave_Request__c> newRequests, Map<Id, Leave_Request__c> oldRequestsMap) {
        
        List<Leave_Balance_History__c> historiesToCreate = new List<Leave_Balance_History__c>();
        Set<Id> balanceIdsToQuery = new Set<Id>();

        for (Leave_Request__c req : newRequests) {
            if (req.Leave_Balance__c != null) {
                balanceIdsToQuery.add(req.Leave_Balance__c);
            }
        }

        Map<Id, Leave_Balance__c> balanceMap = new Map<Id, Leave_Balance__c>();
        if (!balanceIdsToQuery.isEmpty()) {
            balanceMap = new Map<Id, Leave_Balance__c>([
                SELECT Id, Remaining_Days__c
                FROM Leave_Balance__c
                WHERE Id IN :balanceIdsToQuery
            ]);
        }

        for (Leave_Request__c newReq : newRequests) {
            Leave_Request__c oldReq = oldRequestsMap.get(newReq.Id);

            if (newReq.Status__c != oldReq.Status__c) {

                if (newReq.Leave_Type__c == 'RTT' || newReq.Leave_Type__c == 'Paid Leave') {
                    
                    Leave_Balance__c currentBalance = balanceMap.get(newReq.Leave_Balance__c);
                    Decimal newBalanceValue = (currentBalance != null) ? currentBalance.Remaining_Days__c : null;

                    if (newReq.Status__c == 'Approved' && oldReq.Status__c != 'Approved') {
                        historiesToCreate.add(new Leave_Balance_History__c(
                            Employee__c = newReq.Requester__c,
                            Leave_Type__c = newReq.Leave_Type__c,
                            Movement_Date__c = Date.today(),
                            Movement_Type__c = 'Deduction',
                            Number_of_Days__c = -math.abs(newReq.Number_of_Days_Requested__c),
                            Source_of_Movement__c = 'Leave Request Approved',
                            Justification__c = 'Leave from ' + newReq.Start_Date__c.format() + ' to ' + newReq.End_Date__c.format() + ' (' + newReq.Name + ').',
                            New_Balance__c = newBalanceValue
                        ));
                    }

                    if (newReq.Status__c == 'Cancelled' && oldReq.Status__c == 'Cancellation Requested') {
                        historiesToCreate.add(new Leave_Balance_History__c(
                            Employee__c = newReq.Requester__c,
                            Leave_Type__c = newReq.Leave_Type__c,
                            Movement_Date__c = Date.today(),
                            Movement_Type__c = 'Accrual',
                            Number_of_Days__c = math.abs(newReq.Number_of_Days_Requested__c),
                            Source_of_Movement__c = 'Leave Request Cancelled',
                            Justification__c = 'Cancellation of leave from ' + newReq.Start_Date__c.format() + ' to ' + newReq.End_Date__c.format() + ' (' + newReq.Name + ').',
                            New_Balance__c = newBalanceValue 
                        ));
                    }
                }
            }
        }

        if (!historiesToCreate.isEmpty()) {
            insert historiesToCreate;
        }
    }

     public static void createHistoryOnInsert(List<Leave_Balance__c> newBalances) {
        List<Leave_Balance_History__c> historiesToCreate = new List<Leave_Balance_History__c>();
        
        String source;
        if (System.isBatch() || System.isScheduled()) {
            source = 'Annual Balance Allocation';
        } else {
            source = 'Balance created by ' + UserInfo.getName();
        }

        for (Leave_Balance__c balance : newBalances) {
            if (balance.Allocated_Days__c != null && balance.Allocated_Days__c > 0) {
                historiesToCreate.add(new Leave_Balance_History__c(
                    Employee__c = balance.Employee__c,
                    Leave_Type__c = balance.Leave_Type__c,
                    Movement_Date__c = Date.today(),
                    Movement_Type__c = 'Accrual',
                    Number_of_Days__c = balance.Allocated_Days__c,
                    New_Balance__c = balance.Remaining_Days__c,
                    Source_of_Movement__c = source,
                    Justification__c = 'Initial ' + String.valueOf(balance.Year__c) + ' balance allocation.'
                ));
            }
        }

        if (!historiesToCreate.isEmpty()) {
            insert historiesToCreate;
        }
    }
}