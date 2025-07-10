@isTest
private class LeaveBalanceHandlerTest {

    @isTest
    static void testPopulateLeaveBalanceId_Success() {
        User testUser = TestDataFactory.createTestUser('tuser1', 'US');
        Leave_Balance__c leaveBalance = TestDataFactory.createLeaveBalance(testUser.Id, 'Vacation', 20);

        Leave_Request__c leaveRequest = TestDataFactory.createLeaveRequest(
            testUser.Id, 'Vacation', 7, 5 
        );

        Test.startTest();
        LeaveBalanceHandler.populateLeaveBalanceId(new List<Leave_Request__c>{leaveRequest});
        Test.stopTest();

        System.assertEquals(leaveBalance.Id, leaveRequest.Leave_Balance__c, 
            'Leave Balance ID should be automatically populated');
    }

    @isTest
    static void testPopulateLeaveBalanceId_NoBalanceFound() {
        User testUser = TestDataFactory.createTestUser('tuser2', 'US');

        Leave_Request__c leaveRequest = TestDataFactory.createLeaveRequest(
            testUser.Id, 'Vacation', 7, 5
        );

        Test.startTest();
        LeaveBalanceHandler.populateLeaveBalanceId(new List<Leave_Request__c>{leaveRequest});
        Test.stopTest();

  
        System.assert(leaveRequest.hasErrors(), 'Request should have errors when no balance found');
    }

    @isTest
    static void testPopulateLeaveBalanceId_MultipleRequests() {
        User testUser1 = TestDataFactory.createTestUser('tuser3', 'US');
        User testUser2 = TestDataFactory.createTestUser('tuser4', 'FR');
        
        Leave_Balance__c balance1 = TestDataFactory.createLeaveBalance(testUser1.Id, 'Vacation', 20);
        Leave_Balance__c balance2 = TestDataFactory.createLeaveBalance(testUser2.Id, 'RTT', 15);

        List<Leave_Request__c> requests = new List<Leave_Request__c>{
            TestDataFactory.createLeaveRequest(testUser1.Id, 'Vacation', 7, 5),
            TestDataFactory.createLeaveRequest(testUser2.Id, 'RTT', 10, 3)
        };

        Test.startTest();
        LeaveBalanceHandler.populateLeaveBalanceId(requests);
        Test.stopTest();

        System.assertEquals(balance1.Id, requests[0].Leave_Balance__c, 
            'First request should have correct balance ID');
        System.assertEquals(balance2.Id, requests[1].Leave_Balance__c, 
            'Second request should have correct balance ID');
    }

    @isTest
    static void testPopulateLeaveBalanceId_EmptyList() {
        List<Leave_Request__c> emptyList = new List<Leave_Request__c>();
        
        Test.startTest();
        LeaveBalanceHandler.populateLeaveBalanceId(emptyList);
        Test.stopTest();

        System.assertEquals(0, emptyList.size(), 'Empty list should remain empty');
        
        System.assertEquals(0, Limits.getQueries(), 'No SOQL queries should be executed for empty list');
    }

    @isTest
    static void testPopulateLeaveBalanceId_NullRequesterOrLeaveType() {
        User testUser = TestDataFactory.createTestUser('tuser5', 'US');

        List<Leave_Request__c> requests = new List<Leave_Request__c>{
            new Leave_Request__c(
                Requester__c = null, 
                Start_Date__c = Date.today().addDays(7),
                End_Date__c = Date.today().addDays(11),
                Leave_Type__c = 'Vacation'
            ),
            new Leave_Request__c(
                Requester__c = testUser.Id,
                Start_Date__c = Date.today().addDays(7),
                End_Date__c = Date.today().addDays(11),
                Leave_Type__c = null 
            )
        };

        Test.startTest();
        LeaveBalanceHandler.populateLeaveBalanceId(requests);
        Test.stopTest();

        System.assertEquals(null, requests[0].Leave_Balance__c, 
            'Request with null requester should not be processed');
        System.assertEquals(null, requests[1].Leave_Balance__c, 
            'Request with null leave type should not be processed');
            
        System.assertEquals(0, Limits.getQueries(), 
            'No SOQL queries should be executed when all requests have null values');
    }
}
