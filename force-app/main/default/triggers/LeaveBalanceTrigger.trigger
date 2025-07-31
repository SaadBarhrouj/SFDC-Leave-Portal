trigger LeaveBalanceTrigger on Leave_Balance__c (before insert, before update) {
    Set<String> uniqueKeys = new Set<String>();
    for (Leave_Balance__c record : Trigger.new) {
        uniqueKeys.add(record.Employee__c + '-' + record.Leave_Type__c + '-' + String.valueOf(record.Year__c));
    }

    List<Leave_Balance__c> existingRecords = [
        SELECT Employee__c, Leave_Type__c, Year__c
        FROM Leave_Balance__c
    ];

    Map<String, Leave_Balance__c> existingKeysMap = new Map<String, Leave_Balance__c>();
    for (Leave_Balance__c existing : existingRecords) {
        String existingKey = existing.Employee__c + '-' + existing.Leave_Type__c + '-' + String.valueOf(existing.Year__c);
        existingKeysMap.put(existingKey, existing);
    }

    for (Leave_Balance__c record : Trigger.new) {
        String key = record.Employee__c + '-' + record.Leave_Type__c + '-' + String.valueOf(record.Year__c);
        if (existingKeysMap.containsKey(key)) {
            record.addError('A balance for this employee, leave type, and year already exists.');
        }
    }
}