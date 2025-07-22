@isTest
public class HolidayAutomationTestssss {

    @isTest
    static void testQueueable_Success() {
        String successJson = '[{"date": "2025-01-01", "localName": "New Year\'s Day", "countryCode": "FR"}]';
        System.Test.setMock(HttpCalloutMock.class, new HolidayAPIMock(200, successJson));

        Test.startTest();
        System.enqueueJob(new HolidayAPIService('FR', 2025));
        Test.stopTest(); 

        List<Holiday__c> createdHolidays = [SELECT Name, Country_Code__c FROM Holiday__c];
        System.assertEquals(1, createdHolidays.size(), 'A holiday record should have been created.');
        System.assertEquals('FR', createdHolidays[0].Country_Code__c, 'The country code should be FR.');
    }

    @isTest
    static void testQueueable_Failure() {
        System.Test.setMock(HttpCalloutMock.class, new HolidayAPIMock(500, 'Server Error'));

        Test.startTest();
        System.enqueueJob(new HolidayAPIService('DE', 2025));
        Test.stopTest();

        List<Holiday__c> createdHolidays = [SELECT Id FROM Holiday__c];
        System.assertEquals(0, createdHolidays.size(), 'No holiday records should be created on API failure.');
    }

    @isTest
    static void testInvocableMethod_Success() {
        String successJson = '[{"date": "2025-12-25", "localName": "Christmas Day", "countryCode": "US"}]';
        System.Test.setMock(HttpCalloutMock.class, new HolidayAPIMock(200, successJson));

        HolidayAPIService.Request flowRequest = new HolidayAPIService.Request();
        flowRequest.countryCode = 'US';
        flowRequest.year = 2025;

        List<HolidayAPIService.Request> requests = new List<HolidayAPIService.Request>{ flowRequest };

        Test.startTest();
        HolidayAPIService.fetchHolidaysFromFlow(requests);
        Test.stopTest();

        List<Holiday__c> createdHolidays = [SELECT Name, Country_Code__c FROM Holiday__c];
        System.assertEquals(1, createdHolidays.size(), 'The invocable method should create a holiday.');
        System.assertEquals('US', createdHolidays[0].Country_Code__c, 'The country code should be US.');
    }
    
    @isTest
    static void testSchedulable_SyncsNextYear() {
        insert new Holiday__c(Name = 'Old Holiday', Country_Code__c = 'GB', Holiday_Date__c = Date.newInstance(Date.today().year(), 1, 1), Unique_ID__c = 'test1');

        Integer nextYear = Date.today().year() + 1; 
        String successJson = '[{"date": "' + nextYear + '-05-26", "localName": "Spring Bank Holiday", "countryCode": "GB"}]';
        System.Test.setMock(HttpCalloutMock.class, new HolidayAPIMock(200, successJson));

        Test.startTest();
        ScheduledHolidaySync sched = new ScheduledHolidaySync();
        sched.execute(null);
        Test.stopTest();

        List<Holiday__c> nextYearHolidays = [SELECT Id FROM Holiday__c WHERE CALENDAR_YEAR(Holiday_Date__c) = :nextYear];
        System.assertEquals(1, nextYearHolidays.size(), 'The schedulable class should create a holiday for the next year.');
    }
}
