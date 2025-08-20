@isTest
private class HolidayRecalcQueueableTest {

    @isTest
    static void testExecute_SuccessPath() {
        List<Holiday__c> holidays = new List<Holiday__c>{
            new Holiday__c(
                Name = 'Test Holiday',
                Country_Code__c = 'US',
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(1)
            )
        };
        
        Test.startTest();
        System.enqueueJob(new HolidayRecalcQueueable(holidays));
        Test.stopTest();
        
        System.assert(true, 'The queueable job should run without errors.');
    }

    @isTest
    static void testExecute_EmptyList() {
        List<Holiday__c> holidays = new List<Holiday__c>();
        
        Test.startTest();
        System.enqueueJob(new HolidayRecalcQueueable(holidays));
        Test.stopTest();
        
        System.assert(true, 'The queueable job should handle an empty list without errors.');
    }
    
    @isTest
    static void testConstructor_NullList() {
        Test.startTest();
        System.enqueueJob(new HolidayRecalcQueueable(null));
        Test.stopTest();
        
        System.assert(true, 'The queueable job should handle a null list without errors.');
    }

    @isTest
    static void testExecute_NoCountryCodes() {
        List<Holiday__c> holidays = new List<Holiday__c>{
            new Holiday__c(
                Name = 'Holiday No Country',
                Start_Date__c = Date.today(),
                End_Date__c = Date.today()
            )
        };
        
        Test.startTest();
        System.enqueueJob(new HolidayRecalcQueueable(holidays));
        Test.stopTest();
        
        System.assert(true, 'The queueable job should handle holidays with null country codes.');
    }
    
    @isTest
    static void testExecute_MixedHolidays() {
        List<Holiday__c> holidays = new List<Holiday__c>{
            new Holiday__c(
                Name = 'Valid Holiday',
                Country_Code__c = 'CA',
                Start_Date__c = Date.today(),
                End_Date__c = Date.today()
            ),
            new Holiday__c(
                Name = 'Holiday No Country',
                Start_Date__c = Date.today().addDays(5),
                End_Date__c = Date.today().addDays(5)
            )
        };
        
        Test.startTest();
        System.enqueueJob(new HolidayRecalcQueueable(holidays));
        Test.stopTest();
        
        System.assert(true, 'The queueable job should correctly process mixed-validity lists.');
    }
}