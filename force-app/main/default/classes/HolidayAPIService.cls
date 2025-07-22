public class HolidayAPIService implements Queueable, Database.AllowsCallouts {

    private String countryCode;
    private Integer year;

    public HolidayAPIService(String countryCode, Integer year) {
        this.countryCode = countryCode;
        this.year = year;
    }

    public void execute(QueueableContext context) {
        String endpoint = 'callout:Nager_API/api/v3/PublicHolidays/' + this.year + '/' + this.countryCode;
        System.debug('HolidayAPIService: Endpoint = ' + endpoint);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');

        try {
            HttpResponse res = new Http().send(req);
            System.debug('HolidayAPIService: Status code = ' + res.getStatusCode());
            System.debug('HolidayAPIService: Response body = ' + res.getBody());

            if (res.getStatusCode() == 200) {
                List<Object> results = (List<Object>) JSON.deserializeUntyped(res.getBody());
                System.debug('HolidayAPIService: Results size = ' + results.size());
                List<Holiday__c> holidaysToUpsert = new List<Holiday__c>();
                
                for (Object item : results) {
                    Map<String, Object> holidayMap = (Map<String, Object>) item;
                    
                    Date holidayDate = Date.valueOf((String)holidayMap.get('date'));
                    String localName = (String)holidayMap.get('localName');
                    String holidayCountryCode = (String)holidayMap.get('countryCode');

                    String uniqueId = holidayDate.year() + '-' + holidayDate.month() + '-' + holidayDate.day() + '-' + holidayCountryCode;
                    
                    System.debug('HolidayAPIService: Adding holiday - ' + localName + ' | ' + holidayDate + ' | ' + holidayCountryCode + ' | ' + uniqueId);

                    holidaysToUpsert.add(new Holiday__c(
                        Name = localName,
                        Holiday_Date__c = holidayDate,
                        Country_Code__c = holidayCountryCode,
                        Deduction_Value__c = 1.0,
                        Unique_ID__c = uniqueId
                    ));
                }

                if (!holidaysToUpsert.isEmpty()) {
                    Database.upsert(holidaysToUpsert, Holiday__c.Fields.Unique_ID__c, false);
                    System.debug('HolidayAPIService: ' + holidaysToUpsert.size() + ' holidays have been synchronized for ' + this.countryCode);
                } else {
                    System.debug('HolidayAPIService: No holidays to upsert for ' + this.countryCode);
                }
            } else {
                 System.debug('HolidayAPIService: Error status code ' + res.getStatusCode() + ' for ' + this.countryCode);
            }
        } catch (Exception e) {
            System.debug('HolidayAPIService: Error syncing holidays for ' + this.countryCode + ': ' + e.getMessage() + ' at line ' + e.getLineNumber());
        }
    }



@InvocableMethod(label='Fetch Holidays for Country' description='Calls the Nager API to get holidays for a specific country and year.')
public static void fetchHolidaysFromFlow(List<Request> requests) {
    if (requests != null && !requests.isEmpty()) {
        Request req = requests[0];
        HolidayAPIService job = new HolidayAPIService(req.countryCode, req.year);
        System.enqueueJob(job);
    }
}

public class Request {
    @InvocableVariable(label='Country Code' description='The two-letter country code' required=true)
    public String countryCode;

    @InvocableVariable(label='Year' description='The year to fetch holidays for' required=true)
    public Integer year;
}
}