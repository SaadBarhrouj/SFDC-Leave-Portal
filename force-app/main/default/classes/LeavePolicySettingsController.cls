public with sharing class LeavePolicySettingsController {
    
    @AuraEnabled(cacheable=true)
    public static Leave_Policy_Settings__c getLeavePolicySettings() {
        Leave_Policy_Settings__c settings = Leave_Policy_Settings__c.getOrgDefaults();
        if (settings.Id == null) {
            settings = new Leave_Policy_Settings__c();
            settings.Name = 'Default';
            settings.Annual_Paid_Leave_Days__c = 25;
            settings.Minimum_Notice_Period_Days__c = 5;
            settings.Annual_RTT_Days__c = 10;
        }
        return settings;
    }

    @AuraEnabled
    public static void saveLeavePolicySettings(Leave_Policy_Settings__c settingsToSave) {
        if (settingsToSave.Annual_Paid_Leave_Days__c == null) {
            throw new AuraHandledException('Annual Paid Leave Days cannot be empty');
        }
        if (settingsToSave.Annual_Paid_Leave_Days__c < 0) {
            throw new AuraHandledException('Annual Paid Leave Days must be a positive number');
        }
        if (settingsToSave.Annual_Paid_Leave_Days__c > 365) {
            throw new AuraHandledException('Annual Paid Leave Days cannot exceed 365 days');
        }
        if (settingsToSave.Annual_RTT_Days__c == null) {
            throw new AuraHandledException('Annual RTT Days cannot be empty');
        }
        if (settingsToSave.Annual_RTT_Days__c < 0) {
            throw new AuraHandledException('Annual RTT Days must be a positive number');
        }
        if (settingsToSave.Annual_RTT_Days__c > 365) {
            throw new AuraHandledException('Annual RTT Days cannot exceed 365 days');
        }
        if (settingsToSave.Minimum_Notice_Period_Days__c == null) {
            throw new AuraHandledException('Minimum Notice Period Days cannot be empty');
        }
        if (settingsToSave.Minimum_Notice_Period_Days__c < 0) {
            throw new AuraHandledException('Minimum Notice Period Days must be a positive number');
        }
        if (settingsToSave.Minimum_Notice_Period_Days__c > 30) {
            throw new AuraHandledException('Minimum Notice Period Days cannot exceed 30 days');
        }

        try {
            upsert settingsToSave;
            
        } catch (DmlException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}