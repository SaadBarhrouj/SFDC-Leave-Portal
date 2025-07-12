public with sharing class HolidayController {

    @AuraEnabled(cacheable=true)
    public static List<Holiday__c> getHolidays() {
        try {
            User currentUser = [SELECT Country_Code__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            String userCountryCode = currentUser.Country_Code__c;

            if (String.isBlank(userCountryCode)) {
                return new List<Holiday__c>();
            }

            return [
                SELECT Id, Name, Holiday_Date__c 
                FROM Holiday__c 
                WHERE Country_Code__c = :userCountryCode
            ];

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving holidays: ' + e.getMessage());
        }
    }
}