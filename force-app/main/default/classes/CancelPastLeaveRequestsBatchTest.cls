@isTest
public class CancelPastLeaveRequestsBatchTest {
    @isTest
    static void testBatchExecution() {
        User u = TestDataFactory.createTestUser('batch', 'MA');
        Leave_Balance__c paidBalance = TestDataFactory.createLeaveBalance(u.Id, 'Paid Leave', 30);
        Leave_Balance__c rttBalance = TestDataFactory.createLeaveBalance(u.Id, 'RTT', 10);

        List<Leave_Request__c> requests = new List<Leave_Request__c>{
            TestDataFactory.createLeaveRequest(u.Id, 'Paid Leave', Date.today().addDays(-5), Date.today().addDays(-5), paidBalance.Id, 'Cancellation Requested'),
            TestDataFactory.createLeaveRequest(u.Id, 'Paid Leave', Date.today().addDays(-10), Date.today().addDays(-10), paidBalance.Id, 'Pending Manager Approval'),
            TestDataFactory.createLeaveRequest(u.Id, 'RTT', Date.today().addDays(-15), Date.today().addDays(-15), rttBalance.Id, 'Pending Manager Approval'),
            TestDataFactory.createLeaveRequest(u.Id, 'Paid Leave', Date.today().addDays(-20), Date.today().addDays(-20), paidBalance.Id, 'Rejected'),
            TestDataFactory.createLeaveRequest(u.Id, 'Paid Leave', Date.today().addDays(-25), Date.today().addDays(-25), paidBalance.Id, 'Approved'),
            TestDataFactory.createLeaveRequest(u.Id, 'RTT', Date.today().addDays(-30), Date.today().addDays(-30), rttBalance.Id, 'Approved'),
            TestDataFactory.createLeaveRequest(u.Id, 'Sick Leave', Date.today().addDays(-7), Date.today().addDays(-7), null, 'Approved')
        };

        Test.startTest();
        CancelPastLeaveRequestsBatch batch = new CancelPastLeaveRequestsBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Leave_Request__c> updatedRequests = [
            SELECT Id, Status__c, Leave_Type__c
            FROM Leave_Request__c
            WHERE Id IN :requests
        ];

        for (Leave_Request__c req : updatedRequests) {
            Leave_Request__c original = null;
            for (Leave_Request__c r : requests) {
                if (r.Id == req.Id) {
                    original = r;
                    break;
                }
            }
            if (req.Leave_Type__c == 'Sick Leave') {
                System.assertEquals('Approved', req.Status__c, 'Sick Leave should not be modified by the batch');
            }
            else if (original != null && (original.Status__c == 'Rejected' || original.Status__c == 'Approved')) {
                System.assertEquals(original.Status__c, req.Status__c, 'Rejected/Approved should not be modified');
            }
            else if (original != null && original.Status__c == 'Cancellation Requested') {
                System.assertEquals('Approved', req.Status__c, 'Cancellation Requested should become Approved');
            }
            else if (original != null) {
                System.assertEquals('Cancelled', req.Status__c, 'Other statuses should become Cancelled');
            }
        }
    }
}