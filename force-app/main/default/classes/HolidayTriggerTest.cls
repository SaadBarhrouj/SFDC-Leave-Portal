@isTest
private class HolidayTriggerTest {

    @isTest
    static void testBeforeInsert_AutoFields() {
        System.debug('TEST: Before Insert - Standard holiday creation.');
        Holiday__c h = TestDataFactory.createHoliday('Test Holiday', Date.today(), 'FR', 1.0);
        Holiday__c inserted = [SELECT Id, Start_Date__c, End_Date__c, Unique_ID__c FROM Holiday__c WHERE Id = :h.Id];
        System.debug('Inserted Holiday: ' + inserted);
        System.assertEquals(inserted.Start_Date__c, inserted.End_Date__c, 'End_Date__c should be auto-filled to Start_Date__c');
        System.assertNotEquals(null, inserted.Unique_ID__c, 'Unique_ID__c should be auto-filled');
    }


    @isTest
    static void testBeforeInsert_EndDateNotNull() {
        System.debug('TEST: Before Insert - Holiday with End_Date__c already set.');
        Holiday__c h = new Holiday__c(
            Name = 'End Date Present',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(1),
            Country_Code__c = 'FR',
            Deduction_Value__c = 1.0
        );
        insert h;
        Holiday__c inserted = [SELECT End_Date__c FROM Holiday__c WHERE Id = :h.Id];
        System.debug('Inserted Holiday (End_Date__c preset): ' + inserted);
        System.assertEquals(Date.today().addDays(1), inserted.End_Date__c, 'End_Date__c should not be changed if already set');
    }

    @isTest
    static void testBeforeUpdateAndAfterUpdate() {
        System.debug('TEST: Before/After Update - Updating holiday fields.');
        Holiday__c h = TestDataFactory.createHoliday('Update Holiday', Date.today(), 'MA', 1.0);
        h.Name = 'Updated Name';
        h.End_Date__c = null;
        h.Unique_ID__c = null;
        update h;
        Holiday__c updated = [SELECT Id, Name, End_Date__c, Unique_ID__c, Start_Date__c FROM Holiday__c WHERE Id = :h.Id];
        System.debug('Updated Holiday: ' + updated);
        System.assertEquals('Updated Name', updated.Name, 'Name should be updated');
        System.assertEquals(updated.Start_Date__c, updated.End_Date__c, 'End_Date__c should be auto-filled after update');
        System.assertNotEquals(null, updated.Unique_ID__c, 'Unique_ID__c should be auto-filled after update');
    }

    @isTest
    static void testAfterDelete() {
        System.debug('TEST: After Delete - Deleting holiday.');
        Holiday__c h = TestDataFactory.createHoliday('Delete Holiday', Date.today(), 'FR', 1.0);
        Test.startTest();
        delete h;
        Test.stopTest();
        Integer count = [SELECT count() FROM Holiday__c WHERE Id = :h.Id];
        System.debug('Deleted Holiday count: ' + count);
        System.assertEquals(0, count, 'Holiday should be deleted');
    }
}