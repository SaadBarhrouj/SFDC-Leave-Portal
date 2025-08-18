public with sharing class AbsentEmployeesPDFController {
    public List<Leave_Request__c> absences { get; set; }

    public AbsentEmployeesPDFController() {
        Date today = Date.today();

        String employeeName = ApexPages.currentPage().getParameters().get('employeeName');
        String leaveType = ApexPages.currentPage().getParameters().get('leaveType');

        String query = 'SELECT Requester__r.Name, Leave_Type__c, Start_Date__c, End_Date__c FROM Leave_Request__c WHERE (Status__c = \'Approved\' OR Status__c = \'Cancellation Requested\')';

        query += ' AND Start_Date__c <= :today AND End_Date__c >= :today';

        if (employeeName != null && employeeName.trim() != '') {
            query += ' AND Requester__r.Name LIKE :employeeName';
        }
        if (leaveType != null && leaveType.trim() != '') {
            query += ' AND Leave_Type__c = :leaveType';
        }
        
        query += ' ORDER BY Start_Date__c ASC';
        
        this.absences = Database.query(query);
    }
}