public with sharing class LeaveRequestController {
    
    @AuraEnabled
    public static Id getLeaveBalanceId(Id employeeId, String leaveType) {
        try {
            Leave_Balance__c balance = [
                SELECT Id
                FROM Leave_Balance__c
                WHERE Employee__c = :employeeId
                AND Leave_Type__c = :leaveType
                AND Year__c = :Date.today().year()
                LIMIT 1
            ];
            return balance.Id;
        } catch (Exception e) {
            throw new AuraHandledException('No leave balance found for ' + leaveType + ' for this year');
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getMyLeaves() {
        try {
            return [
                SELECT Id, Name, Leave_Type__c, Start_Date__c, End_Date__c, 
                       Number_of_Days_Requested__c, Status__c, Employee_Comments__c,
                       Approver_Comments__c, Rejection_Reason__c, CreatedDate,
                       Requester__r.Name, Leave_Balance__r.Leave_Type__c
                FROM Leave_Request__c
                WHERE Requester__c = :UserInfo.getUserId()
                ORDER BY CreatedDate DESC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving leave requests: ' + e.getMessage());
        }
    }
}
