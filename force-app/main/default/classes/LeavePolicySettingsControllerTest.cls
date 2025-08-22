@isTest
public class LeavePolicySettingsControllerTest {
    
    @isTest
    static void testGetLeavePolicySettings() {
        Test.startTest();
        Leave_Policy_Settings__c settings = LeavePolicySettingsController.getLeavePolicySettings();
        Test.stopTest();
        System.assertNotEquals(null, settings);
        System.assertEquals(25, settings.Annual_Paid_Leave_Days__c);
        System.assertEquals(0, settings.Minimum_Notice_Period_Days__c);
    }
    
    @isTest
    static void testSaveLeavePolicySettings_Success() {
        Leave_Policy_Settings__c settings = new Leave_Policy_Settings__c(
            Name = 'Test',
            Annual_Paid_Leave_Days__c = 20,
            Annual_RTT_Days__c = 10,
            Minimum_Notice_Period_Days__c = 3
        );
        Test.startTest();
        LeavePolicySettingsController.saveLeavePolicySettings(settings);
        Test.stopTest();
        List<Leave_Policy_Settings__c> results = [SELECT Id, Annual_Paid_Leave_Days__c, Annual_RTT_Days__c, Minimum_Notice_Period_Days__c FROM Leave_Policy_Settings__c WHERE Name = 'Test'];
        System.assertEquals(1, results.size());
        System.assertEquals(20, results[0].Annual_Paid_Leave_Days__c);
        System.assertEquals(10, results[0].Annual_RTT_Days__c);
        System.assertEquals(3, results[0].Minimum_Notice_Period_Days__c);
    }
    
    @isTest
    static void testSaveLeavePolicySettings_AnnualPaidLeaveDaysNull() {
        Leave_Policy_Settings__c settings = new Leave_Policy_Settings__c(
            Name = 'Test',
            Annual_RTT_Days__c = 10,
            Minimum_Notice_Period_Days__c = 3
        );
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            LeavePolicySettingsController.saveLeavePolicySettings(settings);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.debug('Exception message: ' + e.getMessage());
            System.assert(
                e.getMessage().contains('Annual Paid Leave Days cannot be empty') ||
                e.getMessage().contains('Script-thrown exception'),
                'Exception message should contain the expected text.'
            );
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown.');
    }
    
    @isTest
    static void testSaveLeavePolicySettings_AnnualPaidLeaveDaysNegative() {
        Leave_Policy_Settings__c settings = new Leave_Policy_Settings__c(
            Name = 'Test',
            Annual_Paid_Leave_Days__c = -1,
            Annual_RTT_Days__c = 10,
            Minimum_Notice_Period_Days__c = 3
        );
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            LeavePolicySettingsController.saveLeavePolicySettings(settings);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.debug('Exception message: ' + e.getMessage());
            System.assert(
                e.getMessage().contains('Annual Paid Leave Days must be a positive number') ||
                e.getMessage().contains('Script-thrown exception'),
                'Exception message should contain the expected text.'
            );
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown.');
    }

    @isTest
    static void testSaveLeavePolicySettings_AnnualPaidLeaveDaysTooHigh() {
        Leave_Policy_Settings__c settings = new Leave_Policy_Settings__c(
            Name = 'Test',
            Annual_Paid_Leave_Days__c = 400,
            Annual_RTT_Days__c = 10,
            Minimum_Notice_Period_Days__c = 3
        );
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            LeavePolicySettingsController.saveLeavePolicySettings(settings);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.debug('Exception message: ' + e.getMessage());
            System.assert(
                e.getMessage().contains('Annual Paid Leave Days cannot exceed 365 days') ||
                e.getMessage().contains('Script-thrown exception'),
                'Exception message should contain the expected text.'
            );
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown.');
    }

    @isTest
    static void testSaveLeavePolicySettings_AnnualRTTDaysNull() {
        Leave_Policy_Settings__c settings = new Leave_Policy_Settings__c(
            Name = 'Test',
            Annual_Paid_Leave_Days__c = 10,
            Minimum_Notice_Period_Days__c = 3
        );
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            LeavePolicySettingsController.saveLeavePolicySettings(settings);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.debug('Exception message: ' + e.getMessage());
            System.assert(
                e.getMessage().contains('Annual RTT Days cannot be empty') ||
                e.getMessage().contains('Script-thrown exception'),
                'Exception message should contain the expected text.'
            );
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown.');
    }

    @isTest
    static void testSaveLeavePolicySettings_AnnualRTTDaysNegative() {
        Leave_Policy_Settings__c settings = new Leave_Policy_Settings__c(
            Name = 'Test',
            Annual_Paid_Leave_Days__c = 10,
            Annual_RTT_Days__c = -1,
            Minimum_Notice_Period_Days__c = 3
        );
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            LeavePolicySettingsController.saveLeavePolicySettings(settings);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.debug('Exception message: ' + e.getMessage());
            System.assert(
                e.getMessage().contains('Annual RTT Days must be a positive number') ||
                e.getMessage().contains('Script-thrown exception'),
                'Exception message should contain the expected text.'
            );
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown.');
    }
    
    @isTest
    static void testSaveLeavePolicySettings_AnnualRTTDaysTooHigh() {
        Leave_Policy_Settings__c settings = new Leave_Policy_Settings__c(
            Name = 'Test',
            Annual_Paid_Leave_Days__c = 10,
            Annual_RTT_Days__c = 400,
            Minimum_Notice_Period_Days__c = 3
        );
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            LeavePolicySettingsController.saveLeavePolicySettings(settings);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.debug('Exception message: ' + e.getMessage());
            System.assert(
                e.getMessage().contains('Annual RTT Days cannot exceed 365 days') ||
                e.getMessage().contains('Script-thrown exception'),
                'Exception message should contain the expected text.'
            );
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown.');
    }

    @isTest
    static void testSaveLeavePolicySettings_MinimumNoticeNull() {
        Leave_Policy_Settings__c settings = new Leave_Policy_Settings__c(
            Name = 'Test',
            Annual_Paid_Leave_Days__c = 10,
            Annual_RTT_Days__c = 10
        );
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            LeavePolicySettingsController.saveLeavePolicySettings(settings);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.debug('Exception message: ' + e.getMessage());
            System.assert(
                e.getMessage().contains('Minimum Notice Period Days cannot be empty') ||
                e.getMessage().contains('Script-thrown exception'),
                'Exception message should contain the expected text.'
            );
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown.');
    }
    
    @isTest
    static void testSaveLeavePolicySettings_MinimumNoticeNegative() {
        Leave_Policy_Settings__c settings = new Leave_Policy_Settings__c(
            Name = 'Test',
            Annual_Paid_Leave_Days__c = 10,
            Annual_RTT_Days__c = 10,
            Minimum_Notice_Period_Days__c = -2
        );
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            LeavePolicySettingsController.saveLeavePolicySettings(settings);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.debug('Exception message: ' + e.getMessage());
            System.assert(
                e.getMessage().contains('Minimum Notice Period Days must be a positive number') ||
                e.getMessage().contains('Script-thrown exception'),
                'Exception message should contain the expected text.'
            );
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown.');
    }
    
    @isTest
    static void testSaveLeavePolicySettings_MinimumNoticeTooHigh() {
        Leave_Policy_Settings__c settings = new Leave_Policy_Settings__c(
            Name = 'Test',
            Annual_Paid_Leave_Days__c = 10,
            Annual_RTT_Days__c = 10,
            Minimum_Notice_Period_Days__c = 40
        );
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            LeavePolicySettingsController.saveLeavePolicySettings(settings);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.debug('Exception message: ' + e.getMessage());
            System.assert(
                e.getMessage().contains('Minimum Notice Period Days cannot exceed 30 days') ||
                e.getMessage().contains('Script-thrown exception'),
                'Exception message should contain the expected text.'
            );
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown.');
    }

    @isTest
    static void testSaveLeavePolicySettings_DmlException() {
        // Create a record to simulate an existing one.
        Leave_Policy_Settings__c settings = new Leave_Policy_Settings__c(
            Name = 'DmlTest',
            Annual_Paid_Leave_Days__c = 15,
            Annual_RTT_Days__c = 5,
            Minimum_Notice_Period_Days__c = 2
        );
        insert settings;
        
        // Simulate a DML exception by attempting to update an invalid ID.
        Leave_Policy_Settings__c settingsToUpdate = new Leave_Policy_Settings__c(
            Id = 'a00000000000000', // Dummy and invalid ID
            Name = 'DmlTest',
            Annual_Paid_Leave_Days__c = 20,
            Annual_RTT_Days__c = 10,
            Minimum_Notice_Period_Days__c = 3
        );
        
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            LeavePolicySettingsController.saveLeavePolicySettings(settingsToUpdate);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.debug('Exception message: ' + e.getMessage());
            System.assert(
                e.getMessage().contains('Id not specified in an update call') ||
                e.getMessage().contains('Invalid Id') ||
                e.getMessage().contains('Script-thrown exception'),
                'The DML exception message should be caught.'
            );
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown.');
    }
}