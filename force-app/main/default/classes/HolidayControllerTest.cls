@isTest
private class HolidayControllerTest {

    @TestSetup
    static void makeData() {
        TestDataFactory.createTestUser('HoliUser', 'FR');
        TestDataFactory.createHoliday('Jour de l\'An', Date.newInstance(2025, 1, 1), 'FR', 1.0);
    }

    @isTest
    static void testGetHolidays_Success() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'HoliUser' LIMIT 1];

        System.runAs(testUser) {
            Test.startTest();
            List<Holiday__c> holidays = HolidayController.getHolidays();
            Test.stopTest();
            
            System.assertEquals(1, holidays.size(), 'One holiday should be returned.');
            System.assertEquals('Jour de l\'An', holidays[0].Name, 'The holiday name should match.');
        }
    }

    @isTest
    static void testGetHolidays_Empty() {
        User testUser = TestDataFactory.createTestUser('emptyHol', 'DE');

        System.runAs(testUser) {
            Test.startTest();
            List<Holiday__c> holidays = HolidayController.getHolidays();
            Test.stopTest();
            
            System.assertEquals(0, holidays.size(), 'No holidays should be found for this country.');
        }
    }

    @isTest
    static void testGetHolidays_UserWithNoCountryCode() {
        String blankCode = ' ';
        User testUser = TestDataFactory.createTestUser('noCode', blankCode);

        System.runAs(testUser) {
            Test.startTest();
            List<Holiday__c> holidays = HolidayController.getHolidays();
            Test.stopTest();

            System.assertEquals(0, holidays.size(), 'List should be empty if user has no country code.');
        }
    }

    @isTest
    static void testGetHolidays_UserWithNullCountryCode() {
        User testUser = TestDataFactory.createTestUser('nullCode', null);

        System.runAs(testUser) {
            Test.startTest();
            List<Holiday__c> holidays = HolidayController.getHolidays();
            Test.stopTest();

            System.assertEquals(0, holidays.size(), 'List should be empty if user country code is null.');
        }
    }

}