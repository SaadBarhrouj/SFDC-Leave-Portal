public with sharing class HolidayController {

    @AuraEnabled(cacheable=true)
    public static List<Holiday__c> getHolidays() {
        User currentUser = [SELECT Work_Country__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String userCountryCode = currentUser.Work_Country__c;

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
             ORDER BY Country_Code__c ASC, Holiday_Date__c ASC
        ];
    }



        @AuraEnabled
        public static void deleteHoliday(Id holidayId) {
            Holiday__c holidayToDelete = [SELECT Id, Holiday_Date__c FROM Holiday__c WHERE Id = :holidayId LIMIT 1];

            if (holidayToDelete.Holiday_Date__c <= Date.today()) {
                throw new AuraHandledException('Deletion is only allowed for future holidays to protect historical leave data.');
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
        public static Integer bulkDeleteHolidays(String countryCode, Integer year) {
            if (year == null) {
                throw new AuraHandledException('Please specify a year to delete.');
            }

            Date startDate;
            Date endDate = Date.newInstance(year, 12, 31);
            Date today = Date.today();

            if (year < today.year()) {
                startDate = Date.newInstance(year, 1, 1);
            } else if (year == today.year()) {
                startDate = today.addDays(1);
            } else {
                startDate = Date.newInstance(year, 1, 1);
            }

            if (startDate > endDate) {
                return 0;
            }
            
            String soqlQuery = 'SELECT Id FROM Holiday__c';
            List<String> conditions = new List<String>();

            if (String.isNotBlank(countryCode)) {
                conditions.add('Country_Code__c = :countryCode');
            }
            
            conditions.add('Holiday_Date__c >= :startDate AND Holiday_Date__c <= :endDate');
            soqlQuery += ' WHERE ' + String.join(conditions, ' AND ');

            List<Holiday__c> holidaysToDelete = Database.query(soqlQuery);

            if (!holidaysToDelete.isEmpty()) {
                delete holidaysToDelete;
                return holidaysToDelete.size();
            }
            
            return 0;
        }


}