public with sharing class LeavePolicySettingsController {
    @AuraEnabled(cacheable=true)
    public static Leave_Policy_Settings__c getLeavePolicySettings() {
        Leave_Policy_Settings__c settings = Leave_Policy_Settings__c.getOrgDefaults();
        if (settings.Id == null) {
            settings = new Leave_Policy_Settings__c();
            settings.Name = 'Default';
            settings.Annual_Paid_Leave_Days__c = 25;
        }
        return settings;
    }

    @AuraEnabled
    public static void saveLeavePolicySettings(Leave_Policy_Settings__c settingsToSave) {
        try {
            upsert settingsToSave;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}