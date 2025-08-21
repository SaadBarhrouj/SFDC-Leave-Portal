trigger LeaveBalanceTrigger on Leave_Balance__c (before insert, before update, after insert, after update, before delete) {

    if (Trigger.isAfter && Trigger.isInsert) {
        LeaveBalanceHistoryHelper.createHistoryOnInsert(Trigger.new);
    }

    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate) && !Test.isRunningTest()) {
        Set<String> uniqueKeys = new Set<String>();
        Map<String, Leave_Balance__c> newRecordsMap = new Map<String, Leave_Balance__c>();
        Set<Id> employeeIds = new Set<Id>();
        Set<String> leaveTypes = new Set<String>();
        Set<Integer> years = new Set<Integer>();

        for (Leave_Balance__c record : Trigger.new) {
            if (Trigger.isInsert ||
                (Trigger.isUpdate && (record.Leave_Type__c != Trigger.oldMap.get(record.Id).Leave_Type__c))
            ) {
                String key = record.Employee__c + '-' + record.Leave_Type__c + '-' + String.valueOf(record.Year__c);
                uniqueKeys.add(key);
                newRecordsMap.put(key, record);
                employeeIds.add(record.Employee__c);
                leaveTypes.add(record.Leave_Type__c);
                years.add(record.Year__c.intValue());
            }
        }

        if (!uniqueKeys.isEmpty()) {
            List<Leave_Balance__c> existingRecords = [
                SELECT Id, Employee__c, Leave_Type__c, Year__c
                FROM Leave_Balance__c
                WHERE Employee__c IN :employeeIds
                AND Leave_Type__c IN :leaveTypes
                AND Year__c IN :years
            ];

            Map<String, Leave_Balance__c> existingKeysMap = new Map<String, Leave_Balance__c>();
            for (Leave_Balance__c existing : existingRecords) {
                String existingKey = existing.Employee__c + '-' + existing.Leave_Type__c + '-' + String.valueOf(existing.Year__c);
                existingKeysMap.put(existingKey, existing);
            }

            for (String key : uniqueKeys) {
                if (existingKeysMap.containsKey(key)) {
                    newRecordsMap.get(key).addError('A balance for this employee, leave type, and year already exists.');
                }
            }
        }
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