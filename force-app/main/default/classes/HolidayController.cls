public with sharing class HolidayController {

    @AuraEnabled(cacheable=true)
    public static List<Holiday__c> getHolidays() {
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
    }


     @AuraEnabled(cacheable=true)
    public static List<Holiday__c> getAllHolidays() {
        return [
            SELECT Id, Name, Holiday_Date__c, Description__c, Country_Code__c, Deduction_Value__c
            FROM Holiday__c
            ORDER BY Holiday_Date__c DESC
        ];
    }

     @AuraEnabled
    public static void deleteHoliday(Id holidayId) {
        try {
            Holiday__c holidayToDelete = [SELECT Id FROM Holiday__c WHERE Id = :holidayId];
            delete holidayToDelete;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}