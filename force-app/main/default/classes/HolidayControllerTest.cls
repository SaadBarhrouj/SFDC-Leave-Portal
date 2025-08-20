@isTest
private class HolidayControllerTest {

    @TestSetup
    static void setupData() {
        TestDataFactory.createTestUser('HoliUser', 'FR');
        TestDataFactory.createTestUser('HoliUsDE', 'DE');
        TestDataFactory.createHoliday('Jour de l\'An', Date.newInstance(2025, 1, 1), 'FR', 1.0);
        TestDataFactory.createHoliday('Tag der Einheit', Date.newInstance(2025, 10, 3), 'DE', 1.0);
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
        User testUser = TestDataFactory.createTestUser('emptyHol', 'ES');
        System.runAs(testUser) {
            Test.startTest();
            List<Holiday__c> holidays = HolidayController.getHolidays();
            Test.stopTest();
            System.assertEquals(0, holidays.size(), 'No holidays should be found for this country.');
        }
    }

    @isTest
    static void testGetHolidays_NoCountry() {
        User testUser = TestDataFactory.createTestUser('noCountr', null);
        System.runAs(testUser) {
            Test.startTest();
            List<Holiday__c> holidays = HolidayController.getHolidays();
            Test.stopTest();
            System.assertEquals(0, holidays.size(), 'Should return empty list if user has no country');
        }
    }

    @isTest
    static void testGetAllHolidays() {
        Test.startTest();
        List<Holiday__c> holidays = HolidayController.getAllHolidays();
        Test.stopTest();
        System.assert(holidays.size() >= 2, 'Should return at least two holidays.');
    }

    @isTest
    static void testDeleteHoliday_NoConflict() {
        Holiday__c holiday = TestDataFactory.createHoliday('ToDelete', Date.newInstance(2025, 5, 1), 'FR', 1.0);
        Test.startTest();
        HolidayController.deleteHoliday(holiday.Id);
        Test.stopTest();
        Holiday__c[] deleted = [SELECT Id FROM Holiday__c WHERE Id = :holiday.Id];
        System.assertEquals(0, deleted.size(), 'Holiday should be deleted.');
    }

    @isTest
    static void testDeleteHoliday_WithConflict() {
        User user = TestDataFactory.createTestUser('confuser', 'FR');
        Holiday__c holiday = TestDataFactory.createHoliday('ConflictHoliday', Date.newInstance(2025, 8, 15), 'FR', 1.0);
        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(user.Id, 'Paid Leave', 10);
        Leave_Request__c req = TestDataFactory.createLeaveRequest(
            user.Id, 'Paid Leave', holiday.Start_Date__c, holiday.End_Date__c, balance.Id, 'Approved'
        );
        Boolean errorThrown = false;
        Test.startTest();
        try {
            HolidayController.deleteHoliday(holiday.Id);
        } catch (AuraHandledException e) {
            errorThrown = true;
        }
        Test.stopTest();
        System.assert(errorThrown, 'An AuraHandledException should have been thrown due to conflict');
    }

    @isTest
    static void testGetCountryOptions() {
        Test.startTest();
        List<Map<String, String>> options = HolidayController.getCountryOptions();
        Test.stopTest();
        System.assert(!options.isEmpty(), 'Country options should not be empty');
    }

    @isTest
    static void testBulkDeleteHolidays_NoYear() {
        Boolean errorThrown = false;
        Test.startTest();
        try {
            HolidayController.bulkDeleteHolidays('FR', null);
        } catch (AuraHandledException e) {
            errorThrown = true;
        }
        Test.stopTest();
        System.assert(errorThrown, 'An AuraHandledException should have been thrown for missing year');
    }

    @isTest
    static void testBulkDeleteHolidays_Success() {
        Holiday__c holiday = TestDataFactory.createHoliday('ToBulkDelete', Date.newInstance(2026, 7, 14), 'FR', 1.0);
        Test.startTest();
        String result = HolidayController.bulkDeleteHolidays('FR', 2026);
        Test.stopTest();
        System.assert(result.contains('successfully deleted'), 'Should confirm successful deletion');
        List<Holiday__c> deleted = [SELECT Id FROM Holiday__c WHERE Id = :holiday.Id];
        System.assertEquals(0, deleted.size(), 'Holiday should be deleted from database');
    }

    @isTest
    static void testBulkDeleteHolidays_NoHolidaysFound() {
        Test.startTest();
        String result = HolidayController.bulkDeleteHolidays('XX', 2099); 
        Test.stopTest();
        System.assert(result.contains('No holidays found for the specified year and country.'), 'Should return no holidays found');
    }
}