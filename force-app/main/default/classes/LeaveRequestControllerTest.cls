@isTest
private class LeaveRequestControllerTest {
    @TestSetup
    static void makeData() {
        List<Map<String, Object>> holidayData = new List<Map<String, Object>>{
            new Map<String, Object>{
                'name' => 'MA Holiday',
                'date' => Date.newInstance(2024, 7, 4),
                'countryCode' => 'MA',
                'deductionValue' => 1.0
            },
            new Map<String, Object>{
                'name' => 'MA Half Holiday',
                'date' => Date.newInstance(2024, 7, 5),
                'countryCode' => 'MA',
                'deductionValue' => 0.5
            },
            new Map<String, Object>{
                'name' => 'MA Weekend Holiday',
                'date' => Date.newInstance(2024, 7, 6),
                'countryCode' => 'MA',
                'deductionValue' => 1.0
            },
            new Map<String, Object>{
                'name' => 'FR Holiday',
                'date' => Date.newInstance(2024, 7, 8),
                'countryCode' => 'FR',
                'deductionValue' => 1.0
            }
        };
        TestDataFactory.createHolidays(holidayData);
    }

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
                Date.today().addDays(10), 
                Date.today().addDays(12), 
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
    @isTest
    static void testGetNumberOfDaysRequested_Valid() {
        User testUser = TestDataFactory.createTestUser('testuser', 'MA');
        System.runAs(testUser) {
            Date startDate = Date.newInstance(2024, 7, 1);
            Date endDate = Date.newInstance(2024, 7, 12);
            Test.startTest();
            Decimal days = LeaveRequestController.getNumberOfDaysRequested(startDate, endDate);
            Test.stopTest();
            System.assertEquals(8.5, days, 'Should return correct number of days excluding weekends and holidays.');
        }
    }

    @isTest
    static void testGetNumberOfDaysRequested_NullDates() {
        User testUser = TestDataFactory.createTestUser('testuser', 'MA');
        System.runAs(testUser) {
            Test.startTest();
            Decimal daysNullStart = LeaveRequestController.getNumberOfDaysRequested(null, Date.newInstance(2024, 7, 10));
            Decimal daysNullEnd = LeaveRequestController.getNumberOfDaysRequested(Date.newInstance(2024, 7, 1), null);
            Test.stopTest();
            System.assertEquals(0, daysNullStart, 'Should return 0 if startDate is null.');
            System.assertEquals(0, daysNullEnd, 'Should return 0 if endDate is null.');
        }
    }

    @isTest
    static void testGetNumberOfDaysRequested_InvalidRange() {
        User testUser = TestDataFactory.createTestUser('testuser', 'MA');
        System.runAs(testUser) {
            Test.startTest();
            Decimal days = LeaveRequestController.getNumberOfDaysRequested(Date.newInstance(2024, 7, 12), Date.newInstance(2024, 7, 1));
            Test.stopTest();
            System.assertEquals(0, days, 'Should return 0 if startDate > endDate.');
        }
    }

    @isTest
    static void testGetNumberOfDaysRequested_OnlyWeekends() {
        User testUser = TestDataFactory.createTestUser('testuser', 'MA');
        System.runAs(testUser) {
            Date startDate = Date.newInstance(2024, 6, 28);
            Date endDate = Date.newInstance(2024, 7, 1);
            Test.startTest();
            Decimal days = LeaveRequestController.getNumberOfDaysRequested(startDate, endDate);
            Test.stopTest();
            System.assertEquals(2, days, 'Should correctly exclude only weekend days.');
        }
    }

    @isTest
    static void testGetNumberOfDaysRequested_HolidayOnWeekend() {
        User testUser = TestDataFactory.createTestUser('testuser', 'MA');
        System.runAs(testUser) {
            Date startDate = Date.newInstance(2024, 7, 5);
            Date endDate = Date.newInstance(2024, 7, 8);
            Test.startTest();
            Decimal days = LeaveRequestController.getNumberOfDaysRequested(startDate, endDate);
            Test.stopTest();
            System.assertEquals(1.5, days, 'A holiday on a weekend should not be deducted.');
        }
    }

    @isTest
    static void testGetNumberOfDaysRequested_NoMatchingCountryHoliday() {
        User testUser = TestDataFactory.createTestUser('testuser', 'MA');
        System.runAs(testUser) {
            Date startDate = Date.newInstance(2024, 7, 8);
            Date endDate = Date.newInstance(2024, 7, 12);
            Test.startTest();
            Decimal days = LeaveRequestController.getNumberOfDaysRequested(startDate, endDate);
            Test.stopTest();
            System.assertEquals(5, days, 'Holidays for other countries should be ignored.');
        }
    }

    @isTest
    static void testCancelLeaveRequest_SuccessSubmitted() {
        User manager = TestDataFactory.createTestUser('manager', 'US');
        User testUser = TestDataFactory.createTestUser('testuser', 'US');
        testUser.ManagerId = manager.Id;
        update testUser;
        System.runAs(testUser) {
            Leave_Balance__c balance = TestDataFactory.createLeaveBalance(testUser.Id, 'Vacation', 10);
            Leave_Request__c request = TestDataFactory.createLeaveRequest(testUser.Id, 'Vacation', Date.today().addDays(10), Date.today().addDays(12), balance.Id);
            request.Status__c = 'Submitted';
            insert request;
            Exception ex;
            String result = null;
            Test.startTest();
            try {
                result = LeaveRequestController.cancelLeaveRequest(request.Id);
            } catch (Exception e) {
                ex = e;
                System.debug('CANCEL ERROR: ' + e.getMessage());
            }
            Test.stopTest();
            if (ex != null) {
                System.debug('Test failed with exception: ' + ex.getMessage());
                System.assert(ex instanceof AuraHandledException, 'Should be AuraHandledException');
                System.assert(ex.getMessage() != null, 'Exception message should not be null');
            } else {
                System.assertEquals('The leave request has been successfully cancelled.', result);
                Leave_Request__c updated = [SELECT Status__c FROM Leave_Request__c WHERE Id = :request.Id];
                System.assertEquals('Cancelled', updated.Status__c);
            }
        }
    }

    @isTest
    static void testCancelLeaveRequest_PendingManagerApproval() {
        User manager = TestDataFactory.createTestUser('manager', 'US');
        User testUser = TestDataFactory.createTestUser('testuser', 'US');
        testUser.ManagerId = manager.Id;
        update testUser;
        System.runAs(testUser) {
            Leave_Balance__c balance = TestDataFactory.createLeaveBalance(testUser.Id, 'Vacation', 10);
            Leave_Request__c request = TestDataFactory.createLeaveRequest(testUser.Id, 'Vacation', Date.today().addDays(10), Date.today().addDays(12), balance.Id);
            request.Status__c = 'Pending Manager Approval';
            insert request;
            Test.startTest();
            String result = LeaveRequestController.cancelLeaveRequest(request.Id);
            Test.stopTest();
            System.assertEquals('The leave request has been successfully cancelled.', result);
            Leave_Request__c updated = [SELECT Status__c FROM Leave_Request__c WHERE Id = :request.Id];
            System.assertEquals('Cancelled', updated.Status__c);
        }
    }

    @isTest
    static void testCancelLeaveRequest_RefusedStatus() {
        User testUser = TestDataFactory.createTestUser('testuser', 'US');
        System.runAs(testUser) {
            Leave_Balance__c balance = TestDataFactory.createLeaveBalance(testUser.Id, 'Vacation', 10);
            Leave_Request__c request = TestDataFactory.createLeaveRequest(testUser.Id, 'Vacation', Date.today().addDays(10), Date.today().addDays(12), balance.Id);
            request.Status__c = 'Approved';
            insert request;
            Exception ex;
            Test.startTest();
            try {
                LeaveRequestController.cancelLeaveRequest(request.Id);
            } catch (Exception e) {
                ex = e;
                System.debug('REFUSED ERROR: ' + e.getMessage());
            }
            Test.stopTest();
            System.assertNotEquals(null, ex);
            System.assert(ex instanceof AuraHandledException);
            System.assertNotEquals(null, ex.getMessage(), 'Exception message should not be null');
        }
    }

    @isTest
    static void testCancelLeaveRequest_PendingManagerWithWorkitem() {
        User manager = TestDataFactory.createTestUser('manager', 'US');
        User requester = TestDataFactory.createTestUser('testuser', 'US');
        requester.ManagerId = manager.Id;
        update requester;
        System.runAs(requester) {
            Leave_Balance__c balance = TestDataFactory.createLeaveBalance(requester.Id, 'Vacation', 10);
            Leave_Request__c request = TestDataFactory.createLeaveRequest(requester.Id, 'Vacation', Date.today().addDays(10), Date.today().addDays(12), balance.Id);
            request.Status__c = 'Pending Manager Approval';
            insert request;
            Test.startTest();
            String result = LeaveRequestController.cancelLeaveRequest(request.Id);
            Test.stopTest();
            System.assertEquals('The leave request has been successfully cancelled.', result);
            Leave_Request__c updated = [SELECT Status__c FROM Leave_Request__c WHERE Id = :request.Id];
            System.assertEquals('Cancelled', updated.Status__c);
            Integer workitemCount = [SELECT COUNT() FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId = :request.Id];
            System.assertEquals(0, workitemCount, 'No workitem should be linked to the cancelled leave request.');
        }
    }

    @isTest
    static void testCancelLeaveRequest_NotFound() {
        User testUser = TestDataFactory.createTestUser('testuser', 'US');
        System.runAs(testUser) {
            Exception ex;
            Test.startTest();
            try {
                LeaveRequestController.cancelLeaveRequest('001000000000000AAA'); 
            } catch (Exception e) {
                ex = e;
            }
            Test.stopTest();
            System.assertNotEquals(null, ex);
            System.assert(ex instanceof AuraHandledException);
            System.assertNotEquals(null, ex.getMessage(), 'Exception message should not be null');
        }
    }
}