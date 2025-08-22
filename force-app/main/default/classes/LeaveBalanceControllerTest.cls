@isTest
private class LeaveBalanceControllerTest {

    @TestSetup
    static void makeData() {
        // Create a test user
        User testUser = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id,
            LastName = 'Test',
            Email = 'testuser@example.com',
            Username = 'testuser@example.com' + System.currentTimeMillis(),
            CompanyName = 'TestCorp',
            Title = 'Tester',
            Alias = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            Work_Country__c = 'US'
        );
        insert testUser;

        // Create Leave Policy Settings
        Leave_Policy_Settings__c settings = new Leave_Policy_Settings__c(
            Annual_Paid_Leave_Days__c = 25,
            Minimum_Notice_Period_Days__c = 5
        );
        insert settings;

        // Create Leave Balances for the test user
        List<Leave_Balance__c> balances = new List<Leave_Balance__c>();
        balances.add(new Leave_Balance__c(
            Employee__c = testUser.Id,
            Year__c = Date.today().year(),
            Leave_Type__c = 'Paid Leave',
            Allocated_Days__c = 20
        ));
        balances.add(new Leave_Balance__c(
            Employee__c = testUser.Id,
            Year__c = Date.today().year(),
            Leave_Type__c = 'RTT',
            Allocated_Days__c = 10
        ));
        insert balances;

        // Create Leave Requests for the test user to test consumed calculations
        List<Leave_Request__c> requests = new List<Leave_Request__c>();
        requests.add(new Leave_Request__c(
            Requester__c = testUser.Id,
            Leave_Type__c = 'Sick Leave',
            Start_Date__c = Date.today().addDays(-10),
            End_Date__c = Date.today().addDays(-9),
            Status__c = 'Approved'
        ));
        requests.add(new Leave_Request__c(
            Requester__c = testUser.Id,
            Leave_Type__c = 'Training',
            Start_Date__c = Date.today().addDays(5),
            End_Date__c = Date.today().addDays(6),
            Status__c = 'Approved'
        ));
        requests.add(new Leave_Request__c(
            Requester__c = testUser.Id,
            Leave_Type__c = 'Paid Leave',
            Start_Date__c = Date.today().addDays(7),
            End_Date__c = Date.today().addDays(8),
            Status__c = 'Approved'
        ));
        insert requests;

        // Create Balance History
        Leave_Balance_History__c history = new Leave_Balance_History__c(
            Employee__c = testUser.Id,
            Leave_Type__c = 'Paid Leave',
            Movement_Date__c = Date.today(),
            Movement_Type__c = 'Correction',
            Number_of_Days__c = 1,
            New_Balance__c = 16,
            Source_of_Movement__c = 'Test Correction',
            Justification__c = 'Test Justification'
        );
        insert history;
    }

    @isTest
    static void testGetLeaveBalanceOverviews() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        
        Test.startTest();
        System.runAs(testUser) {
            List<LeaveBalanceController.BalanceOverview> overviews = LeaveBalanceController.getLeaveBalanceOverviews();
            System.assertEquals(5, overviews.size(), 'Should return 5 balance overviews.');
            
            Decimal sickLeaveDays = LeaveRequestUtils.calculateRequestedDays(
                Date.today().addDays(-10), Date.today().addDays(-9), 'US'
            );
            Decimal trainingDays = LeaveRequestUtils.calculateRequestedDays(
                Date.today().addDays(5), Date.today().addDays(6), 'US'
            );
            Decimal paidLeaveDays = LeaveRequestUtils.calculateRequestedDays(
                Date.today().addDays(7), Date.today().addDays(8), 'US'
            );

            for(LeaveBalanceController.BalanceOverview overview : overviews){
                if(overview.type == 'Paid Leave'){
                    System.assertEquals(20 - paidLeaveDays, overview.remaining, 'Remaining paid leave should match calculated value.');
                    System.assertEquals(paidLeaveDays, overview.consumed, 'Consumed paid leave should match calculated value.');
                }
                if(overview.type == 'Sick Leave'){
                    System.assertEquals(sickLeaveDays, overview.consumed, 'Consumed sick leave should match calculated value.');
                }
            }
        }
        Test.stopTest();
    }

    @isTest
    static void testGetLeavePolicySettings() {
        Test.startTest();
        Leave_Policy_Settings__c settings = LeaveBalanceController.getLeavePolicySettings();
        Test.stopTest();
        
        System.assertNotEquals(null, settings);
        System.assertEquals(25, settings.Annual_Paid_Leave_Days__c);
    }

    @isTest
    static void testGetBalances() {
        Test.startTest();
        List<Leave_Balance__c> balances = LeaveBalanceController.getBalances();
        Test.stopTest();
        
        System.assertNotEquals(null, balances);
        System.assertEquals(2, balances.size(), 'Should return two balances for RTT and Paid Leave.');
    }

    @isTest
    static void testGetAllBalanceHistory() {
        Test.startTest();
        List<Leave_Balance_History__c> history = LeaveBalanceController.getAllBalanceHistory();
        Test.stopTest();
        
        System.assertNotEquals(null, history);
        System.assertEquals(3, history.size());
    }

    @isTest
    static void testGetBalanceHistoryForCurrentUser() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        
        Test.startTest();
        System.runAs(testUser) {
            List<Leave_Balance_History__c> history = LeaveBalanceController.getBalanceHistoryForCurrentUser();
            System.assertNotEquals(null, history);
            System.assertEquals(3, history.size());
        }
        Test.stopTest();
    }

    @isTest
    static void testDeleteBalanceWithJustification_Success() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        Leave_Balance__c balanceToDelete = new Leave_Balance__c(
            Employee__c = testUser.Id,
            Year__c = Date.today().year(),
            Leave_Type__c = 'Paid Leave',
            Allocated_Days__c = 5,
            Used_Days__c = 0
        );
        insert balanceToDelete;

        Test.startTest();
        LeaveBalanceController.deleteBalanceWithJustification(balanceToDelete.Id, 'Test deletion');
        Test.stopTest();

        List<Leave_Balance__c> balances = [SELECT Id FROM Leave_Balance__c WHERE Id = :balanceToDelete.Id];
        System.assertEquals(0, balances.size(), 'Balance should be deleted.');

        List<Leave_Balance_History__c> allHistory = [SELECT Id, Justification__c FROM Leave_Balance_History__c];
        List<Leave_Balance_History__c> filteredHistory = new List<Leave_Balance_History__c>();
        for (Leave_Balance_History__c history : allHistory) {
            if (history.Justification__c == 'Test deletion') {
                filteredHistory.add(history);
            }
        }
        System.assertEquals(1, filteredHistory.size(), 'History record should be created for deletion.');
    }

    @isTest
    static void testDeleteBalanceWithJustification_NoJustification() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        Leave_Balance__c balanceToDelete = new Leave_Balance__c(
            Employee__c = testUser.Id,
            Year__c = Date.today().year(),
            Leave_Type__c = 'RTT',
            Allocated_Days__c = 5,
            Used_Days__c = 0
        );
        insert balanceToDelete;

        Test.startTest();
        try {
            LeaveBalanceController.deleteBalanceWithJustification(balanceToDelete.Id, '');
            System.assert(false, 'Exception was not thrown');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateBalanceWithJustification_Success() {
        Leave_Balance__c balanceToUpdate = [SELECT Id FROM Leave_Balance__c WHERE Leave_Type__c = 'Paid Leave' LIMIT 1];
        
        Test.startTest();
        LeaveBalanceController.updateBalanceWithJustification(balanceToUpdate.Id, 25, 'Annual adjustment');
        Test.stopTest();

        Leave_Balance__c updatedBalance = [SELECT Allocated_Days__c FROM Leave_Balance__c WHERE Id = :balanceToUpdate.Id];
        System.assertEquals(25, updatedBalance.Allocated_Days__c, 'Allocated days should be updated.');

        List<Leave_Balance_History__c> allHistory = [SELECT Id, Justification__c FROM Leave_Balance_History__c];
        List<Leave_Balance_History__c> filteredHistory = new List<Leave_Balance_History__c>();
        for (Leave_Balance_History__c history : allHistory) {
            if (history.Justification__c == 'Annual adjustment') {
                filteredHistory.add(history);
            }
        }
        System.assertEquals(1, filteredHistory.size(), 'History record should be created for update.');
    }

    @isTest
    static void testUpdateBalanceWithJustification_NoJustification() {
        Leave_Balance__c balanceToUpdate = [SELECT Id FROM Leave_Balance__c WHERE Leave_Type__c = 'Paid Leave' LIMIT 1];
        
        Test.startTest();
        try {
            LeaveBalanceController.updateBalanceWithJustification(balanceToUpdate.Id, 22, null);
            System.assert(false, 'Exception was not thrown for null justification.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}