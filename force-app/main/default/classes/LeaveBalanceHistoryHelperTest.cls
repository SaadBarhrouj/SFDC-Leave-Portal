@isTest
private class LeaveBalanceHistoryHelperTest {

    @isTest
    static void testHistoryOnApproved() {
        Integer minNotice = 5;
        Leave_Policy_Settings__c settings = Leave_Policy_Settings__c.getOrgDefaults();
        if (settings != null && settings.Minimum_Notice_Period_Days__c != null) {
            minNotice = Integer.valueOf(settings.Minimum_Notice_Period_Days__c);
        }
        Date startDate = Date.today().addDays(minNotice + 1);
        Date endDate = startDate.addDays(2);

        User user = TestDataFactory.createTestUser('hUapprv', 'FR');
        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(user.Id, 'Paid Leave', 10);

        Leave_Request__c req = TestDataFactory.createLeaveRequest(
            user.Id, 'Paid Leave', startDate, endDate, balance.Id, 'Submitted'
        );
        req.Status__c = 'Approved';
        req.Number_of_Days_Requested__c = 3;

        Test.startTest();
        update req;
        Test.stopTest();

        List<Leave_Balance_History__c> histories = [
            SELECT Movement_Type__c, Source_of_Movement__c, Number_of_Days__c
            FROM Leave_Balance_History__c
            WHERE Employee__c = :user.Id
              AND Leave_Type__c = 'Paid Leave'
              AND Source_of_Movement__c = 'Leave Request Approved'
        ];
        System.assertEquals(1, histories.size(), 'Should create one history for approval');
        System.assertEquals('Deduction', histories[0].Movement_Type__c);
        System.assertEquals('Leave Request Approved', histories[0].Source_of_Movement__c);
        System.assertEquals(-3, histories[0].Number_of_Days__c);
    }

    @isTest
    static void testHistoryOnCancelled() {
        Integer minNotice = 5;
        Leave_Policy_Settings__c settings = Leave_Policy_Settings__c.getOrgDefaults();
        if (settings != null && settings.Minimum_Notice_Period_Days__c != null) {
            minNotice = Integer.valueOf(settings.Minimum_Notice_Period_Days__c);
        }
        Date startDate = Date.today().addDays(minNotice + 1);
        Date endDate = startDate.addDays(1);

        User user = TestDataFactory.createTestUser('hUcancl', 'FR');
        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(user.Id, 'RTT', 8);

        Leave_Request__c req = TestDataFactory.createLeaveRequest(
            user.Id, 'RTT', startDate, endDate, balance.Id, 'Cancellation Requested'
        );
        req.Status__c = 'Cancelled';
        req.Number_of_Days_Requested__c = 2;

        Test.startTest();
        update req;
        Test.stopTest();

        List<Leave_Balance_History__c> histories = [
            SELECT Movement_Type__c, Source_of_Movement__c, Number_of_Days__c
            FROM Leave_Balance_History__c
            WHERE Employee__c = :user.Id
              AND Leave_Type__c = 'RTT'
              AND Source_of_Movement__c = 'Leave Request Cancelled'
        ];
        System.assertEquals(1, histories.size(), 'Should create one history for cancellation');
        System.assertEquals('Accrual', histories[0].Movement_Type__c);
        System.assertEquals('Leave Request Cancelled', histories[0].Source_of_Movement__c);
        System.assertEquals(2, histories[0].Number_of_Days__c);
    }

    @isTest
    static void testNoHistoryIfStatusUnchanged() {
        Integer minNotice = 5;
        Leave_Policy_Settings__c settings = Leave_Policy_Settings__c.getOrgDefaults();
        if (settings != null && settings.Minimum_Notice_Period_Days__c != null) {
            minNotice = Integer.valueOf(settings.Minimum_Notice_Period_Days__c);
        }
        Date startDate = Date.today().addDays(minNotice + 1);
        Date endDate = startDate.addDays(2);

        User user = TestDataFactory.createTestUser('hUunchg', 'FR');
        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(user.Id, 'Paid Leave', 10);

        Leave_Request__c req = TestDataFactory.createLeaveRequest(
            user.Id, 'Paid Leave', startDate, endDate, balance.Id, 'Submitted'
        );

        Test.startTest();
        update req; 
        Test.stopTest();

        Integer count = [SELECT count() FROM Leave_Balance_History__c
                         WHERE Employee__c = :user.Id
                         AND Leave_Type__c = 'Paid Leave'
                         AND Source_of_Movement__c = 'Leave Request Approved'];
        System.assertEquals(0, count, 'No history should be created if status did not change');
    }

    @isTest
    static void testNoHistoryIfOtherLeaveType() {
        Integer minNotice = 5;
        Leave_Policy_Settings__c settings = Leave_Policy_Settings__c.getOrgDefaults();
        if (settings != null && settings.Minimum_Notice_Period_Days__c != null) {
            minNotice = Integer.valueOf(settings.Minimum_Notice_Period_Days__c);
        }
        Date startDate = Date.today().addDays(minNotice + 1);
        Date endDate = startDate.addDays(1);

        User user = TestDataFactory.createTestUser('hUothrt', 'FR');
        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(user.Id, 'Sick Leave', 5);

        Leave_Request__c req = TestDataFactory.createLeaveRequest(
            user.Id, 'Sick Leave', startDate, endDate, balance.Id, 'Submitted'
        );
        req.Status__c = 'Approved';

        Test.startTest();
        update req; 
        Test.stopTest();

        Integer count = [SELECT count() FROM Leave_Balance_History__c
                         WHERE Employee__c = :user.Id
                         AND Leave_Type__c = 'Sick Leave'
                         AND Source_of_Movement__c = 'Leave Request Approved'];
        System.assertEquals(0, count, 'No history should be created for other leave types');
    }
}