@isTest
public class HolidayAPIServiceTest {

    @isTest
    static void testFetchHolidays_Success() {
        String successJson = '[{"date": "2025-01-01", "localName": "Jour de l\'An", "countryCode": "FR"}]';
        System.Test.setMock(HttpCalloutMock.class, new HolidayAPIMock(200, successJson));

        System.Test.startTest();
        HolidayAPIService.fetchHolidaysForCountry('FR', 2025);
        System.Test.stopTest();

        List<Holiday__c> createdHolidays = [SELECT Name, Country_Code__c FROM Holiday__c];
        System.assertEquals(1, createdHolidays.size());
        System.assertEquals('FR', createdHolidays[0].Country_Code__c);
    }

    @isTest
    static void testFetchHolidays_Failure() {
        System.Test.setMock(HttpCalloutMock.class, new HolidayAPIMock(500, 'Server Error'));

        System.Test.startTest();
        HolidayAPIService.fetchHolidaysForCountry('DE', 2025);
        System.Test.stopTest();

        List<Holiday__c> createdHolidays = [SELECT Id FROM Holiday__c];
        System.assertEquals(0, createdHolidays.size());
    }
}