@isTest
public class MyBalanceHistoryExportControllerTest {
    @isTest
    static void testWithAllParams() {
        User testUser = TestDataFactory.createTestUser('myuser', 'US');
        System.runAs(testUser) {
            Date movementDate = Date.today();
            Leave_Balance_History__c hist = TestDataFactory.createCorrectionHistory(
                testUser.Id, testUser.Name, movementDate, 'Paid Leave',
                'Manual', 'Test justification', -5, 10
            );

            Test.startTest();
            PageReference pageRef = new PageReference('/apex/MyBalanceHistoryExport');
            Test.setCurrentPage(pageRef);
            ApexPages.currentPage().getParameters().put('type', 'Paid Leave');
            ApexPages.currentPage().getParameters().put('movementType', 'Correction');
            ApexPages.currentPage().getParameters().put('start', String.valueOf(movementDate));
            ApexPages.currentPage().getParameters().put('end', String.valueOf(movementDate));
            MyBalanceHistoryExportController ctrl = new MyBalanceHistoryExportController();
            Test.stopTest();
            System.assertNotEquals(null, ctrl.histories);
        }
    }

    @isTest
    static void testWithNoParams() {
        User testUser = TestDataFactory.createTestUser('myuser2', 'US');
        System.runAs(testUser) {
            Date movementDate = Date.today();
            Leave_Balance_History__c hist = TestDataFactory.createCorrectionHistory(
                testUser.Id, testUser.Name, movementDate, 'RTT',
                'Manual', 'Test justification', -2, 8
            );

            Test.startTest();
            PageReference pageRef = new PageReference('/apex/MyBalanceHistoryExport');
            Test.setCurrentPage(pageRef);
            MyBalanceHistoryExportController ctrl = new MyBalanceHistoryExportController();
            Test.stopTest();
            System.assertNotEquals(null, ctrl.histories);
        }
    }

    @isTest
    static void testWithEmptyParams() {
        User testUser = TestDataFactory.createTestUser('myuser3', 'US');
        System.runAs(testUser) {
            Date movementDate = Date.today();
            Leave_Balance_History__c hist = TestDataFactory.createCorrectionHistory(
                testUser.Id, testUser.Name, movementDate, 'RTT',
                'Manual', 'Test justification', -1, 7
            );

            Test.startTest();
            PageReference pageRef = new PageReference('/apex/MyBalanceHistoryExport');
            Test.setCurrentPage(pageRef);
            ApexPages.currentPage().getParameters().put('type', '');
            ApexPages.currentPage().getParameters().put('movementType', '');
            ApexPages.currentPage().getParameters().put('start', String.valueOf(movementDate));
            ApexPages.currentPage().getParameters().put('end', String.valueOf(movementDate));
            MyBalanceHistoryExportController ctrl = new MyBalanceHistoryExportController();
            Test.stopTest();
            System.assertNotEquals(null, ctrl.histories);
        }
    }
}