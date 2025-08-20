@isTest
public class LeaveBalanceTriggerTest {

    @isTest
    static void testAfterInsert_CreatesHistory() {
        User user = TestDataFactory.createTestUser('baluser', 'FR');
        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(user.Id, 'Paid Leave', 10);

        List<Leave_Balance_History__c> histories = [
            SELECT Id, Employee__c, Leave_Type__c, Movement_Type__c, Number_of_Days__c, Source_of_Movement__c
            FROM Leave_Balance_History__c
            WHERE Employee__c = :user.Id AND Leave_Type__c = 'Paid Leave'
        ];
        System.assertEquals(1, histories.size(), 'A history record must be created on insert');
        System.assertEquals('Accrual', histories[0].Movement_Type__c, 'The type must be Accrual');
        System.assert(histories[0].Source_of_Movement__c.contains('Balance created by'), 'The source must contain "Balance created by"');
    }

    @isTest
    static void testAfterInsert_NoHistoryIfZero() {
        User user = TestDataFactory.createTestUser('baluser4', 'FR');
        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(user.Id, 'Paid Leave', 0);
        List<Leave_Balance_History__c> histories = [
            SELECT Id FROM Leave_Balance_History__c WHERE Employee__c = :user.Id AND Leave_Type__c = 'Paid Leave'
        ];
        System.assertEquals(0, histories.size(), 'No history should be created if Allocated_Days__c is 0');
    }

    @isTest
    static void testAfterInsert_NoHistoryIfNegative() {
        User user = TestDataFactory.createTestUser('baluser5', 'FR');
        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(user.Id, 'Paid Leave', -5);
        List<Leave_Balance_History__c> histories = [
            SELECT Id FROM Leave_Balance_History__c WHERE Employee__c = :user.Id AND Leave_Type__c = 'Paid Leave'
        ];
        System.assertEquals(0, histories.size(), 'No history should be created if Allocated_Days__c is negative');
    }

    @isTest
    static void testBeforeDelete_WithNoLinkedRequests() {
        User user = TestDataFactory.createTestUser('baluser2', 'FR');
        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(user.Id, 'Paid Leave', 5);

        Test.startTest();
        delete balance; 
        Test.stopTest();

        List<Leave_Balance__c> check = [SELECT Id FROM Leave_Balance__c WHERE Id = :balance.Id];
        System.assertEquals(0, check.size(), 'The balance must be deleted');
    }

    @isTest
    static void testBeforeDelete_WithLinkedRequests() {
        User user = TestDataFactory.createTestUser('baluser3', 'FR');
        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(user.Id, 'Paid Leave', 8);

        Leave_Request__c req = TestDataFactory.createLeaveRequest(
            user.Id, 'Paid Leave', Date.today().addDays(1), Date.today().addDays(2), balance.Id, 'Approved'
        );

        Boolean errorThrown = false;
        Test.startTest();
        try {
            delete balance;
        } catch (DmlException e) {
            errorThrown = true;
        }
        Test.stopTest();
        System.assert(errorThrown, 'An error must be thrown if a leave request is linked');
    }
      
    @isTest
    static void testBeforeDelete_NoId() {
        Leave_Balance__c fakeBalance = new Leave_Balance__c();
        Boolean errorThrown = false;
        Test.startTest();
        try {
            delete fakeBalance;
        } catch (Exception e) {
            errorThrown = true;
        }
        Test.stopTest();
        System.assert(errorThrown, 'An exception should be thrown when deleting a record with no Id');
    }
}