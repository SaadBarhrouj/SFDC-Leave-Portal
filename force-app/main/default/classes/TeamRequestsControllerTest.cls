@isTest
private class TeamRequestsControllerTest {
    
    @TestSetup
    static void makeData() {
        User manager = TestDataFactory.createTestUser('manag', 'MA');
        User teamMember1 = TestDataFactory.createTestUser('tmemb1', 'MA');
        teamMember1.ManagerId = manager.Id;
        User teamMember2 = TestDataFactory.createTestUser('tmemb2', 'MA');
        teamMember2.ManagerId = manager.Id;
        update new List<User>{teamMember1, teamMember2};

        List<PermissionSetGroup> psgs = [
            SELECT Id, DeveloperName 
            FROM PermissionSetGroup 
            WHERE DeveloperName IN ('PSG_LeavePortal_Manager', 'PSG_LeavePortal_Employee')
        ];
        
        Map<String, Id> psgMap = new Map<String, Id>();
        for (PermissionSetGroup psg : psgs) {
            psgMap.put(psg.DeveloperName, psg.Id);
        }

        if (!psgMap.isEmpty()) {
            System.Test.calculatePermissionSetGroup(psgMap.values());
        }

        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        assignments.add(new PermissionSetAssignment(
            AssigneeId = manager.Id,
            PermissionSetGroupId = psgMap.get('PSG_LeavePortal_Manager')
        ));
        assignments.add(new PermissionSetAssignment(
            AssigneeId = teamMember1.Id,
            PermissionSetGroupId = psgMap.get('PSG_LeavePortal_Employee')
        ));
        assignments.add(new PermissionSetAssignment(
            AssigneeId = teamMember2.Id,
            PermissionSetGroupId = psgMap.get('PSG_LeavePortal_Employee')
        ));
        
        insert assignments;
    }
    
    private static void createBalances() {
        User teamMember1 = [SELECT Id FROM User WHERE Alias = 'tmemb1' LIMIT 1];
        User teamMember2 = [SELECT Id FROM User WHERE Alias = 'tmemb2' LIMIT 1];
        TestDataFactory.createLeaveBalance(teamMember1.Id, 'Paid Leave', 20);
        TestDataFactory.createLeaveBalance(teamMember2.Id, 'Paid Leave', 20);
    }

    @isTest
    static void testGetApprovedLeavesByManager() {
        createBalances();
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        User teamMember1 = [SELECT Id FROM User WHERE Alias = 'tmemb1' LIMIT 1];
        TestDataFactory.createLeaveRequest(teamMember1.Id, 'Paid Leave', Date.today().addDays(20), Date.today().addDays(21), null, 'Approved');
        
        List<Leave_Request__c> approvedLeaves = TeamRequestsController.getApprovedLeavesByManager(manager.Id);
        System.assertEquals(1, approvedLeaves.size(), 'Should return one approved leave request.');
        
        List<Leave_Request__c> noLeaves = TeamRequestsController.getApprovedLeavesByManager(null);
        System.assertEquals(0, noLeaves.size(), 'Should return an empty list for a null manager Id.');
    }
    
    @isTest
    static void testGetTeamRequestsHistory() {
        createBalances();
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        User teamMember = [SELECT Id FROM User WHERE Alias = 'tmemb1' LIMIT 1];
        
        TestDataFactory.createLeaveRequest(teamMember.Id, 'Paid Leave', Date.today().addDays(20), Date.today().addDays(21), null, 'Approved');
        TestDataFactory.createLeaveRequest(teamMember.Id, 'Paid Leave', Date.today().addDays(30), Date.today().addDays(31), null, 'Rejected');
        TestDataFactory.createLeaveRequest(teamMember.Id, 'Paid Leave', Date.today().addDays(40), Date.today().addDays(41), null, 'Cancellation Requested');

        System.runAs(manager) {
            List<Leave_Request__c> history = TeamRequestsController.getTeamRequestsHistory();
            System.assertEquals(3, history.size(), 'Manager should see 3 historical requests (Approved, Rejected, Cancellation Requested).');
        }
        
        System.runAs(teamMember) {
            List<Leave_Request__c> history = TeamRequestsController.getTeamRequestsHistory();
            System.assertEquals(0, history.size(), 'User with no team should see no history.');
        }
    }
    
    @isTest
    static void testGetTeamRequests() {
        createBalances();
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        User teamMember = [SELECT Id FROM User WHERE Alias = 'tmemb1' LIMIT 1];
        
        Test.startTest();
        Leave_Request__c req = TestDataFactory.createLeaveRequest(
            teamMember.Id, 'Paid Leave', Date.today().addDays(60), Date.today().addDays(61), null, 'Submitted'
        );
        Test.stopTest();
            
        System.runAs(manager) {
            List<Leave_Request__c> pending = TeamRequestsController.getTeamRequests();
            System.assertEquals(1, pending.size(), 'Manager should see 1 pending request.');
        }
        
        System.runAs(teamMember) {
            List<Leave_Request__c> pending = TeamRequestsController.getTeamRequests();
            System.assertEquals(0, pending.size(), 'User with no assigned items should see none.');
        }
    }
    
    @isTest
    static void testGetTeamLeavesForRequester() {
        createBalances();
        User teamMember1 = [SELECT Id FROM User WHERE Alias = 'tmemb1' LIMIT 1];
        User teamMember2 = [SELECT Id FROM User WHERE Alias = 'tmemb2' LIMIT 1];
        User userNoManager = TestDataFactory.createTestUser('nomgr', 'MA');
        
        TestDataFactory.createLeaveRequest(teamMember1.Id, 'Paid Leave', Date.today().addDays(20), Date.today().addDays(21), null, 'Approved');
        TestDataFactory.createLeaveRequest(teamMember1.Id, 'Paid Leave', Date.today().addDays(40), Date.today().addDays(41), null, 'Cancellation Requested');

        List<Leave_Request__c> teamLeaves = TeamRequestsController.getTeamLeavesForRequester(teamMember2.Id);
        System.assertEquals(2, teamLeaves.size(), 'Should return Approved and Cancellation Requested leaves for the team.');
        
        List<Leave_Request__c> noTeamLeaves = TeamRequestsController.getTeamLeavesForRequester(userNoManager.Id);
        System.assertEquals(0, noTeamLeaves.size(), 'Should return empty list for user with no manager.');
    }
    
    @isTest
    static void testApproveLeaveRequest() {
        createBalances();
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        User requester = [SELECT Id FROM User WHERE Alias = 'tmemb1' LIMIT 1];
        
        Leave_Request__c toApprove = new Leave_Request__c(
            Requester__c = requester.Id,
            Leave_Type__c = 'Paid Leave',
            Start_Date__c = Date.today().addDays(70),
            End_Date__c = Date.today().addDays(71),
            Status__c = 'Submitted'
        );
        
        Test.startTest();
        insert toApprove;
        System.runAs(manager) {
            TeamRequestsController.approveLeaveRequest(toApprove.Id);
        }
        Test.stopTest();
        
        Leave_Request__c approvedReq = [SELECT Id, Status__c, Last_Approver__c FROM Leave_Request__c WHERE Id = :toApprove.Id];
        System.assertEquals('Approved', approvedReq.Status__c, 'Status should be Approved.');
        System.assertEquals(manager.Id, approvedReq.Last_Approver__c, 'Last Approver should be the manager.');
    }

    @isTest
    static void testRejectLeaveRequest() {
        createBalances();
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        User requester = [SELECT Id FROM User WHERE Alias = 'tmemb1' LIMIT 1];

        Leave_Request__c reqToReject = new Leave_Request__c(
            Requester__c = requester.Id,
            Leave_Type__c = 'Paid Leave',
            Start_Date__c = Date.today().addDays(80),
            End_Date__c = Date.today().addDays(81),
            Status__c = 'Submitted'
        );
        
        Test.startTest();
        insert reqToReject;
        System.runAs(manager) {
            TeamRequestsController.rejectLeaveRequest(reqToReject.Id, 'Other', 'A Comment', false);
        }
        Test.stopTest();
        
        Leave_Request__c rejectedReq = [SELECT Status__c, Rejection_Reason__c, Approver_Comments__c FROM Leave_Request__c WHERE Id = :reqToReject.Id];
        System.assertEquals('Rejected', rejectedReq.Status__c, 'Status should be Rejected.');
        System.assertEquals('Other', rejectedReq.Rejection_Reason__c, 'Rejection reason should be set.');
        System.assertEquals('A Comment', rejectedReq.Approver_Comments__c, 'Approver comment should be set.');
    }
    
    @isTest
    static void testRejectLeaveRequest_ReasonRequired() {
        createBalances();
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        User requester = [SELECT Id FROM User WHERE Alias = 'tmemb1' LIMIT 1];
        
        Leave_Request__c pendingReq = new Leave_Request__c(
            Requester__c = requester.Id,
            Leave_Type__c = 'Paid Leave',
            Start_Date__c = Date.today().addDays(90),
            End_Date__c = Date.today().addDays(91),
            Status__c = 'Submitted'
        );
        
        Exception caughtException = null;
        Test.startTest();
        insert pendingReq;
        System.runAs(manager) {
            try {
                TeamRequestsController.rejectLeaveRequest(pendingReq.Id, '', 'A Comment', true);
            } catch (AuraHandledException e) {
                caughtException = e;
            }
        }
        Test.stopTest();
        
        System.assertNotEquals(null, caughtException, 'An exception should be thrown when reason is required but blank.');
    }
    
    @isTest
    static void testProcessRequest_NoWorkItemFound() {
        createBalances();
        User manager = [SELECT Id FROM User WHERE Alias = 'manag' LIMIT 1];
        User teamMember1 = [SELECT Id FROM User WHERE Alias = 'tmemb1' LIMIT 1];
        Leave_Request__c approvedReq = TestDataFactory.createLeaveRequest(teamMember1.Id, 'Paid Leave', Date.today().addDays(20), Date.today().addDays(21), null, 'Approved');
        
        Exception caughtException = null;
        Test.startTest();
        System.runAs(manager) {
            try {
                TeamRequestsController.approveLeaveRequest(approvedReq.Id);
            } catch (AuraHandledException e) {
                caughtException = e;
            }
        }
        Test.stopTest();
        
        System.assertNotEquals(null, caughtException, 'An exception should be thrown for a request with no pending work item.');
    }
}