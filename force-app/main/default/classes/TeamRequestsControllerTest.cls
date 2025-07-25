@isTest
private class TeamRequestsControllerTest {
    
    @TestSetup
    static void makeData() {
        User manager = TestDataFactory.createTestUser('manag', 'MA');
        User hrUser = TestDataFactory.createTestUser('hruser', 'HR');
        User teamMember = TestDataFactory.createTestUser('tmemb', 'MA');
        teamMember.ManagerId = manager.Id;
        update teamMember;
        
        Leave_Balance__c vacationBalance = TestDataFactory.createLeaveBalance(teamMember.Id, 'Vacation', 50);
        Leave_Balance__c rttBalance = TestDataFactory.createLeaveBalance(teamMember.Id, 'RTT', 10);
        
        Leave_Request__c pendingRequest1 = TestDataFactory.createLeaveRequest(
            teamMember.Id, 'Vacation', Date.today().addDays(10), Date.today().addDays(11), vacationBalance.Id
            );
        Leave_Request__c pendingRequest2 = TestDataFactory.createLeaveRequest(
            teamMember.Id, 'RTT', Date.today().addDays(12), Date.today().addDays(14), rttBalance.Id
            );
        Leave_Request__c pendingRequest3 = TestDataFactory.createLeaveRequest(
            teamMember.Id, 'RTT', Date.today().addDays(15), Date.today().addDays(18), rttBalance.Id
            );
        Leave_Request__c approvedRequest = TestDataFactory.createLeaveRequest(
            teamMember.Id, 'Vacation', Date.today().addDays(20), Date.today().addDays(21), vacationBalance.Id
            );
        approvedRequest.Status__c = 'Approved';
        pendingRequest1.Status__c = 'Submitted';
        pendingRequest2.Status__c = 'Submitted';
        pendingRequest3.Status__c = 'Submitted';
        
        Leave_Request__c vacation25DaysRequest = TestDataFactory.createLeaveRequest(
            teamMember.Id, 'Vacation', Date.today().addDays(30), Date.today().addDays(55), vacationBalance.Id
            );
        vacation25DaysRequest.Status__c = 'Submitted';
        
        insert new List<Leave_Request__c>{pendingRequest1, pendingRequest2,pendingRequest3, approvedRequest, vacation25DaysRequest};
    }
    
    @isTest
    static void testGetTeamRequests_Success() {
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        Test.startTest();
        System.runAs(manager) {
            List<Leave_Request__c> requests = TeamRequestsController.getTeamRequests();
            // Le manager doit voir les 4 demandes en attente de son approbation
            System.assertEquals(4, requests.size(), 'Should return 4 pending requests for the manager.');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetTeamRequests_NoTeam() {
        User teamMember = [SELECT Id FROM User WHERE Alias = 'tmemb' LIMIT 1];
        Test.startTest();
        System.runAs(teamMember) {
            List<Leave_Request__c> requests = TeamRequestsController.getTeamRequests();
            System.assertEquals(true, requests.isEmpty(), 'Should return an empty list for a user with no pending approvals.');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testApproveLeaveRequest_Success() {
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        Leave_Request__c request = [SELECT Id FROM Leave_Request__c WHERE Status__c != 'Approved' AND Leave_Type__c = 'Vacation' LIMIT 1];
        
        Test.startTest();
        System.runAs(manager) {
            TeamRequestsController.approveLeaveRequest(request.Id);
        }
        Test.stopTest();
        
        Leave_Request__c result = [SELECT Status__c FROM Leave_Request__c WHERE Id = :request.Id];
        System.assertEquals('Approved', result.Status__c, 'Status should be updated to Approved.');
    }
    
    @isTest
    static void testRejectLeaveRequest_Success() {
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        Leave_Request__c request = [SELECT Id FROM Leave_Request__c WHERE Status__c != 'Approved' AND Leave_Type__c = 'RTT' LIMIT 1];
        String reason = 'Blackout Period';
        String comment = 'Please reschedule.';
        
        Test.startTest();
        System.runAs(manager) {
            TeamRequestsController.rejectLeaveRequest(request.Id, reason, comment, false);
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
        Leave_Request__c request = [SELECT Id FROM Leave_Request__c WHERE Status__c != 'Approved' LIMIT 1];
        
        Test.startTest();
        System.runAs(manager) {
            try {
                TeamRequestsController.rejectLeaveRequest(request.Id, '', 'some comment', true);
                System.assert(false, 'An AuraHandledException should have been thrown for missing reason.');
            } catch (AuraHandledException e) {
                System.debug('Exception message: ' + e.getMessage());
                System.assert(true);
            }
        }
        Test.stopTest();
    }

    
    @isTest
    static void testApproveLeaveRequest_Error() {
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        
        String invalidId = Id.valueOf('001000000000000AAA');
        Test.startTest();
        System.runAs(manager) {
            try {
                TeamRequestsController.approveLeaveRequest(invalidId);
                System.assert(false, 'An AuraHandledException should have been thrown.');
            } catch (AuraHandledException e) {
                System.debug('Exception message: ' + e.getMessage());
                System.assert(true);
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testApproveLeaveRequest_Fails() {
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        User teamMember = [SELECT Id FROM User WHERE Alias = 'tmemb' LIMIT 1];
        
        Leave_Balance__c vacationBalance = TestDataFactory.createLeaveBalance(teamMember.Id, 'Vacation', 5);
        Leave_Request__c request = TestDataFactory.createLeaveRequest(
            teamMember.Id, 'Vacation', Date.today().addDays(70), Date.today().addDays(71), vacationBalance.Id
            );
        request.Status__c = 'Submitted';
        insert request;
        
        // Première approbation (fonctionne)
        Test.startTest();
        System.runAs(manager) {
            TeamRequestsController.approveLeaveRequest(request.Id);
        }
        Test.stopTest();
        
        // Deuxième approbation (échoue car plus de workitem "Pending")
        System.runAs(manager) {
            try {
                TeamRequestsController.approveLeaveRequest(request.Id);
                System.assert(false, 'Une exception aurait dû être levée car il n\'y a plus de workitem en attente.');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
    }
    
    @isTest
    static void testGetTeamRequests_FromQueue() {
        User hrUser = [SELECT Id FROM User WHERE Alias = 'hruser' LIMIT 1];
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        Group hrQueue = [SELECT Id FROM Group WHERE Name = 'HR Approvals' AND Type = 'Queue' LIMIT 1];
        
        GroupMember gm = new GroupMember(UserOrGroupId = hrUser.Id, GroupId = hrQueue.Id);
        insert gm;
        
        Leave_Request__c vacation25DaysRequest = [
            SELECT Id FROM Leave_Request__c 
            WHERE Status__c != 'Approved' AND Number_of_Days_Requested__c > 15 LIMIT 1
        ];
        
        Test.startTest();
        System.runAs(manager) {
            TeamRequestsController.approveLeaveRequest(vacation25DaysRequest.Id);
        }
        Test.stopTest();
        
        ProcessInstanceWorkitem hrWorkItem = [
            SELECT Id, ActorId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :vacation25DaysRequest.Id
            LIMIT 1
        ];
        System.assertEquals(hrQueue.Id, hrWorkItem.ActorId, 'Le workitem doit être assigné à la queue HR Approvals.');
        
        System.runAs(hrUser) {
            List<Leave_Request__c> requests = TeamRequestsController.getTeamRequests();
            System.assertEquals(1, requests.size(), 'HR user should see the request from the queue.');
        }
    }
    
    @isTest
    static void testApproveLeaveRequest_NotAssigned() {
        User otherManager = TestDataFactory.createTestUser('other', 'OM');
        
        User teamMember = [SELECT Id FROM User WHERE Alias = 'tmemb' LIMIT 1];
        Leave_Balance__c vacationBalance = TestDataFactory.createLeaveBalance(teamMember.Id, 'Vacation', 5);
        Leave_Request__c vacationRequest = TestDataFactory.createLeaveRequest(
            teamMember.Id, 'Vacation', Date.today().addDays(80), Date.today().addDays(81), vacationBalance.Id
            );
        vacationRequest.Status__c = 'Submitted';
        insert vacationRequest;
        
        Test.startTest();
        System.runAs(otherManager) {
            try {
                TeamRequestsController.approveLeaveRequest(vacationRequest.Id);
                System.assert(false, 'An exception should have been thrown for an unauthorized user.');
            } catch (AuraHandledException e) {
                System.debug('Exception message: ' + e.getMessage());
                System.assert(true);
            }
        }
        Test.stopTest();
    }
}