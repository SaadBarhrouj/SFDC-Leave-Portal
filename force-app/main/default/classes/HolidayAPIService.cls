public class HolidayAPIService {

    @future(callout=true)
    public static void fetchHolidaysForCountry(String countryCode, Integer year) {
        String endpoint = 'https://date.nager.at/api/v3/PublicHolidays/' + year + '/' + countryCode;
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200) {
                
                List<Object> results = (List<Object>) JSON.deserializeUntyped(res.getBody());
                List<Holiday__c> holidaysToUpsert = new List<Holiday__c>();
                
                for (Object item : results) {
                    Map<String, Object> holidayMap = (Map<String, Object>) item;
                    
                    String dateString = (String) holidayMap.get('date');
                    Date holidayDate = Date.valueOf(dateString); 
                    String localName = (String) holidayMap.get('localName');
                    String country = (String) holidayMap.get('countryCode');
                    
                    holidaysToUpsert.add(new Holiday__c(
                        Name = localName,
                        Holiday_Date__c = holidayDate,
                        Country_Code__c = country,
                        Deduction_Value__c = 1.0,
                        Unique_ID__c = holidayDate.year() +'-'+ holidayDate.month() +'-'+ holidayDate.day() +'-'+ country
                    ));
                }

                if (!holidaysToUpsert.isEmpty()) {
                    Database.upsert(holidaysToUpsert, Holiday__c.Fields.Unique_ID__c, false);
                    System.debug(holidaysToUpsert.size() + ' jours fériés ont été synchronisés pour ' + countryCode);
                }
            }
        } catch (Exception e) {
            System.debug('Error syncing holidays for ' + countryCode + ': ' + e.getMessage());
        }
    }
}