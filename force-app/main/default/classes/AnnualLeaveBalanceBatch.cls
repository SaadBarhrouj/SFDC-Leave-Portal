public without sharing class AnnualLeaveBalanceBatch implements Database.Batchable<sObject>, Database.Stateful {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id FROM User WHERE IsActive = true]);
    }

    public void execute(Database.BatchableContext bc, List<User> userScope) {
        Integer nextYear = Date.today().year() + 1;
        Set<Id> userIdsInScope = new Map<Id, User>(userScope).keySet();

        Set<Id> usersWithExistingPaidLeaveBalance = new Set<Id>();
        Set<Id> usersWithExistingRTTBalance = new Set<Id>();

        for (Leave_Balance__c lb : [
            SELECT Employee__c, Leave_Type__c
            FROM Leave_Balance__c
            WHERE Year__c = :nextYear
              AND Employee__c IN :userIdsInScope
              AND (Leave_Type__c = 'Paid Leave' OR Leave_Type__c = 'RTT')
        ]) {
            if (lb.Leave_Type__c == 'Paid Leave') {
                usersWithExistingPaidLeaveBalance.add(lb.Employee__c);
            } else if (lb.Leave_Type__c == 'RTT') {
                usersWithExistingRTTBalance.add(lb.Employee__c);
            }
        }

        Leave_Policy_Settings__c settings = Leave_Policy_Settings__c.getOrgDefaults();
        Decimal annualPaidLeaveDays = settings.Annual_Paid_Leave_Days__c != null ? settings.Annual_Paid_Leave_Days__c : 30;
        Decimal annualRTTDays = settings.Annual_RTT_Days__c != null ? settings.Annual_RTT_Days__c : 8;

        List<Leave_Balance__c> balancesToCreate = new List<Leave_Balance__c>();

        for (User u : userScope) {
            if (!usersWithExistingPaidLeaveBalance.contains(u.Id)) {
                balancesToCreate.add(new Leave_Balance__c(
                    Employee__c = u.Id,
                    Year__c = nextYear,
                    Leave_Type__c = 'Paid Leave',
                    Allocated_Days__c = annualPaidLeaveDays,
                    Used_Days__c = 0
                ));
            }

            if (!usersWithExistingRTTBalance.contains(u.Id)) {
                balancesToCreate.add(new Leave_Balance__c(
                    Employee__c = u.Id,
                    Year__c = nextYear,
                    Leave_Type__c = 'RTT',
                    Allocated_Days__c = annualRTTDays,
                    Used_Days__c = 0
                ));
            }
        }

        if (!balancesToCreate.isEmpty()) {
            insert balancesToCreate;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Paid Leave and RTT balance creation batch finished successfully.');
    }
}