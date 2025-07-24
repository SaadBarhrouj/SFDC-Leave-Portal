@isTest
public class ScheduledHolidaySyncTest {
    @isTest
    static void testScheduleJob() {
        Test.startTest();
        String jobId = System.schedule('TestHolidaySyncJob', '0 0 0 1 1 ? 2050', new ScheduledHolidaySync());
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'The scheduled job must have an Id.');
    }
}