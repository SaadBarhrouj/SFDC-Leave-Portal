@isTest
public class ContentDocumentLinkTriggerTest {
    @isTest
    static void testSupportingDocumentReceivedIsSet() {
        User testUser = TestDataFactory.createTestUser('cdluser', 'US');
        
        Leave_Balance__c balance = TestDataFactory.createLeaveBalance(
            testUser.Id, 'Paid Leave', 10
        );

        Leave_Request__c leaveRequest = TestDataFactory.createLeaveRequest(
            testUser.Id, 'Paid Leave', Date.today().addDays(5), Date.today().addDays(7), balance.Id, 'Submitted'
        );
        
        ContentVersion ver = new ContentVersion(
            Title = 'TestDoc',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Test content')
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
}