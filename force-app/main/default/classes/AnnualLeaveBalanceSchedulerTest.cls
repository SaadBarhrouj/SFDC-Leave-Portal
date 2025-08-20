@isTest
public class AnnualLeaveBalanceSchedulerTest {
    @isTest
    static void testScheduleJob() {
        Test.startTest();
        String jobId = System.schedule(
            'TestAnnualLeaveBalanceJob',
            '0 0 0 1 1 ? 2050',
            new AnnualLeaveBalanceScheduler()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'The scheduled job must have an Id.');
    }
}