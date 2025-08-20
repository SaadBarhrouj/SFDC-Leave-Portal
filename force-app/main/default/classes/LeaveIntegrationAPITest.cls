@isTest
private class LeaveIntegrationAPITest {

    @TestSetup
    static void makeData(){
        List<Profile> standardUserProfiles = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
        
        List<User> testUsers = new List<User>();
        testUsers.add(new User(
            ProfileId = standardUserProfiles[0].Id,
            LastName = 'Test',
            Email = 'testuser1@example.com',
            Username = 'testuser1@example.com' + System.currentTimeMillis(),
            CompanyName = 'TestCorp',
            Title = 'Tester',
            Alias = 'test1',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            Work_Country__c = 'US'
        ));
        testUsers.add(new User(
            ProfileId = standardUserProfiles[0].Id,
            LastName = 'UserTwo',
            Email = 'testuser2@example.com',
            Username = 'testuser2@example.com' + System.currentTimeMillis(),
            CompanyName = 'TestCorp',
            Title = 'Tester',
            Alias = 'test2',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            Work_Country__c = 'US'
        ));
        insert testUsers;

        User user1 = [SELECT Id FROM User WHERE Email = 'testuser1@example.com' LIMIT 1];
        User user2 = [SELECT Id FROM User WHERE Email = 'testuser2@example.com' LIMIT 1];

        List<Leave_Balance__c> balances = new List<Leave_Balance__c>();
        balances.add(new Leave_Balance__c(
            Employee__c = user1.Id,
            Year__c = Decimal.valueOf(Date.today().year()),
            Leave_Type__c = 'Paid Leave',
            Allocated_Days__c = 20,
            Used_Days__c = 0
        ));
        balances.add(new Leave_Balance__c(
            Employee__c = user2.Id,
            Year__c = Decimal.valueOf(Date.today().year()),
            Leave_Type__c = 'Paid Leave',
            Allocated_Days__c = 20,
            Used_Days__c = 0
        ));
        insert balances;
    }

    @isTest
    static void testProcessNewRequest_Success() {
        User u = [SELECT Id, Email FROM User WHERE Email = 'testuser1@example.com' LIMIT 1];
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/leave/requests';
        req.httpMethod = 'POST';
        
        LeaveIntegrationAPI.LeaveRequestWrapper wrapper = new LeaveIntegrationAPI.LeaveRequestWrapper();
        wrapper.userEmail = u.Email;
        wrapper.leaveType = 'Paid Leave';
        wrapper.startDate = Date.today().addDays(10);
        wrapper.endDate = Date.today().addDays(12);
        wrapper.employeeComment = 'API Test Vacation';
        wrapper.status = 'Submitted';
        req.requestBody = Blob.valueOf(JSON.serialize(wrapper));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LeaveIntegrationAPI.handlePost();
        Test.stopTest();

        System.assertEquals(201, res.statusCode, 'Status code should be 201 Created.');
        LeaveIntegrationAPI.Result result = (LeaveIntegrationAPI.Result) JSON.deserialize(res.responseBody.toString(), LeaveIntegrationAPI.Result.class);
        System.assertEquals('Success', result.status);
        System.assertNotEquals(null, result.salesforceRequestId);

        Leave_Request__c createdRequest = [SELECT Id FROM Leave_Request__c WHERE Id = :result.salesforceRequestId];
        System.assertNotEquals(null, createdRequest);
    }

    @isTest
    static void testProcessNewRequest_NoBalance() {
        User u = [SELECT Id, Email FROM User WHERE Email = 'testuser1@example.com' LIMIT 1];
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/leave/requests';
        req.httpMethod = 'POST';
        
        LeaveIntegrationAPI.LeaveRequestWrapper wrapper = new LeaveIntegrationAPI.LeaveRequestWrapper();
        wrapper.userEmail = u.Email;
        wrapper.leaveType = 'Sick Leave';
        wrapper.startDate = Date.today().addDays(10);
        wrapper.endDate = Date.today().addDays(11);
        wrapper.status = 'Submitted';
        req.requestBody = Blob.valueOf(JSON.serialize(wrapper));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LeaveIntegrationAPI.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        LeaveIntegrationAPI.Result result = (LeaveIntegrationAPI.Result) JSON.deserialize(res.responseBody.toString(), LeaveIntegrationAPI.Result.class);
        System.assertEquals('Error', result.status);
        System.assertEquals('Leave balance not found for user.', result.message);
    }

    @isTest
    static void testProcessNewRequest_UserNotFound() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/leave/requests';
        req.httpMethod = 'POST';

        LeaveIntegrationAPI.LeaveRequestWrapper wrapper = new LeaveIntegrationAPI.LeaveRequestWrapper();
        wrapper.userEmail = 'no.such.user@example.com';
        wrapper.leaveType = 'Paid Leave';
        wrapper.startDate = Date.today().addDays(5);
        wrapper.endDate = Date.today().addDays(6);
        wrapper.status = 'Submitted';
        req.requestBody = Blob.valueOf(JSON.serialize(wrapper));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LeaveIntegrationAPI.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        LeaveIntegrationAPI.Result result = (LeaveIntegrationAPI.Result) JSON.deserialize(res.responseBody.toString(), LeaveIntegrationAPI.Result.class);
        System.assertEquals('Error', result.status);
        System.assert(result.message.contains('Active user not found'));
    }

    @isTest
    static void testProcessBulkRequests_AllSuccess() {
        User user1 = [SELECT Id, Email FROM User WHERE Email = 'testuser1@example.com' LIMIT 1];
        User user2 = [SELECT Id, Email FROM User WHERE Email = 'testuser2@example.com' LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/leave/requests';
        req.httpMethod = 'POST';

        List<LeaveIntegrationAPI.LeaveRequestWrapper> wrappers = new List<LeaveIntegrationAPI.LeaveRequestWrapper>();
        
        LeaveIntegrationAPI.LeaveRequestWrapper wrapper1 = new LeaveIntegrationAPI.LeaveRequestWrapper();
        wrapper1.userEmail = user1.Email;
        wrapper1.leaveType = 'Paid Leave';
        wrapper1.startDate = Date.today().addDays(20);
        wrapper1.endDate = Date.today().addDays(21);
        wrapper1.status = 'Approved';
        wrappers.add(wrapper1);

        LeaveIntegrationAPI.LeaveRequestWrapper wrapper2 = new LeaveIntegrationAPI.LeaveRequestWrapper();
        wrapper2.userEmail = user2.Email;
        wrapper2.leaveType = 'Paid Leave';
        wrapper2.startDate = Date.today().addDays(22);
        wrapper2.endDate = Date.today().addDays(23);
        wrapper2.status = 'Submitted';
        wrappers.add(wrapper2);

        req.requestBody = Blob.valueOf(JSON.serialize(wrappers));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LeaveIntegrationAPI.handlePost();
        Test.stopTest();

        System.assertEquals(207, res.statusCode);
        List<LeaveIntegrationAPI.Result> results = (List<LeaveIntegrationAPI.Result>) JSON.deserialize(res.responseBody.toString(), List<LeaveIntegrationAPI.Result>.class);
        System.assertEquals(2, results.size());
        System.assertEquals('Success', results[0].status);
        System.assertEquals('Success', results[1].status);
        System.assertNotEquals(null, results[0].salesforceRequestId);
        System.assertNotEquals(null, results[1].salesforceRequestId);
    }

    @isTest
    static void testProcessBulkRequests_PartialSuccess() {
        User user1 = [SELECT Id, Email FROM User WHERE Email = 'testuser1@example.com' LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/leave/requests';
        req.httpMethod = 'POST';

        List<LeaveIntegrationAPI.LeaveRequestWrapper> wrappers = new List<LeaveIntegrationAPI.LeaveRequestWrapper>();
        
        LeaveIntegrationAPI.LeaveRequestWrapper wrapper1 = new LeaveIntegrationAPI.LeaveRequestWrapper();
        wrapper1.userEmail = user1.Email;
        wrapper1.leaveType = 'Paid Leave';
        wrapper1.startDate = Date.today().addDays(30);
        wrapper1.endDate = Date.today().addDays(31);
        wrapper1.status = 'Submitted';
        wrappers.add(wrapper1);

        LeaveIntegrationAPI.LeaveRequestWrapper wrapper2 = new LeaveIntegrationAPI.LeaveRequestWrapper();
        wrapper2.userEmail = user1.Email;
        wrapper2.leaveType = 'Unpaid Leave';
        wrapper2.startDate = Date.today().addDays(32);
        wrapper2.endDate = Date.today().addDays(33);
        wrapper2.status = 'Submitted';
        wrappers.add(wrapper2);

        LeaveIntegrationAPI.LeaveRequestWrapper wrapper3 = new LeaveIntegrationAPI.LeaveRequestWrapper();
        wrapper3.userEmail = 'nosuchuser@example.com';
        wrapper3.leaveType = 'Paid Leave';
        wrapper3.startDate = Date.today().addDays(34);
        wrapper3.endDate = Date.today().addDays(35);
        wrapper3.status = 'Submitted';
        wrappers.add(wrapper3);

        req.requestBody = Blob.valueOf(JSON.serialize(wrappers));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LeaveIntegrationAPI.handlePost();
        Test.stopTest();

        System.assertEquals(207, res.statusCode);
        List<LeaveIntegrationAPI.Result> results = (List<LeaveIntegrationAPI.Result>) JSON.deserialize(res.responseBody.toString(), List<LeaveIntegrationAPI.Result>.class);
        System.assertEquals(3, results.size());

        Integer successCount = 0;
        Integer errorCount = 0;
        for(LeaveIntegrationAPI.Result r : results){
            if(r.status == 'Success'){
                successCount++;
            } else {
                errorCount++;
            }
        }
        System.assertEquals(1, successCount, 'There should be one successful record.');
        System.assertEquals(2, errorCount, 'There should be two failed records.');
    }

    @isTest
    static void testHandlePost_InvalidJson() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/leave/requests';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('this is not json');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LeaveIntegrationAPI.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        LeaveIntegrationAPI.Result result = (LeaveIntegrationAPI.Result) JSON.deserialize(res.responseBody.toString(), LeaveIntegrationAPI.Result.class);
        System.assertEquals('Error', result.status);
        System.assertEquals('Invalid JSON format.', result.message);
    }
}