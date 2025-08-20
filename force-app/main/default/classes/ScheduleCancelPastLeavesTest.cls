@isTest
public class ScheduleCancelPastLeavesTest {
    @isTest
    static void testScheduleJob() {
        Test.startTest();
        String jobId = System.schedule(
            'TestCancelPastLeavesJob',
            '0 0 0 1 1 ? 2050',
            new ScheduleCancelPastLeaves()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'The scheduled job must have an Id.');
    }
}