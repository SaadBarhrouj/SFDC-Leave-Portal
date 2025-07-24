public class ScheduledHolidaySync implements Schedulable {

    public void execute(SchedulableContext sc) {
        Integer nextYear = Date.today().year() + 1;
        Set<String> uniqueCountryCodes = new Set<String>();

        for (AggregateResult ar : [SELECT Country_Code__c FROM Holiday__c GROUP BY Country_Code__c]) {
            uniqueCountryCodes.add((String)ar.get('Country_Code__c'));
        }

        for (String countryCode : uniqueCountryCodes) {
            if (String.isNotBlank(countryCode)) {
                HolidayAPIService job = new HolidayAPIService(countryCode, nextYear);
                System.enqueueJob(job);
            }
        }
    }
}