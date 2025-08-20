@isTest
public class AnnualLeaveBalanceBatchTest {

    @isTest
    static void testBatch_UserWithNoBalances() {
        User u = TestDataFactory.createTestUser('batch1', 'MA');
        Integer nextYear = Date.today().year() + 1;

        Test.startTest();
        Database.executeBatch(new AnnualLeaveBalanceBatch(), 200);
        Test.stopTest();

        List<Leave_Balance__c> balances = [
            SELECT Leave_Type__c FROM Leave_Balance__c
            WHERE Employee__c = :u.Id AND Year__c = :nextYear
        ];
        Set<String> types = new Set<String>();
        for (Leave_Balance__c b : balances) types.add(b.Leave_Type__c);
        System.assert(types.contains('Paid Leave'), 'Paid Leave should be created');
        System.assert(types.contains('RTT'), 'RTT should be created');
    }

    @isTest
    static void testBatch_UserWithPaidLeaveOnly() {
        User u = TestDataFactory.createTestUser('batch2', 'FR');
        Integer nextYear = Date.today().year() + 1;
        TestDataFactory.createPaidLeaveBalance(u.Id, 30, nextYear);

        Test.startTest();
        Database.executeBatch(new AnnualLeaveBalanceBatch(), 200);
        Test.stopTest();

        List<Leave_Balance__c> balances = [
            SELECT Leave_Type__c FROM Leave_Balance__c
            WHERE Employee__c = :u.Id AND Year__c = :nextYear
        ];
        Set<String> types = new Set<String>();
        for (Leave_Balance__c b : balances) types.add(b.Leave_Type__c);
        System.assert(types.contains('Paid Leave'), 'Paid Leave should exist');
        System.assert(types.contains('RTT'), 'RTT should be created');
    }

    @isTest
    static void testBatch_UserWithRTTOnly() {
        User u = TestDataFactory.createTestUser('batch3', 'US');
        Integer nextYear = Date.today().year() + 1;
        TestDataFactory.createRTTBalance(u.Id, 8, nextYear);

        Test.startTest();
        Database.executeBatch(new AnnualLeaveBalanceBatch(), 200);
        Test.stopTest();

        List<Leave_Balance__c> balances = [
            SELECT Leave_Type__c FROM Leave_Balance__c
            WHERE Employee__c = :u.Id AND Year__c = :nextYear
        ];
        Set<String> types = new Set<String>();
        for (Leave_Balance__c b : balances) types.add(b.Leave_Type__c);
        System.assert(types.contains('Paid Leave'), 'Paid Leave should be created');
        System.assert(types.contains('RTT'), 'RTT should exist');
    }

    @isTest
    static void testBatch_UserWithBothBalances() {
        User u = TestDataFactory.createTestUser('batch4', 'DE');
        Integer nextYear = Date.today().year() + 1;
        TestDataFactory.createPaidLeaveBalance(u.Id, 30, nextYear);
        TestDataFactory.createRTTBalance(u.Id, 8, nextYear);

        Test.startTest();
        Database.executeBatch(new AnnualLeaveBalanceBatch(), 200);
        Test.stopTest();

        List<Leave_Balance__c> balances = [
            SELECT Leave_Type__c FROM Leave_Balance__c
            WHERE Employee__c = :u.Id AND Year__c = :nextYear
        ];
        Integer count = 0;
        for (Leave_Balance__c b : balances) count++;
        System.assertEquals(2, count, 'No duplicate balances should be created');
    }
}