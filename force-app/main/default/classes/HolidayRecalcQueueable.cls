public with sharing class HolidayRecalcQueueable implements Queueable {
    private List<Holiday__c> deletedHolidays;
    
    public HolidayRecalcQueueable(List<Holiday__c> deletedHolidays) {
        this.deletedHolidays = deletedHolidays != null ? deletedHolidays.deepClone(false, true) : new List<Holiday__c>();
    }
    
    public void execute(QueueableContext qc) {
        if (deletedHolidays.isEmpty()) return;
        Set<String> countryCodes = new Set<String>();
        Date minDate = Date.newInstance(9999, 1, 1);
        Date maxDate = Date.newInstance(1000, 1, 1);
        for (Holiday__c h : deletedHolidays) {
            if (h.Country_Code__c == null) continue;
            countryCodes.add(h.Country_Code__c);
            if (h.Start_Date__c != null && h.Start_Date__c < minDate) minDate = h.Start_Date__c;
            if (h.End_Date__c != null && h.End_Date__c > maxDate) maxDate = h.End_Date__c;
        }
        if (countryCodes.isEmpty()) return;
        LeaveRequestUtils.recalcRequestsByRange(countryCodes, minDate, maxDate);
    }
}