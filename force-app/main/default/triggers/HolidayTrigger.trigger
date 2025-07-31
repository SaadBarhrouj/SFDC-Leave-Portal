trigger HolidayTrigger on Holiday__c (before insert) {
    for (Holiday__c holiday : Trigger.new) {
        if (String.isBlank(holiday.Unique_ID__c)) {
            
            if (holiday.Holiday_Date__c != null && String.isNotBlank(holiday.Country_Code__c)) {
                
                Date holidayDate = holiday.Holiday_Date__c;
                String countryCode = holiday.Country_Code__c;
                
                String uniqueId = holidayDate.year() + '-' + holidayDate.month() + '-' + holidayDate.day() + '-' + countryCode;
                
                holiday.Unique_ID__c = uniqueId;
            }
        }
    }
}