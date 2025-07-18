trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
    Set<Id> leaveRequestIds = new Set<Id>();
    String leaveRequestPrefix = Leave_Request__c.SObjectType.getDescribe().getKeyPrefix();

    for (ContentDocumentLink cdl : Trigger.new) {
        if (cdl.LinkedEntityId != null && String.valueOf(cdl.LinkedEntityId).startsWith(leaveRequestPrefix)) {
            leaveRequestIds.add(cdl.LinkedEntityId);
        }
    }
    if (!leaveRequestIds.isEmpty()) {
        List<Leave_Request__c> requests = [SELECT Id, Supporting_Document_Received__c FROM Leave_Request__c WHERE Id IN :leaveRequestIds];
        for (Leave_Request__c req : requests) {
            req.Supporting_Document_Received__c = true;
        }
        update requests;
    }
}