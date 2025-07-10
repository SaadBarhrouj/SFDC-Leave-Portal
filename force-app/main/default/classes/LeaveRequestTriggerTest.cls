
@isTest
private class LeaveRequestTriggerTest {

    @isTest
    static void testLeaveRequestTrigger_Insert() {
        User testUser = TestDataFactory.createTestUser('tstuser', 'US');
        Leave_Balance__c leaveBalance = TestDataFactory.createLeaveBalance(testUser.Id, 'Vacation', 20);

        Leave_Request__c leaveRequest = TestDataFactory.createLeaveRequest(
            testUser.Id, 'Vacation', 
            Date.newInstance(2025, 7, 14), 
            Date.newInstance(2025, 7, 18), 
            null
        );

        Test.startTest();
        insert leaveRequest;
        Test.stopTest();

        Leave_Request__c updatedLeaveRequest = [
            SELECT Number_of_Days_Requested__c, Leave_Balance__c 
            FROM Leave_Request__c 
            WHERE Id = :leaveRequest.Id
        ];

        System.assertEquals(5, updatedLeaveRequest.Number_of_Days_Requested__c);
        System.assertEquals(leaveBalance.Id, updatedLeaveRequest.Leave_Balance__c, 'Leave Balance ID should be automatically found and set by trigger');
    }

    @isTest
    static void testLeaveRequestTrigger_Update() {
        User testUser = TestDataFactory.createTestUser('tstuser2', 'US');
        Leave_Balance__c leaveBalance = TestDataFactory.createLeaveBalance(testUser.Id, 'Vacation', 20);

        Leave_Request__c leaveRequest = TestDataFactory.createLeaveRequest(
            testUser.Id, 'Vacation', 
            Date.newInstance(2025, 8, 4), 
            Date.newInstance(2025, 8, 8), 
            null
        );
        insert leaveRequest;

        leaveRequest.End_Date__c = Date.newInstance(2025, 8, 11);

        Test.startTest();
        update leaveRequest;
        Test.stopTest();

        Leave_Request__c updatedLeaveRequest = [
            SELECT Number_of_Days_Requested__c, Leave_Balance__c 
            FROM Leave_Request__c 
            WHERE Id = :leaveRequest.Id
        ];

        System.assertEquals(6, updatedLeaveRequest.Number_of_Days_Requested__c);
        System.assertEquals(leaveBalance.Id, updatedLeaveRequest.Leave_Balance__c, 'Leave Balance ID should remain correct after update');
    }
}


