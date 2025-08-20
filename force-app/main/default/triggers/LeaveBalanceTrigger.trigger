trigger LeaveBalanceTrigger on Leave_Balance__c (after insert, before delete) {

    if (Trigger.isAfter && Trigger.isInsert) {
        LeaveBalanaceHistoryHelper.createHistoryOnInsert(Trigger.new);
    }

    if (Trigger.isDelete) {
        Map<Id, AggregateResult> balanceRequestCounts = new Map<Id, AggregateResult>([
            SELECT Leave_Balance__c, COUNT(Id) requestCount
            FROM Leave_Request__c
            WHERE Leave_Balance__c IN :Trigger.oldMap.keySet()
            AND Leave_Balance__c != null
            GROUP BY Leave_Balance__c
        ]);
    
        if (!balanceRequestCounts.isEmpty()) {
            for (Leave_Balance__c balanceToDelete : Trigger.old) {
                if (balanceToDelete.Id != null && balanceRequestCounts.containsKey(balanceToDelete.Id)) {
                    balanceToDelete.addError('This balance cannot be deleted because it is associated with existing leave requests.');
                }
            }
        }
    }
}