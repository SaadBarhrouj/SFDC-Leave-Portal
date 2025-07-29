public class AnnualLeaveBalanceBatch implements Database.Batchable<sObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id FROM User WHERE IsActive = true]);
    }

    public void execute(Database.BatchableContext bc, List<User> userScope) {
        
        Integer nextYear = Date.today().year() + 1;
        Set<Id> userIdsInScope = new Map<Id, User>(userScope).keySet();

        Set<Id> usersWithExistingBalance = new Set<Id>();
        for (Leave_Balance__c lb : [
            SELECT Employee__c 
            FROM Leave_Balance__c 
            WHERE Year__c = :nextYear 
              AND Employee__c IN :userIdsInScope
              AND Leave_Type__c = 'Paid Leave'  
        ]) {
            usersWithExistingBalance.add(lb.Employee__c);
        }
        
        Leave_Policy_Settings__c settings = Leave_Policy_Settings__c.getOrgDefaults();
        Decimal annualLeaveDays = settings.Annual_Paid_Leave_Days__c != null ? settings.Annual_Paid_Leave_Days__c : 30;
        
        List<Leave_Balance__c> balancesToCreate = new List<Leave_Balance__c>();

        for (User u : userScope) {
            if (!usersWithExistingBalance.contains(u.Id)) {
                balancesToCreate.add(new Leave_Balance__c(
                    Employee__c = u.Id, 
                    Year__c = nextYear, 
                    Leave_Type__c = 'Paid Leave',
                    Allocated_Days__c = annualLeaveDays, 
                    Used_Days__c = 0
                ));
            }
        }
        
        if (!balancesToCreate.isEmpty()) {
            insert balancesToCreate;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Paid Leave balance creation batch finished successfully.');
    }
}