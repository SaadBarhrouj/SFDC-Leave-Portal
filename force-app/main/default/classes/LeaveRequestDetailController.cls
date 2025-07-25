public with sharing class LeaveRequestDetailController {
    @AuraEnabled(cacheable=true)
    public static Leave_Request__c getLeaveRequestDetails(Id recordId, Long refresh) {
        if (recordId == null) {
            return null;
        }
        return [
            SELECT
                Id, Name, Status__c, Leave_Type__c, Start_Date__c, End_Date__c,
                Number_of_Days_Requested__c, Employee_Comments__c,
                Approver_Comments__c, Rejection_Reason__c,
                Requester__c, Requester__r.Name,
                Leave_Balance__r.Used_Days__c,
                Leave_Balance__r.Remaining_Days__c,
                Leave_Balance__r.Leave_Type__c
            FROM Leave_Request__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ContentDocument> getRelatedFiles(Id recordId, Long refresh) {
        if (recordId == null) {
            return new List<ContentDocument>();
        }
        
        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId
        ]) {
            contentDocumentIds.add(cdl.ContentDocumentId);
        }
        
        if (contentDocumentIds.isEmpty()) {
            return new List<ContentDocument>();
        }
        
        return [
            SELECT Id, Title, FileExtension, FileType 
            FROM ContentDocument 
            WHERE Id IN :contentDocumentIds
        ];
    }
    
    @AuraEnabled
    public static void deleteRelatedFile(Id contentDocumentId, Id recordId) {
        List<ContentDocumentLink> links = [
        SELECT Id FROM ContentDocumentLink
        WHERE ContentDocumentId = :contentDocumentId AND LinkedEntityId = :recordId
    ];
        delete links;
    }
}