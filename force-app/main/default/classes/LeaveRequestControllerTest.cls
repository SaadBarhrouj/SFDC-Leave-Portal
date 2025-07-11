@isTest
private class LeaveRequestControllerTest {

    @isTest
    static void testGetLeaveBalanceId_Success() {
        User testUser = TestDataFactory.createTestUser('testuser', 'US');
        Leave_Balance__c leaveBalance = TestDataFactory.createLeaveBalance(testUser.Id, 'Vacation', 20);

        Test.startTest();
        Id balanceId = LeaveRequestController.getLeaveBalanceId(testUser.Id, 'Vacation');
        Test.stopTest();

        System.assertEquals(leaveBalance.Id, balanceId, 'Leave balance ID should match the created record.');
    }

    @isTest
    static void testGetLeaveBalanceId_NotFound() {
     
        User testUser = TestDataFactory.createTestUser('testuser', 'US');
        
        Id balanceId = null;
        Exception expectedException = null;

        Test.startTest();
        try {
            balanceId = LeaveRequestController.getLeaveBalanceId(testUser.Id, 'RTT');
        } catch (Exception e) {
            expectedException = e;
        }
        Test.stopTest();

        System.assertEquals(null, balanceId, 'Balance ID should be null when no record is found.');
        System.assertNotEquals(null, expectedException, 'An exception should have been thrown.');
        System.assert(expectedException instanceof AuraHandledException, 'The exception should be an AuraHandledException.');
    }

    @isTest
    static void testGetMyLeaves() {
        User testUser = TestDataFactory.createTestUser('testuser', 'US');
        
        System.runAs(testUser) {
            Leave_Balance__c leaveBalance = TestDataFactory.createLeaveBalance(testUser.Id, 'Vacation', 20);
            
            Leave_Request__c leaveRequest = TestDataFactory.createLeaveRequest(
                testUser.Id, 
                'Vacation', 
                Date.today(), 
                Date.today().addDays(2), 
                leaveBalance.Id
            );
            insert leaveRequest;

            Test.startTest();
            List<Leave_Request__c> myLeaves = LeaveRequestController.getMyLeaves();
            Test.stopTest();

            System.assertEquals(1, myLeaves.size(), 'Should return one leave request.');
            System.assertEquals(leaveRequest.Id, myLeaves[0].Id, 'The returned leave request ID should match the created one.');
        }
    }

    @isTest
    static void testGetMyLeaves_NoRecords() {
        User testUser = TestDataFactory.createTestUser('testuser', 'US');

        System.runAs(testUser) {
            Test.startTest();
            List<Leave_Request__c> myLeaves = LeaveRequestController.getMyLeaves();
            Test.stopTest();

            System.assert(myLeaves.isEmpty(), 'Should return an empty list when there are no leave requests.');
        }
    }
}