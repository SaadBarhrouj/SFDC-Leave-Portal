@isTest
private class LeaveRequestTriggerTest {

    private static Leave_Balance__c createLeaveBalance(Id userId, String leaveType, Decimal allocatedDays) {
        Leave_Balance__c lb = new Leave_Balance__c(
            Employee__c = userId,
            Leave_Type__c = leaveType,
            Allocated_Days__c = allocatedDays,
            Year__c = Date.today().year()
        );
        insert lb;
        return lb;
    }

    @isTest
    static void testLeaveRequestTrigger_Insert() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User testUser = new User(
            Alias = 'tstuser',
            Email='testuser@test.com',
            EmailEncodingKey='UTF-8',
            LastName='Testing',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles',
            UserName='testuser@test.com' + System.currentTimeMillis(),
            Country_Code__c = 'US'
        );
        insert testUser;

        Leave_Balance__c leaveBalance = createLeaveBalance(testUser.Id, 'Vacation', 20);

        Leave_Request__c leaveRequest = new Leave_Request__c(
            Requester__c = testUser.Id,
            Start_Date__c = Date.newInstance(2025, 7, 14),
            End_Date__c = Date.newInstance(2025, 7, 18),
            Leave_Type__c = 'Vacation',
            Leave_Balance__c = leaveBalance.Id
        );

        Test.startTest();
        insert leaveRequest;
        Test.stopTest();

        Leave_Request__c updatedLeaveRequest = [
            SELECT Number_of_Days_Requested__c 
            FROM Leave_Request__c 
            WHERE Id = :leaveRequest.Id
        ];

        System.assertEquals(5, updatedLeaveRequest.Number_of_Days_Requested__c);
    }

    @isTest
    static void testLeaveRequestTrigger_Update() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User testUser = new User(
            Alias = 'tstuser2',
            Email='testuser2@test.com',
            EmailEncodingKey='UTF-8',
            LastName='Testing2',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles',
            UserName='testuser2@test.com' + System.currentTimeMillis(),
            Country_Code__c = 'US'
        );
        insert testUser;

        Leave_Balance__c leaveBalance = createLeaveBalance(testUser.Id, 'Vacation', 20);

        Leave_Request__c leaveRequest = new Leave_Request__c(
            Requester__c = testUser.Id,
            Start_Date__c = Date.newInstance(2025, 8, 4),
            End_Date__c = Date.newInstance(2025, 8, 8),
            Leave_Type__c = 'Vacation',
            Leave_Balance__c = leaveBalance.Id
        );
        insert leaveRequest;

        leaveRequest.End_Date__c = Date.newInstance(2025, 8, 11);

        Test.startTest();
        update leaveRequest;
        Test.stopTest();

        Leave_Request__c updatedLeaveRequest = [
            SELECT Number_of_Days_Requested__c 
            FROM Leave_Request__c 
            WHERE Id = :leaveRequest.Id
        ];

        System.assertEquals(6, updatedLeaveRequest.Number_of_Days_Requested__c);
    }
}
