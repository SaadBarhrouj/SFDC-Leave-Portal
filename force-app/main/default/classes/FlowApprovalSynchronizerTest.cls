@isTest
private class FlowApprovalSynchronizerTest {

    @isTest
    static void testNullOrEmptyInput() {
        Test.startTest();
        FlowApprovalSynchronizer.syncApprovalTask(null);
        FlowApprovalSynchronizer.syncApprovalTask(new List<Id>());
        Test.stopTest();
        System.assert(true, 'No exception for null/empty input');
    }

    @isTest
    static void testNoApproverOnRequest() {
        User approver = TestDataFactory.createTestUser('approvr', 'US');
        User requester = TestDataFactory.createTestUser('requestr', 'US');
        String leaveType = 'RTT';
        Date startDate = Date.today().addDays(10);
        Date endDate = startDate.addDays(2);
        Leave_Request__c req = TestDataFactory.createLeaveRequest(requester.Id, leaveType, startDate, endDate, null);
        insert req;
        Test.startTest();
        FlowApprovalSynchronizer.syncApprovalTask(new List<Id>{req.Id});
        Test.stopTest();
        Leave_Request__c result = [SELECT Approver__c FROM Leave_Request__c WHERE Id = :req.Id];
        System.assertEquals(null, result.Approver__c, 'Approver should be null');
    }

    @isTest
    static void testNoWorkItemsToUpdate() {
        User approver = TestDataFactory.createTestUser('approver', 'US');
        String leaveType = 'RTT';
        Date startDate = Date.today().addDays(10);
        Date endDate = startDate.addDays(2);
        Leave_Request__c req = TestDataFactory.createLeaveRequest(approver.Id, leaveType, startDate, endDate, null);
        insert req;
        Test.startTest();
        FlowApprovalSynchronizer.syncApprovalTask(new List<Id>{req.Id});
        Test.stopTest();
        Integer count = [SELECT COUNT() FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId = :req.Id];
        System.assertEquals(0, count, 'No workitems should exist');
    }

    @isTest
    static void testUpdateWorkItems() {
        User manager = TestDataFactory.createTestUser('manager_', 'US');
        User newApprover = TestDataFactory.createTestUser('newappr', 'US');
        User requester = TestDataFactory.createTestUser('requestr', 'US');
        requester.ManagerId = manager.Id;
        update requester;
        
        String leaveType = 'Paid Leave';
        Date startDate = Date.today().addDays(10);
        Date endDate = startDate.addDays(2);
        Leave_Request__c req = TestDataFactory.createLeaveRequest(requester.Id, leaveType, startDate, endDate, null);
        insert req; 
        
        req = [SELECT Id, Approver__c FROM Leave_Request__c WHERE Id = :req.Id];
        System.assertEquals(manager.Id, req.Approver__c, 'Approver should be the manager');
        
        req.Status__c = 'Submitted';
        update req;

        req.Approver__c = newApprover.Id;
        update req;
        
        Test.startTest();
        FlowApprovalSynchronizer.syncApprovalTask(new List<Id>{req.Id});
        Test.stopTest();
        
        List<ProcessInstanceWorkitem> workitems = [SELECT Id, ActorId FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId = :req.Id AND ProcessInstance.Status = 'Pending'];
        System.assert(!workitems.isEmpty(), 'Workitem should exist for the request');
        System.assertEquals(newApprover.Id, workitems[0].ActorId, 'ActorId should be updated to new approver');
    }
}