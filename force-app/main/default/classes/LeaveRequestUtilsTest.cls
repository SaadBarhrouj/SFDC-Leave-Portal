@isTest
private class LeaveRequestUtilsTest {

    @TestSetup
    static void makeData(){
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
    static void testCalculateDays_WithWeekendsAndHolidays() {
        Date startDate = Date.newInstance(2024, 7, 1);
        Date endDate = Date.newInstance(2024, 7, 12);

        Test.startTest();
        Decimal actualDays = LeaveRequestUtils.calculateRequestedDays(startDate, endDate, 'MA');
        Test.stopTest();

        System.assertEquals(8.5, actualDays, 'Should exclude weekends and holidays with correct deductions.');
    }

    @isTest
    static void testCalculateDays_OnlyWeekends() {
        Date startDate = Date.newInstance(2024, 6, 28);
        Date endDate = Date.newInstance(2024, 7, 1);

        Test.startTest();
        Decimal actualDays = LeaveRequestUtils.calculateRequestedDays(startDate, endDate, 'MA');
        Test.stopTest();

        System.assertEquals(2, actualDays, 'Should correctly exclude only weekend days.');
    }

    @isTest
    static void testCalculateDays_HolidayOnWeekend() {
        Date startDate = Date.newInstance(2024, 7, 5);
        Date endDate = Date.newInstance(2024, 7, 8);

        Test.startTest();
        Decimal actualDays = LeaveRequestUtils.calculateRequestedDays(startDate, endDate, 'MA');
        Test.stopTest();

        System.assertEquals(1.5, actualDays, 'A holiday on a weekend should not be deducted.');
    }

    @isTest
    static void testCalculateDays_NoMatchingCountryHoliday() {
        Date startDate = Date.newInstance(2024, 7, 8);
        Date endDate = Date.newInstance(2024, 7, 12);

        Test.startTest();
        Decimal actualDays = LeaveRequestUtils.calculateRequestedDays(startDate, endDate, 'MA');
        Test.stopTest();

        System.assertEquals(5, actualDays, 'Holidays for other countries should be ignored.');
    }

    @isTest
    static void testCalculateDays_InvalidDateRange() {
        Date startDate = Date.newInstance(2024, 6, 10);
        Date endDate = Date.newInstance(2024, 6, 1);

        Test.startTest();
        Decimal actualDays = LeaveRequestUtils.calculateRequestedDays(startDate, endDate, 'MA');
        Test.stopTest();

        System.assertEquals(0, actualDays, 'Should be 0 for an invalid date range.');
    }

    @isTest
    static void testCalculateDays_NullDates() {
        Test.startTest();
        Decimal actualDaysWithNullStart = LeaveRequestUtils.calculateRequestedDays(null, Date.newInstance(2024, 6, 10), 'MA');
        Decimal actualDaysWithNullEnd = LeaveRequestUtils.calculateRequestedDays(Date.newInstance(2024, 6, 1), null, 'MA');
        Test.stopTest();

        System.assertEquals(0, actualDaysWithNullStart, 'Should be 0 for a null start date.');
        System.assertEquals(0, actualDaysWithNullEnd, 'Should be 0 for a null end date.');
    }

    @isTest
    static void testValidateNoOverlappingRequests() {
           User user1 = TestDataFactory.createTestUser('User1', 'MA');
           User user2 = TestDataFactory.createTestUser('User2', 'MA');
        Leave_Request__c existingRequest = new Leave_Request__c(
            Start_Date__c = Date.newInstance(2026, 7, 1),
            End_Date__c = Date.newInstance(2026, 7, 5),
            Requester__c = user1.Id,
            Leave_Type__c = 'RTT'
        );
        insert existingRequest;

         List<Leave_Request__c> newRequests = new List<Leave_Request__c> {
            new Leave_Request__c(
                Start_Date__c = Date.newInstance(2026, 7, 1),
                End_Date__c = Date.newInstance(2026, 7, 5),
                Requester__c = user2.Id,
                Leave_Type__c = 'RTT'
            ),
            new Leave_Request__c(
                Start_Date__c = Date.newInstance(2026, 7, 6),
                End_Date__c = Date.newInstance(2026, 7, 10),
                Requester__c = user1.Id,
                Leave_Type__c = 'RTT'
            )
        };
        insert newRequests; 

        System.AssertEquals(3, [SELECT COUNT() FROM Leave_Request__c], 'Should have 3 leave requests including the existing one.');
        System.AssertEquals(0, newRequests[0].getErrors().size(), 'The first new request should not  have an error due to overlapping dates.');
    }
}