Id managerId = UserInfo.getUserId();
Integer currentYear = Date.today().year();

Leave_Balance__c paidLeaveBalance = new Leave_Balance__c(
    Employee__c = managerId,
    Leave_Type__c = 'Paid Leave',
    Year__c = currentYear,
    Allocated_Days__c = 25
);

Leave_Balance__c rttBalance = new Leave_Balance__c(
    Employee__c = managerId,
    Leave_Type__c = 'RTT',
    Year__c = currentYear,
    Allocated_Days__c = 10
);

insert new List<Leave_Balance__c>{paidLeaveBalance, rttBalance};