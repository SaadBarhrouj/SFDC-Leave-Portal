@isTest
private class LeaveRequestUtilsTest {

    @TestSetup
    static void makeData(){
        List<Holiday__c> holidays = new List<Holiday__c>();
        holidays.add(new Holiday__c(
            Name = 'MA Holiday',
            Unique_ID__c = 'MAHOLIDAY01',
            Holiday_Date__c = Date.newInstance(2024, 7, 4), // Thursday
            Country_Code__c = 'MA',
            Deduction_Value__c = 1
        ));
        holidays.add(new Holiday__c(
            Name = 'MA Half Holiday',
            Unique_ID__c = 'MAHOLIDAY02',
            Holiday_Date__c = Date.newInstance(2024, 7, 5), // Friday
            Country_Code__c = 'MA',
            Deduction_Value__c = 0.5
        ));
        holidays.add(new Holiday__c(
            Name = 'MA Weekend Holiday',
            Unique_ID__c = 'MAHOLIDAY03',
            Holiday_Date__c = Date.newInstance(2024, 7, 6), // Saturday
            Country_Code__c = 'MA',
            Deduction_Value__c = 1
        ));
        holidays.add(new Holiday__c(
            Name = 'FR Holiday',
            Unique_ID__c = 'FRHOLIDAY01',
            Holiday_Date__c = Date.newInstance(2024, 7, 8), // Monday
            Country_Code__c = 'FR',
            Deduction_Value__c = 1
        ));
        insert holidays;
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