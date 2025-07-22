@isTest
public class ContentDocumentLinkTriggerTest {
    @isTest
    static void testContentDocumentLinkTrigger_LeaveRequest() {
        User testUser = TestDataFactory.createTestUser('docuser', 'US');
        Leave_Request__c leaveRequest = TestDataFactory.createLeaveRequest(
            testUser.Id, 'Vacation', Date.today(), Date.today(), null
        );
        insert leaveRequest;

        ContentVersion ver = new ContentVersion(
            Title = 'DocTest',
            PathOnClient = 'DocTest.pdf',
            VersionData = Blob.valueOf('Test')
        );
        insert ver;

        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :ver.Id].ContentDocumentId;

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = leaveRequest.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert link;

        Leave_Request__c updatedLeaveRequest = [
            SELECT Supporting_Document_Received__c FROM Leave_Request__c WHERE Id = :leaveRequest.Id
        ];
        System.assertEquals(true, updatedLeaveRequest.Supporting_Document_Received__c, 'Supporting document should be marked as received');
    }

    @isTest
    static void testContentDocumentLinkTrigger_NotLeaveRequest() {
        User testUser = TestDataFactory.createTestUser('docuser2', 'US');
        Leave_Request__c leaveRequest = TestDataFactory.createLeaveRequest(
            testUser.Id, 'Vacation', Date.today(), Date.today(), null
        );
        insert leaveRequest;

        ContentVersion ver = new ContentVersion(
            Title = 'DocTest2',
            PathOnClient = 'DocTest2.pdf',
            VersionData = Blob.valueOf('Test2')
        );
        insert ver;

        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :ver.Id].ContentDocumentId;

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = testUser.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert link;

        Leave_Request__c updatedLeaveRequest = [
            SELECT Supporting_Document_Received__c FROM Leave_Request__c WHERE Id = :leaveRequest.Id
        ];
        System.assertEquals(false, updatedLeaveRequest.Supporting_Document_Received__c, 'Supporting document should NOT be marked as received');
    }
}