@isTest
public class FlowApprovalSynchronizerTest {


    @isTest
    static void testEscalateAndSyncApproval_NoManagerId() {
        User manager = TestDataFactory.createTestUser('manag2', 'FR');
        update manager;

        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(manager.Id, 'Paid Leave', 10);

        Leave_Request__c req = TestDataFactory.createLeaveRequest(
            manager.Id, 'Paid Leave', Date.today().addDays(1), Date.today().addDays(2), balance.Id, 'Pending Manager Approval'
        );
        req.Approver__c = manager.Id;
        update req;

        Approval.ProcessSubmitRequest submitReq = new Approval.ProcessSubmitRequest();
        submitReq.setObjectId(req.Id);
        Approval.process(submitReq);

        Test.startTest();
        FlowApprovalSynchronizer.escalateAndSyncApproval(new List<Id>{ req.Id });
        Test.stopTest();

        Leave_Request__c updated = [SELECT Approver__c, Status__c FROM Leave_Request__c WHERE Id = :req.Id];
        System.assertEquals(manager.Id, updated.Approver__c, 'Approver should remain the same');
        System.assertEquals('Pending HR Approval', updated.Status__c, 'Status should remain the same');
    }


    @isTest
    static void testEscalateAndSyncApproval_EmptyList() {
        Test.startTest();
        FlowApprovalSynchronizer.escalateAndSyncApproval(new List<Id>());
        Test.stopTest();
        System.assert(true, 'No error with empty list');
    }

    @isTest
    static void testEscalateAndSyncApproval_NullList() {
        Test.startTest();
        FlowApprovalSynchronizer.escalateAndSyncApproval(null);
        Test.stopTest();
        System.assert(true, 'No error with null list');
    }

    @isTest
    static void testEscalateAndSyncApproval_EscalationLogicOnly() {
        User manager = TestDataFactory.createTestUser('manag', 'FR');
        User n2Manager = TestDataFactory.createTestUser('n2man', 'FR');
        manager.ManagerId = n2Manager.Id;
        update manager;

        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(manager.Id, 'Paid Leave', 10);

        Leave_Request__c req = TestDataFactory.createLeaveRequest(
            manager.Id, 'Paid Leave', Date.today().addDays(1), Date.today().addDays(2), balance.Id, 'Pending Manager Approval'
        );
        req.Approver__c = manager.Id; 
        update req;

        Test.startTest();
        FlowApprovalSynchronizer.escalateAndSyncApproval(new List<Id>{ req.Id });
        Test.stopTest();

        Leave_Request__c updated = [SELECT Approver__c, Status__c FROM Leave_Request__c WHERE Id = :req.Id];
        System.assertEquals(n2Manager.Id, updated.Approver__c, 'Approver should be N+2');
        System.assertEquals('Escalated to Senior Manager', updated.Status__c, 'Status should be escalated');
    }
}