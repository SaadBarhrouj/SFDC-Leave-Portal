@isTest
private class LeaveRequestDetailControllerTest {

    @TestSetup
    static void makeData(){
        User testUser = TestDataFactory.createTestUser('testu', 'MA');

        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(testUser.Id, 'Paid Leave', 20);

        Leave_Request__c request = TestDataFactory.createLeaveRequest(
            testUser.Id, 
            'Paid Leave', 
            Date.today().addDays(10), 
            Date.today().addDays(12), 
            balance.Id
        );
        request.Status__c = 'Pending Manager Approval';
        insert request;
    }

    @isTest
    static void testGetLeaveRequestDetails_Success() {
        Leave_Request__c req = [SELECT Id FROM Leave_Request__c LIMIT 1];
        User sysAdminUser = TestDataFactory.createTestUser('uAdmin', 'MA', 'System Administrator');

        Test.startTest();
        System.runAs(sysAdminUser) {
            Leave_Request__c result = LeaveRequestDetailController.getLeaveRequestDetails(req.Id, null);
            System.assertNotEquals(null, result, 'Leave request should not be null.');
            System.assertEquals(req.Id, result.Id, 'Leave request ID should match.');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetLeaveRequestDetails_NullId() {
        Test.startTest();
        Leave_Request__c result = LeaveRequestDetailController.getLeaveRequestDetails(null, null);
        Test.stopTest();
        System.assertEquals(null, result, 'Result should be null for a null Id.');
    }
}