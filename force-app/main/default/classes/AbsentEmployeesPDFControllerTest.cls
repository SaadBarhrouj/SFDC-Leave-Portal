@isTest
public class AbsentEmployeesPDFControllerTest {
    @isTest
    static void testControllerWithAllParams() {
        User testUser = TestDataFactory.createTestUser('absent', 'US');
        System.runAs(testUser) {
            Leave_Request__c req = TestDataFactory.createSickLeaveApprovedForToday(testUser.Id);
            Test.startTest();
            PageReference pageRef = new PageReference('/apex/HrAbsencesExport');
            Test.setCurrentPage(pageRef);
            ApexPages.currentPage().getParameters().put('employeeName', testUser.Name);
            ApexPages.currentPage().getParameters().put('leaveType', 'Sick Leave');
            AbsentEmployeesPDFController ctrl = new AbsentEmployeesPDFController();
            Test.stopTest();
            System.assertNotEquals(null, ctrl.absences, 'Absences should not be null');
        }
    }

    @isTest
    static void testControllerWithNoParams() {
        User testUser = TestDataFactory.createTestUser('absent2', 'US');
        System.runAs(testUser) {
            Leave_Request__c req = TestDataFactory.createSickLeaveApprovedForToday(testUser.Id);
            Test.startTest();
            PageReference pageRef = new PageReference('/apex/HrAbsencesExport');
            Test.setCurrentPage(pageRef);
            AbsentEmployeesPDFController ctrl = new AbsentEmployeesPDFController();
            Test.stopTest();
            System.assertNotEquals(null, ctrl.absences, 'Absences should not be null');
        }
    }

    @isTest
    static void testControllerWithOnlyEmployeeName() {
        User testUser = TestDataFactory.createTestUser('absent3', 'US');
        System.runAs(testUser) {
            Leave_Request__c req = TestDataFactory.createSickLeaveApprovedForToday(testUser.Id);
            Test.startTest();
            PageReference pageRef = new PageReference('/apex/HrAbsencesExport');
            Test.setCurrentPage(pageRef);
            ApexPages.currentPage().getParameters().put('employeeName', testUser.Name);
            AbsentEmployeesPDFController ctrl = new AbsentEmployeesPDFController();
            Test.stopTest();
            System.assertNotEquals(null, ctrl.absences, 'Absences should not be null');
        }
    }

    @isTest
    static void testControllerWithOnlyLeaveType() {
        User testUser = TestDataFactory.createTestUser('absent4', 'US');
        System.runAs(testUser) {
            Leave_Request__c req = TestDataFactory.createSickLeaveApprovedForToday(testUser.Id);
            Test.startTest();
            PageReference pageRef = new PageReference('/apex/HrAbsencesExport');
            Test.setCurrentPage(pageRef);
            ApexPages.currentPage().getParameters().put('leaveType', 'Sick Leave');
            AbsentEmployeesPDFController ctrl = new AbsentEmployeesPDFController();
            Test.stopTest();
            System.assertNotEquals(null, ctrl.absences, 'Absences should not be null');
        }
    }

    @isTest
    static void testControllerWithEmptyParams() {
        User testUser = TestDataFactory.createTestUser('absent5', 'US');
        System.runAs(testUser) {
            Leave_Request__c req = TestDataFactory.createSickLeaveApprovedForToday(testUser.Id);
            Test.startTest();
            PageReference pageRef = new PageReference('/apex/HrAbsencesExport');
            Test.setCurrentPage(pageRef);
            ApexPages.currentPage().getParameters().put('employeeName', '');
            ApexPages.currentPage().getParameters().put('leaveType', '');
            AbsentEmployeesPDFController ctrl = new AbsentEmployeesPDFController();
            Test.stopTest();
            System.assertNotEquals(null, ctrl.absences, 'Absences should not be null');
        }
    }
}