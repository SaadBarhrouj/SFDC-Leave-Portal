@isTest
private class LeaveRequestDetailControllerTest {

    @TestSetup
    static void makeData() {
        // Create a user to own the records
        User testUser = TestDataFactory.createTestUser('testu', 'MA');
        
        System.runAs(testUser) {
            // Create a leave balance and request for the user
            Leave_Balance__c balance = TestDataFactory.createLeaveBalance(testUser.Id, 'Paid Leave', 20);
            Leave_Request__c request = new Leave_Request__c(
                Requester__c = testUser.Id,
                Leave_Type__c = 'Paid Leave',
                Start_Date__c = Date.today().addDays(10),
                End_Date__c = Date.today().addDays(12),
                Leave_Balance__c = balance.Id,
                Status__c = 'Submitted'
            );
            insert request;
        }
    }

    @isTest
    static void testGetLeaveRequestDetails_Success() {
        Leave_Request__c req = [SELECT Id FROM Leave_Request__c LIMIT 1];
        User sysAdminUser = TestDataFactory.createTestUser('uAdmin', 'MA', 'System Administrator');

        Test.startTest();
        System.runAs(sysAdminUser) {
            Leave_Request__c result = LeaveRequestDetailController.getLeaveRequestDetails(req.Id, null);
            System.assertNotEquals(null, result, 'Leave request should not be null.');
            System.assertEquals(req.Id, result.Id, 'Leave request ID should match.');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetLeaveRequestDetails_NullId() {
        Test.startTest();
        Leave_Request__c result = LeaveRequestDetailController.getLeaveRequestDetails(null, null);
        Test.stopTest();
        System.assertEquals(null, result, 'Result should be null for a null Id.');
    }
    
    @isTest
    static void testGetLeaveRequestDetails_NoAccess() {
        Leave_Request__c req = [SELECT Id FROM Leave_Request__c LIMIT 1];
        User noAccessUser = TestDataFactory.createTestUser('noaccess', 'MA');
        
        Exception caughtException = null;
        Test.startTest();
        System.runAs(noAccessUser) {
            try {
                LeaveRequestDetailController.getLeaveRequestDetails(req.Id, null);
            } catch (Exception e) {
                caughtException = e;
            }
        }
        Test.stopTest();
        
        System.assertNotEquals(null, caughtException, 'A security exception should have been thrown.');
    }

    @isTest
    static void testGetRelatedFiles_WithFiles() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];
        Leave_Request__c req = [SELECT Id FROM Leave_Request__c LIMIT 1];

        // Create and link the file within the test, as the correct user
        System.runAs(testUser) {
            ContentVersion cv = new ContentVersion(
                Title = 'Test Attachment', PathOnClient = 'attachment.txt',
                VersionData = Blob.valueOf('Test content'), IsMajorVersion = true
            );
            insert cv;
            Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
            insert new ContentDocumentLink(
                ContentDocumentId = docId, LinkedEntityId = req.Id, ShareType = 'V'
            );
        }

        Test.startTest();
        System.runAs(testUser) {
            List<ContentDocument> files = LeaveRequestDetailController.getRelatedFiles(req.Id, null);
            System.assertNotEquals(null, files, 'File list should not be null.');
            System.assertEquals(1, files.size(), 'Should retrieve one related file.');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetRelatedFiles_NoFiles() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];
        Leave_Request__c req = [SELECT Id FROM Leave_Request__c LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<ContentDocument> files = LeaveRequestDetailController.getRelatedFiles(req.Id, null);
            System.assertEquals(0, files.size(), 'Should return an empty list for a request with no files.');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetRelatedFiles_NullId() {
        Test.startTest();
        List<ContentDocument> files = LeaveRequestDetailController.getRelatedFiles(null, null);
        Test.stopTest();
        System.assertEquals(0, files.size(), 'Should return an empty list for a null Id.');
    }

    @isTest
    static void testDeleteRelatedFile_Success() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];
        Leave_Request__c req = [SELECT Id FROM Leave_Request__c LIMIT 1];
        Id docId;

        // Create and link the file as the user who will delete it
        System.runAs(testUser) {
            ContentVersion cv = new ContentVersion(
                Title = 'File to Delete', PathOnClient = 'delete.txt',
                VersionData = Blob.valueOf('Test content'), IsMajorVersion = true
            );
            insert cv;
            docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
            insert new ContentDocumentLink(
                ContentDocumentId = docId, LinkedEntityId = req.Id, ShareType = 'V'
            );
        }

        Test.startTest();
        System.runAs(testUser) {
            LeaveRequestDetailController.deleteRelatedFile(docId, req.Id);
        }
        Test.stopTest();

        List<ContentDocumentLink> remainingLinks = [
            SELECT Id 
            FROM ContentDocumentLink 
            WHERE ContentDocumentId = :docId AND LinkedEntityId = :req.Id
        ];
        System.assertEquals(0, remainingLinks.size(), 'The file link should have been deleted.');
    }
}