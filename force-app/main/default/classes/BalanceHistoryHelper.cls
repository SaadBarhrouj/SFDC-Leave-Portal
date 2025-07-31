public class BalanceHistoryHelper {

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
                            Source_of_Movement__c = 'Leave Request ' + newReq.Name + ' Approved',
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
                            Source_of_Movement__c = 'Leave Request ' + newReq.Name + ' Cancelled',
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

    public static void createCorrectionHistory(List<Leave_Balance__c> newBalances, Map<Id, Leave_Balance__c> oldBalancesMap) {
        List<Leave_Balance_History__c> historiesToCreate = new List<Leave_Balance_History__c>();

        for (Leave_Balance__c newBalance : newBalances) {
            Leave_Balance__c oldBalance = oldBalancesMap.get(newBalance.Id);

            if (newBalance.Allocated_Days__c != oldBalance.Allocated_Days__c || newBalance.Used_Days__c != oldBalance.Used_Days__c) {

                Decimal changeInDays = (newBalance.Remaining_Days__c - oldBalance.Remaining_Days__c);

                Leave_Balance_History__c history = new Leave_Balance_History__c(
                    Employee__c = newBalance.Employee__c,
                    Leave_Type__c = newBalance.Leave_Type__c,
                    Movement_Date__c = Date.today(),
                    Movement_Type__c = 'Correction',
                    Number_of_Days__c = changeInDays,
                    Source_of_Movement__c = 'Manual correction by HR. Old remaining balance: ' + oldBalance.Remaining_Days__c,
                    New_Balance__c = newBalance.Remaining_Days__c
                );
                historiesToCreate.add(history);
            }
        }

        if (!historiesToCreate.isEmpty()) {
            insert historiesToCreate;
        }
    }
}