public class CancelPastLeaveRequestsBatch implements Database.Batchable<sObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Status__c FROM Leave_Request__c ' +
                       'WHERE Start_Date__c < TODAY ' +
                       'AND Leave_Type__c != \'Sick Leave\' ' +
                       'AND Status__c NOT IN (\'Cancelled\', \'Rejected\', \'Approved\')'; 

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Leave_Request__c> scope) {
        List<Leave_Request__c> requestsToUpdate = new List<Leave_Request__c>();
        
        for (Leave_Request__c req : scope) {
            
            if (req.Status__c == 'Cancellation Requested') {
                req.Status__c = 'Approved';
                requestsToUpdate.add(req);
            }else {
                req.Status__c = 'Cancelled'; 
                requestsToUpdate.add(req);
            }
        }
        
        if (!requestsToUpdate.isEmpty()) {
            update requestsToUpdate;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Batch to clean up past leave requests completed.');
    }
}