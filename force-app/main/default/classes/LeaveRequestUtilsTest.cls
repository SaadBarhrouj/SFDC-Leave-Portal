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
}