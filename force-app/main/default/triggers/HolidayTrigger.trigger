trigger HolidayTrigger on Holiday__c (before insert, before update, after insert, after update, after delete) {
    
    if (Trigger.isInsert || Trigger.isUpdate) {
        for (Holiday__c holiday : Trigger.new) {
            if (holiday.End_Date__c == null) {
                holiday.End_Date__c = holiday.Start_Date__c;
            }
            
            if (String.isBlank(holiday.Unique_ID__c)) {
                if (holiday.Start_Date__c != null && String.isNotBlank(holiday.Country_Code__c)) {
                    Date holidayDate = holiday.Start_Date__c;
                    String countryCode = holiday.Country_Code__c;
                    String uniqueId = holidayDate.year() + '-' + holidayDate.month() + '-' + holidayDate.day() + '-' + countryCode;
                    holiday.Unique_ID__c = uniqueId;
                }
            }
        }
    }

    if (Trigger.isAfter) {
        if (Trigger.isDelete) {
            System.enqueueJob(new HolidayRecalcQueueable(Trigger.old));
        } else {
            LeaveRequestUtils.recalculateAffectedRequests(Trigger.newMap.keySet());
        }
    }
}