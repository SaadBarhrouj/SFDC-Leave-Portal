@isTest
private class LeaveRequestControllerTest {

    @TestSetup
    static void makeData() {
        User manager = TestDataFactory.createTestUser('manager', 'US');
        User seniorManager = TestDataFactory.createTestUser('srmgr', 'US');
        manager.ManagerId = seniorManager.Id;
        update manager;

        User testUser = TestDataFactory.createTestUser('testu', 'US');
        testUser.ManagerId = manager.Id;
        update testUser;

        TestDataFactory.createLeaveBalance(testUser.Id, 'Paid Leave', 20);
        TestDataFactory.createLeaveBalance(testUser.Id, 'Sick Leave', 10);
    }

    private static User getTestUser() {
        return [SELECT Id, ManagerId, Work_Country__c FROM User WHERE Alias = 'testu' LIMIT 1];
    }

    @isTest
    static void testGetLeaveBalanceId_Success() {
        User testUser = getTestUser();
        Id balanceId = null;
        Test.startTest();
        System.runAs(testUser) {
            balanceId = LeaveRequestController.getLeaveBalanceId(testUser.Id, 'Paid Leave');
        }
        Test.stopTest();

        System.assertNotEquals(null, balanceId, 'Should return a valid balance Id.');
    }

    @isTest
    static void testGetLeaveBalanceId_NotFound() {
        User testUser = getTestUser();
        Exception expectedException = null;
        Test.startTest();
        System.runAs(testUser) {
            try {
                LeaveRequestController.getLeaveBalanceId(testUser.Id, 'Unpaid Leave');
            } catch (AuraHandledException e) {
                expectedException = e;
            }
        }
        Test.stopTest();

        System.assertNotEquals(null, expectedException, 'An AuraHandledException should have been thrown.');
    }

    @isTest
    static void testGetMyLeaves() {
        User testUser = getTestUser();
        TestDataFactory.createLeaveRequest(testUser.Id, 'Paid Leave', Date.today().addDays(10), Date.today().addDays(11), null, 'Approved');

        List<Leave_Request__c> myLeaves;
        Test.startTest();
        System.runAs(testUser) {
            myLeaves = LeaveRequestController.getMyLeaves();
        }
        Test.stopTest();

        System.assertNotEquals(null, myLeaves);
        System.assertEquals(1, myLeaves.size(), 'Should return one leave request.');
    }
    
    @isTest
    static void testGetMyLeavesForCalendar() {
        User testUser = getTestUser();
        TestDataFactory.createLeaveRequest(testUser.Id, 'Paid Leave', Date.today().addDays(15), Date.today().addDays(16), null, 'Approved');

        List<Leave_Request__c> myLeaves;
        Test.startTest();
        System.runAs(testUser) {
            myLeaves = LeaveRequestController.getMyLeavesForCalendar();
        }
        Test.stopTest();

        System.assertNotEquals(null, myLeaves);
        System.assertEquals(1, myLeaves.size(), 'Should return one leave request for the calendar.');
    }
    
    @isTest
    static void testGetNumberOfDaysRequested_InvalidDates() {
        User testUser = getTestUser();
        Decimal daysRequested;
        Test.startTest();
        System.runAs(testUser) {
            daysRequested = LeaveRequestController.getNumberOfDaysRequested(Date.today(), null);
        }
        Test.stopTest();
        System.assertEquals(0, daysRequested, 'Should be 0 for null dates.');
    }

    @isTest
    static void testCancelLeaveRequest_Submitted() {
        User testUser = getTestUser();
        Leave_Request__c req = TestDataFactory.createLeaveRequest(testUser.Id, 'Paid Leave', Date.today().addDays(20), Date.today().addDays(21), null, 'Submitted');

        Test.startTest();
        String result = LeaveRequestController.cancelLeaveRequest(req.Id);
        Test.stopTest();
        
        System.assertEquals('The leave request has been successfully cancelled.', result);
        Leave_Request__c cancelledReq = [SELECT Status__c FROM Leave_Request__c WHERE Id = :req.Id];
        System.assertEquals('Cancelled', cancelledReq.Status__c, 'Status should be Cancelled.');
    }

    @isTest
    static void testCancelLeaveRequest_PendingApproval() {
        User testUser = getTestUser();
        Leave_Request__c req = TestDataFactory.createLeaveRequest(testUser.Id, 'Paid Leave', Date.today().addDays(30), Date.today().addDays(31), null, 'Submitted');

        Test.startTest();
        String result = LeaveRequestController.cancelLeaveRequest(req.Id);
        Test.stopTest();

        System.assertEquals('The leave request has been successfully cancelled.', result);
        Leave_Request__c cancelledReq = [SELECT Status__c FROM Leave_Request__c WHERE Id = :req.Id];
        System.assertEquals('Cancelled', cancelledReq.Status__c, 'Status should be Cancelled after recall.');
    }

    @isTest
    static void testCancelLeaveRequest_InvalidStatus() {
        User testUser = getTestUser();
        Leave_Request__c req = TestDataFactory.createLeaveRequest(testUser.Id, 'Paid Leave', Date.today().addDays(40), Date.today().addDays(41), null, 'Approved');
        
        Exception expectedException = null;
        Test.startTest();
        try {
            LeaveRequestController.cancelLeaveRequest(req.Id);
        } catch (AuraHandledException e) {
            expectedException = e;
        }
        Test.stopTest();

        System.assertNotEquals(null, expectedException, 'An exception should be thrown for non-cancellable status.');
    }

    @isTest
    static void testRequestCancellation_Success() {
        User testUser = getTestUser();
        Leave_Request__c req = TestDataFactory.createLeaveRequest(testUser.Id, 'Paid Leave', Date.today().addDays(50), Date.today().addDays(51), null, 'Approved');
        
        req.Last_Approver__c = testUser.ManagerId;
        update req;

        Test.startTest();
        System.runAs(testUser) {
            LeaveRequestController.requestCancellation(req.Id);
        }
        Test.stopTest();

        Leave_Request__c updatedReq = [SELECT Status__c FROM Leave_Request__c WHERE Id = :req.Id];
        System.assertEquals('Cancellation Requested', updatedReq.Status__c, 'Status should be Cancellation Requested.');
    }

    @isTest
    static void testRequestCancellation_InvalidStatus() {
        User testUser = getTestUser();
        Leave_Request__c req = TestDataFactory.createLeaveRequest(testUser.Id, 'Paid Leave', Date.today().addDays(60), Date.today().addDays(61), null, 'Submitted');

        Exception expectedException = null;
        Test.startTest();
        try {
            LeaveRequestController.requestCancellation(req.Id);
        } catch (AuraHandledException e) {
            expectedException = e;
        }
        Test.stopTest();

        System.assertNotEquals(null, expectedException, 'An exception should be thrown for non-approved status.');
    }

    @isTest
    static void testWithdrawCancellationRequest() {
        User testUser = getTestUser();
        Leave_Request__c req = TestDataFactory.createLeaveRequest(testUser.Id, 'Paid Leave', Date.today().addDays(70), Date.today().addDays(71), null, 'Cancellation Requested');
        req.Last_Approver__c = testUser.ManagerId;
        update req;

        Test.startTest();
        LeaveRequestController.withdrawCancellationRequest(req.Id);
        Test.stopTest();

        Leave_Request__c updatedReq = [SELECT Status__c FROM Leave_Request__c WHERE Id = :req.Id];
        System.assertEquals('Approved', updatedReq.Status__c, 'Status should be reverted to Approved.');
    }
    
    @isTest
    static void testWithdrawCancellationRequest_InvalidStatus() {
        User testUser = getTestUser();
        Leave_Request__c req = TestDataFactory.createLeaveRequest(testUser.Id, 'Paid Leave', Date.today().addDays(80), Date.today().addDays(81), null, 'Approved');
        
        Exception expectedException = null;
        Test.startTest();
        try {
            LeaveRequestController.withdrawCancellationRequest(req.Id);
        } catch (AuraHandledException e) {
            expectedException = e;
        }
        Test.stopTest();
        
        System.assertNotEquals(null, expectedException, 'An exception should be thrown for invalid status.');
    }

    @isTest
    static void testGetAbsentEmployees() {
        User testUser = getTestUser();
        // Use a date range that includes today
        TestDataFactory.createLeaveRequest(testUser.Id, 'Sick Leave', Date.today().addDays(-1), Date.today().addDays(1), null, 'Approved');

        List<Leave_Request__c> absentEmployees;
        Test.startTest();
        System.runAs(testUser) {
            absentEmployees = LeaveRequestController.getAbsentEmployees();
        }
        Test.stopTest();

        System.assertNotEquals(null, absentEmployees);
        System.assertEquals(1, absentEmployees.size(), 'Should return one absent employee.');
    }

    @isTest
    static void testRecallAndUpdate() {
        User testUser = getTestUser();
        Leave_Request__c req = TestDataFactory.createLeaveRequest(testUser.Id, 'Paid Leave', Date.today().addDays(90), Date.today().addDays(91), null, 'Submitted');

        Date newStartDate = Date.today().addDays(95);
        Date newEndDate = Date.today().addDays(96);
        String newComments = 'Updated comments';

        Test.startTest();
        String result = LeaveRequestController.recallAndUpdate(req.Id, newStartDate, newEndDate, newComments);
        Test.stopTest();
        
        System.assertEquals('Request updated. Resubmission initiated.', result);

        Leave_Request__c updatedReq = [SELECT Start_Date__c, End_Date__c, Employee_Comments__c, Status__c FROM Leave_Request__c WHERE Id = :req.Id];
        System.assertEquals(newStartDate, updatedReq.Start_Date__c);
        System.assertEquals(newEndDate, updatedReq.End_Date__c);
        System.assertEquals(newComments, updatedReq.Employee_Comments__c);
    }
    
    @isTest
    static void testRecallAndUpdate_Exception() {
        Exception expectedException = null;
        Test.startTest();
        try {
            // Pass an invalid Id
            LeaveRequestController.recallAndUpdate('001000000000000', Date.today(), Date.today(), 'test');
        } catch (AuraHandledException e) {
            expectedException = e;
        }
        Test.stopTest();
        
        System.assertNotEquals(null, expectedException, 'An exception should be thrown for an invalid Id.');
    }
}