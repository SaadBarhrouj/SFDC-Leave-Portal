@isTest
private class TeamRequestsControllerTest {

    @TestSetup
    static void makeData() {
        User manager = TestDataFactory.createTestUser('manag', 'MA');
        User teamMember = TestDataFactory.createTestUser('tmemb', 'MA');
        teamMember.ManagerId = manager.Id;
        update teamMember;

        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(teamMember.Id, 'Vacation', 20);

        Leave_Request__c pendingRequest1 = TestDataFactory.createLeaveRequest(
            teamMember.Id, 
            'Vacation', 
            Date.today(), 
            Date.today().addDays(1), 
            balance.Id
        );
        pendingRequest1.Status__c = 'Pending Manager Approval';

        Leave_Request__c pendingRequest2 = TestDataFactory.createLeaveRequest(
            teamMember.Id, 
            'RTT', 
            Date.today(), 
            Date.today().addDays(2), 
            balance.Id
        );
        pendingRequest2.Status__c = 'Pending Manager Approval';
        
        Leave_Request__c approvedRequest = TestDataFactory.createLeaveRequest(
            teamMember.Id, 
            'Vacation', 
            Date.today().addDays(10), 
            Date.today().addDays(11), 
            balance.Id
        );
        approvedRequest.Status__c = 'Approved';

        insert new List<Leave_Request__c>{pendingRequest1, pendingRequest2, approvedRequest};
        
    }

    @isTest
    static void testGetTeamRequests_Success() {
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        Test.startTest();
        System.runAs(manager) {
            List<Leave_Request__c> requests = TeamRequestsController.getTeamRequests();
            System.assertEquals(3, requests.size(), 'Should only return two pending request.');
            System.assertEquals('Pending Manager Approval', requests[0].Status__c, 'Status should be Pending Manager Approval.');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetTeamRequests_NoTeam() {
        User teamMember = [SELECT Id FROM User WHERE Alias = 'tmemb' LIMIT 1];
        Test.startTest();
        System.runAs(teamMember) {
            List<Leave_Request__c> requests = TeamRequestsController.getTeamRequests();
            System.assertEquals(true, requests.isEmpty(), 'Should return an empty list for a user with no team.');
        }
        Test.stopTest();
    }

    @isTest
    static void testApproveLeaveRequest_Success() {
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        Leave_Request__c request = [SELECT Id FROM Leave_Request__c WHERE Status__c = 'Pending Manager Approval' LIMIT 1];

        Test.startTest();
        System.runAs(manager) {
            TeamRequestsController.approveLeaveRequest(request.Id);
        }
        Test.stopTest();

        Leave_Request__c result = [SELECT Status__c FROM Leave_Request__c WHERE Id = :request.Id];
        System.assertEquals('Approved', result.Status__c, 'Status should be updated to Approved.');
    }

    @isTest
    static void testApproveLeaveRequest_Error() {
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        Test.startTest();
        System.runAs(manager) {
            try {
                TeamRequestsController.approveLeaveRequest('invalidId');
                System.assert(false, 'An AuraHandledException should have been thrown.');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
        Test.stopTest();
    }

    @isTest
    static void testRejectLeaveRequest_Success() {
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        Leave_Request__c request = [SELECT Id FROM Leave_Request__c WHERE Status__c = 'Pending Manager Approval' LIMIT 1];
        String reason = 'Blackout Period';
        String comment = 'Please reschedule.';

        Test.startTest();
        System.runAs(manager) {
            TeamRequestsController.rejectLeaveRequest(request.Id, reason, comment);
        }
        Test.stopTest();

        Leave_Request__c result = [SELECT Status__c, Rejection_Reason__c, Approver_Comments__c FROM Leave_Request__c WHERE Id = :request.Id];
        System.assertEquals('Rejected', result.Status__c, 'Status should be updated to Rejected.');
        System.assertEquals(reason, result.Rejection_Reason__c, 'Rejection reason should be updated.');
        System.assertEquals(comment, result.Approver_Comments__c, 'Approver comment should be updated.');
    }

    @isTest
    static void testRejectLeaveRequest_NoReason() {
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        Leave_Request__c request = [SELECT Id FROM Leave_Request__c WHERE Status__c = 'Pending Manager Approval' LIMIT 1];

        Test.startTest();
        System.runAs(manager) {
            try {
                TeamRequestsController.rejectLeaveRequest(request.Id, '', 'some comment');
                System.assert(false, 'An AuraHandledException should have been thrown.');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
        Test.stopTest();
    }

    @isTest
    static void testRejectLeaveRequest_Error() {
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        Test.startTest();
        System.runAs(manager) {
            try {
                TeamRequestsController.rejectLeaveRequest('invalidId', 'reason', 'comment');
                System.assert(false, 'An AuraHandledException should have been thrown.');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
        Test.stopTest();
    }
}
