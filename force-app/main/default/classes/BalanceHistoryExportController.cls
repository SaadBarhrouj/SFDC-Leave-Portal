public with sharing class BalanceHistoryExportController {
    public List<Leave_Balance_History__c> histories { get; set; }
    public Boolean showEmployee { get; set; }

    public BalanceHistoryExportController() {
        String emp = ApexPages.currentPage().getParameters().get('employee');
        String type = ApexPages.currentPage().getParameters().get('type');
        String movementType = ApexPages.currentPage().getParameters().get('movementType');
        String start = ApexPages.currentPage().getParameters().get('start');
        String endDate = ApexPages.currentPage().getParameters().get('end');
        String showEmpParam = ApexPages.currentPage().getParameters().get('showEmployee');

        showEmployee = (showEmpParam == 'true')? true : false;

        Date startDateVal;
        Date endDateVal;

        if (start != null && start != '') startDateVal = Date.valueOf(start);
        if (endDate != null && endDate != '') endDateVal = Date.valueOf(endDate);

        Id currentUserId = UserInfo.getUserId();

        String query = 'SELECT Employee__r.Name, Leave_Type__c, Movement_Date__c, Movement_Type__c, Source_of_Movement__c, Justification__c, Number_of_Days__c, New_Balance__c FROM Leave_Balance_History__c WHERE Id != null';

        if (showEmployee) {
            if (emp != null && emp != '') query += ' AND Employee__r.Name LIKE :emp';
        } else {
            query += ' AND Employee__c = :currentUserId';
        }

        if (type != null && type != '') query += ' AND Leave_Type__c = :type';
        if (movementType != null && movementType != '') query += ' AND Movement_Type__c = :movementType';
        if (startDateVal != null) query += ' AND Movement_Date__c >= :startDateVal';
        if (endDateVal != null) query += ' AND Movement_Date__c <= :endDateVal';

        query += ' ORDER BY Movement_Date__c DESC LIMIT 200';
        System.debug('Valeur de showEmployee : ' + showEmployee);
        histories = Database.query(query);
    }
}
