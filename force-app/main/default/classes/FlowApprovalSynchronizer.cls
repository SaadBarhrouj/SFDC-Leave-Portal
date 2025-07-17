public class FlowApprovalSynchronizer {

    @InvocableMethod(label='Sync Approval Task' description='Reads the Approver__c field from a record and reassigns the pending approval task to match.')
    public static void syncApprovalTask(List<Id> leaveRequestIds) {
        
        if (leaveRequestIds == null || leaveRequestIds.isEmpty()) {
            return;
        }

        Map<Id, Id> newApproverMap = new Map<Id, Id>();
        for (Leave_Request__c req : [SELECT Id, Approver__c FROM Leave_Request__c WHERE Id IN :leaveRequestIds]) {
            if (req.Approver__c != null) {
                newApproverMap.put(req.Id, req.Approver__c);
            }
        }

        if (newApproverMap.isEmpty()) {
            return;
        }

        List<ProcessInstanceWorkitem> workItemsToUpdate = new List<ProcessInstanceWorkitem>();
        for (ProcessInstanceWorkitem workItem : [SELECT Id, ActorId, ProcessInstance.TargetObjectId 
                                                  FROM ProcessInstanceWorkitem 
                                                  WHERE ProcessInstance.TargetObjectId IN :newApproverMap.keySet() 
                                                    AND ProcessInstance.Status = 'Pending']) {
            
            Id newApproverId = newApproverMap.get(workItem.ProcessInstance.TargetObjectId);
            
            if (newApproverId != null) {
                workItem.ActorId = newApproverId;
                workItemsToUpdate.add(workItem);
            }
        }

        if (!workItemsToUpdate.isEmpty()) {
            try {
                update workItemsToUpdate;
            } catch (Exception e) {
                // Log the error in case something goes wrong, but don't stop the flow.
                System.debug('Error during approval task reassignment: ' + e.getMessage());
            }
        }
    }
}