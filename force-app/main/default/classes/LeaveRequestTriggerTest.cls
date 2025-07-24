@isTest
private class LeaveRequestTriggerTest {

    @isTest
    static void testLeaveRequestTrigger_Insert() {
        User testUser = TestDataFactory.createTestUser('tstuser', 'US');
        Leave_Balance__c leaveBalance = TestDataFactory.createLeaveBalance(testUser.Id, 'Vacation', 20);

        Date startDate = System.today().addDays(10); 
        Date endDate = startDate.addDays(4);

        Integer expectedDays = 0;
        Date d = startDate;
        while (d <= endDate) {
            Integer dayOfWeek = Integer.valueOf(Datetime.newInstance(d, Time.newInstance(0,0,0,0)).format('u'));
            if (dayOfWeek < 6) {
                expectedDays++;
            }
            d = d.addDays(1);
        }

        Leave_Request__c leaveRequest = TestDataFactory.createLeaveRequest(
            testUser.Id, 'Vacation', 
            startDate, 
            endDate, 
            leaveBalance.Id
        );

        Test.startTest();
        insert leaveRequest;
        Test.stopTest();

        Leave_Request__c updatedLeaveRequest = [
            SELECT Number_of_Days_Requested__c
            FROM Leave_Request__c 
            WHERE Id = :leaveRequest.Id
        ];

        System.assertEquals(expectedDays, updatedLeaveRequest.Number_of_Days_Requested__c, 'Le nombre de jours devrait être calculé dynamiquement par le trigger.');
    }

    @isTest
    static void testLeaveRequestTrigger_Update() {
        User testUser = TestDataFactory.createTestUser('tstuser2', 'US');
        Leave_Balance__c leaveBalance = TestDataFactory.createLeaveBalance(testUser.Id, 'Vacation', 20);

        Date startDate = System.today().addDays(20);
        Date endDate = System.today().addDays(24);

        Leave_Request__c leaveRequest = TestDataFactory.createLeaveRequest(
            testUser.Id, 'Vacation', 
            startDate, 
            endDate, 
            leaveBalance.Id
        );
        insert leaveRequest;

        Date newEndDate = endDate.addDays(3);
        leaveRequest.End_Date__c = newEndDate;

        Integer expectedDays = 0;
        Date d = startDate;
        while (d <= newEndDate) {
            Integer dayOfWeek = Integer.valueOf(Datetime.newInstance(d, Time.newInstance(0,0,0,0)).format('u'));
            if (dayOfWeek < 6) {
                expectedDays++;
            }
            d = d.addDays(1);
        }
    
        Test.startTest();
        update leaveRequest;
        Test.stopTest();

        Leave_Request__c updatedLeaveRequest = [
            SELECT Number_of_Days_Requested__c
            FROM Leave_Request__c 
            WHERE Id = :leaveRequest.Id
        ];

        System.assertEquals(expectedDays, updatedLeaveRequest.Number_of_Days_Requested__c, 'Le nombre de jours devrait être recalculé par le trigger lors de la mise à jour.');
    }
}