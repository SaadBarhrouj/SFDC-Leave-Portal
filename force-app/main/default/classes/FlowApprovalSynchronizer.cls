public without sharing class FlowApprovalSynchronizer {

    @InvocableMethod(label='Escalate and Sync Approval' description='Escalates a leave request to N+2 and reassigns the approval task.')
    public static void escalateAndSyncApproval(List<Id> leaveRequestIds) {
        
        if (leaveRequestIds == null || leaveRequestIds.isEmpty()) {
            return;
        }

        List<Leave_Request__c> requestsToUpdate = new List<Leave_Request__c>();
        for (Leave_Request__c req : [
            SELECT Id, Approver__c, Approver__r.ManagerId 
            FROM Leave_Request__c 
            WHERE Id IN :leaveRequestIds 
              AND Status__c = 'Pending Manager Approval' 
        ]) {

            if (req.Approver__r.ManagerId != null) {
                req.Approver__c = req.Approver__r.ManagerId;
                req.Status__c = 'Escalated to Senior Manager';
                requestsToUpdate.add(req);
            }

        }


        update requestsToUpdate;

        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id 
            FROM ProcessInstanceWorkitem 
            WHERE ProcessInstance.TargetObjectId IN :leaveRequestIds 
              AND ProcessInstance.Status = 'Pending'
        ];

        if (workItems.isEmpty()) {
            resubmitRequests(leaveRequestIds);
            return;
        }

        List<Approval.ProcessWorkitemRequest> recallRequests = new List<Approval.ProcessWorkitemRequest>();
        for(ProcessInstanceWorkitem workItem : workItems) {
            Approval.ProcessWorkitemRequest pwr = new Approval.ProcessWorkitemRequest();
            pwr.setWorkitemId(workItem.Id);
            pwr.setAction('Removed');
            recallRequests.add(pwr);
        }

        try {
            Approval.process(recallRequests, false);
            resubmitRequests(leaveRequestIds);
        } catch (Exception e) {
            System.debug('Error recalling/resubmitting approval process: ' + e.getMessage());
        }
    }

    private static void resubmitRequests(List<Id> requestIds) {
        List<Approval.ProcessSubmitRequest> submitRequests = new List<Approval.ProcessSubmitRequest>();
        for (Id requestId : requestIds) {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(requestId);
            submitRequests.add(req);
        }

        try {
            Approval.process(submitRequests, false);
        } catch (Exception e) {
            System.debug('Error resubmitting requests for approval: ' + e.getMessage());
        }
    }
}