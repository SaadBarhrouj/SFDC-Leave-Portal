@isTest
public class HRAllBalancesHistoryExportControllerTest {
    @isTest
    static void testWithAllParams() {
        User testUser = TestDataFactory.createTestUser('hruser', 'US');
        System.runAs(testUser) {
            Date movementDate = Date.today();
            Leave_Balance_History__c hist = TestDataFactory.createCorrectionHistory(
                testUser.Id, testUser.Name, movementDate, 'Paid Leave',
                'Manual', 'Test justification', -5, 10
            );

            Test.startTest();
            PageReference pageRef = new PageReference('/apex/HRAllBalancesHistoryExport');
            Test.setCurrentPage(pageRef);
            ApexPages.currentPage().getParameters().put('employee', testUser.Name);
            ApexPages.currentPage().getParameters().put('type', 'Paid Leave');
            ApexPages.currentPage().getParameters().put('movementType', 'Correction');
            ApexPages.currentPage().getParameters().put('start', String.valueOf(movementDate));
            ApexPages.currentPage().getParameters().put('end', String.valueOf(movementDate));
            HRAllBalancesHistoryExportController ctrl = new HRAllBalancesHistoryExportController();
            Test.stopTest();
            System.assertNotEquals(null, ctrl.histories);
        }
    }

    @isTest
    static void testWithNoParams() {
        User testUser = TestDataFactory.createTestUser('hruser2', 'US');
        System.runAs(testUser) {
            Date movementDate = Date.today();
            Leave_Balance_History__c hist = TestDataFactory.createCorrectionHistory(
                testUser.Id, testUser.Name, movementDate, 'RTT',
                'Manual', 'Test justification', -2, 8
            );

            Test.startTest();
            PageReference pageRef = new PageReference('/apex/HRAllBalancesHistoryExport');
            Test.setCurrentPage(pageRef);
            HRAllBalancesHistoryExportController ctrl = new HRAllBalancesHistoryExportController();
            Test.stopTest();
            System.assertNotEquals(null, ctrl.histories);
        }
    }

    @isTest
    static void testWithEmptyParams() {
        User testUser = TestDataFactory.createTestUser('hruser3', 'US');
        System.runAs(testUser) {
            Date movementDate = Date.today();
            Leave_Balance_History__c hist = TestDataFactory.createCorrectionHistory(
                testUser.Id, testUser.Name, movementDate, 'RTT',
                'Manual', 'Test justification', -1, 7
            );

            Test.startTest();
            PageReference pageRef = new PageReference('/apex/HRAllBalancesHistoryExport');
            Test.setCurrentPage(pageRef);
            ApexPages.currentPage().getParameters().put('employee', '');
            ApexPages.currentPage().getParameters().put('type', '');
            ApexPages.currentPage().getParameters().put('movementType', '');
            ApexPages.currentPage().getParameters().put('start', String.valueOf(movementDate));
            ApexPages.currentPage().getParameters().put('end', String.valueOf(movementDate));
            HRAllBalancesHistoryExportController ctrl = new HRAllBalancesHistoryExportController();
            Test.stopTest();
            System.assertNotEquals(null, ctrl.histories);
        }
    }
}