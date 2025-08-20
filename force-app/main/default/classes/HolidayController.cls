public with sharing class HolidayController {
    
    @AuraEnabled(cacheable=true)
    public static List<Holiday__c> getHolidays() {
        User currentUser = [SELECT Work_Country__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String userCountryCode = currentUser.Work_Country__c;
        
        if (String.isBlank(userCountryCode)) {
            return new List<Holiday__c>();
        }
        
        return [
            SELECT Id, Name, Start_Date__c, End_Date__c 
            FROM Holiday__c 
            WHERE Country_Code__c = :userCountryCode
        ];
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<Holiday__c> getAllHolidays() {
        return [
            SELECT Id, Name, Start_Date__c, End_Date__c, Description__c, Country_Code__c, Deduction_Value__c
            FROM Holiday__c
             ORDER BY Country_Code__c ASC, Start_Date__c ASC
        ];
    }
    
    
    
    @AuraEnabled
    public static void deleteHoliday(Id holidayId) {
        Holiday__c holidayToDelete = [
            SELECT Id, Start_Date__c, End_Date__c, Country_Code__c 
            FROM Holiday__c 
            WHERE Id = :holidayId 
            LIMIT 1
        ];
        
        List<Leave_Request__c> conflictingRequests = [
            SELECT Id 
            FROM Leave_Request__c 
            WHERE Status__c IN ('Approved', 'Cancellation Requested') 
              AND Requester__r.Work_Country__c = :holidayToDelete.Country_Code__c
              AND Start_Date__c <= :holidayToDelete.End_Date__c 
              AND End_Date__c >= :holidayToDelete.Start_Date__c
            LIMIT 1
        ];

        if (!conflictingRequests.isEmpty()) {
            throw new AuraHandledException('This holiday cannot be deleted because it overlaps with at least one approved leave request.');
        }
        
        delete holidayToDelete;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCountryOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        Schema.DescribeFieldResult fieldResult = User.Work_Country__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        
        for (Schema.PicklistEntry f: ple) {
            options.add(new Map<String, String>{
                'label' => f.getLabel(),
                'value' => f.getValue()
            });
        }
        
        return options;
    }
    
    
    @AuraEnabled
    public static void syncHolidaysForCountry(String countryCode, Integer year) {
        HolidayAPIService job = new HolidayAPIService(countryCode, year);
        System.enqueueJob(job);
    }
    
    @AuraEnabled
    public static String bulkDeleteHolidays(String countryCode, Integer year) {
        if (year == null) {
            throw new AuraHandledException('Please specify a year to delete.');
        }
        
        Date startDate = Date.newInstance(year, 1, 1);
        Date endDate = Date.newInstance(year, 12, 31);
        
        if (startDate > endDate) {
            return 'No holidays found for the specified year.';
        }
        
        String soqlQuery = 'SELECT Id, Name, Start_Date__c, End_Date__c, Country_Code__c FROM Holiday__c';
        List<String> conditions = new List<String>();
        
        if (String.isNotBlank(countryCode)) {
            conditions.add('Country_Code__c = :countryCode');
        }
        
        conditions.add('(Start_Date__c >= :startDate AND Start_Date__c <= :endDate)');
        soqlQuery += ' WHERE ' + String.join(conditions, ' AND ');
        
        List<Holiday__c> holidaysToPotentiallyDelete = Database.query(soqlQuery);
        
        if (holidaysToPotentiallyDelete.isEmpty()) {
            return 'No holidays found for the specified year and country.';
        }

        List<Leave_Request__c> conflictingRequests = [
            SELECT Id, Start_Date__c, End_Date__c, Requester__r.Work_Country__c 
            FROM Leave_Request__c 
            WHERE Status__c IN ('Approved', 'Cancellation Requested') 
              AND Requester__r.Work_Country__c = :countryCode
              AND CALENDAR_YEAR(Start_Date__c) = :year
        ];

        Set<Id> holidaysWithConflicts = new Set<Id>();
        List<String> conflictMessages = new List<String>();

        for (Holiday__c holiday : holidaysToPotentiallyDelete) {
            for (Leave_Request__c request : conflictingRequests) {
                if (holiday.Country_Code__c == request.Requester__r.Work_Country__c &&
                    holiday.Start_Date__c <= request.End_Date__c &&
                    holiday.End_Date__c >= request.Start_Date__c) {
                    
                    if (!holidaysWithConflicts.contains(holiday.Id)) {
                        holidaysWithConflicts.add(holiday.Id);
                        conflictMessages.add(holiday.Name + ' (' + holiday.Start_Date__c.format() + ')');
                    }
                }
            }
        }

        List<Holiday__c> holidaysToDelete = new List<Holiday__c>();
        for (Holiday__c h : holidaysToPotentiallyDelete) {
            if (!holidaysWithConflicts.contains(h.Id)) {
                holidaysToDelete.add(h);
            }
        }
        
        Integer successfulDeletes = 0;
        if (!holidaysToDelete.isEmpty()) {
            Database.DeleteResult[] deleteResults = Database.delete(holidaysToDelete, false);
            for(Database.DeleteResult dr : deleteResults){
                if(dr.isSuccess()){
                    successfulDeletes++;
                }
            }
        }

        String successMessage = successfulDeletes + ' holiday(s) were successfully deleted.';
        if (!conflictMessages.isEmpty()) {
            String errorMessage = ' The following holidays could not be deleted because they overlap with approved leave requests: ' + String.join(conflictMessages, ', ') + '.';
            return successMessage + errorMessage;
        }
        
        return successMessage;
    }
    
    
}