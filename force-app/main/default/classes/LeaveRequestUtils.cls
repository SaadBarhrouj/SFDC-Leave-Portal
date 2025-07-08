public class LeaveRequestUtils {

    public static Decimal calculateRequestedDays(Date startDate, Date endDate, String countryCode) {
        if (startDate == null || endDate == null || startDate > endDate) {
            return 0;
        }

        Map<Date, Holiday__c> holidaysMap = new Map<Date, Holiday__c>();
        for (Holiday__c holiday : [
            SELECT Holiday_Date__c, Deduction_Value__c 
            FROM Holiday__c
            WHERE Holiday_Date__c >= :startDate 
              AND Holiday_Date__c <= :endDate
              AND Country_Code__c = :countryCode
        ]) {
            holidaysMap.put(holiday.Holiday_Date__c, holiday);
        }

        Decimal requestedDays = 0;
        Date currentDate = startDate;

        while (currentDate <= endDate) {

            Datetime dt = Datetime.newInstance(currentDate.year(), currentDate.month(), currentDate.day());
            String dayOfWeek = dt.format('E');

            if (dayOfWeek != 'Sat' && dayOfWeek != 'Sun') {
                if (holidaysMap.containsKey(currentDate)) {
                    Decimal deduction = holidaysMap.get(currentDate).Deduction_Value__c;
                    requestedDays += (1 - deduction);
                } else {
                    requestedDays += 1;
                }
            }
            currentDate = currentDate.addDays(1);
        }
        return requestedDays;
    }
}