// 1. Get your user Id (the manager)
Id managerId = UserInfo.getUserId(); // ou remplacez par votre Id si besoin

// 2. Créer un nouvel utilisateur dont vous êtes le manager
Profile userProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

User teamMember = new User(
    Alias = 'tmember',
    Email = 'team.member@example.com',
    EmailEncodingKey = 'UTF-8',
    LastName = 'ELKIHAL',
    FirstName = 'Youness',
    LanguageLocaleKey = 'en_US',
    LocaleSidKey = 'en_US',
    ProfileId = userProfile.Id,
    TimeZoneSidKey = 'Europe/Paris',
    UserName = 'team.member+' + System.currentTimeMillis() + '@example.com',
    Work_Country__c = 'MR',
    ManagerId = managerId
);

insert teamMember;

// 3. Créer les soldes de congés pour ce nouvel utilisateur
Integer currentYear = Date.today().year();

Leave_Balance__c paidLeaveBalance = new Leave_Balance__c(
    Employee__c = teamMember.Id,
    Leave_Type__c = 'Paid Leave',
    Year__c = currentYear,
    Allocated_Days__c = 25
);

Leave_Balance__c rttBalance = new Leave_Balance__c(
    Employee__c = teamMember.Id,
    Leave_Type__c = 'RTT',
    Year__c = currentYear,
    Allocated_Days__c = 10
);

insert new List<Leave_Balance__c>{paidLeaveBalance, rttBalance};

// 4. Créer des demandes de congé pour ce collaborateur
List<Leave_Request__c> requestsToCreate = new List<Leave_Request__c>();

Leave_Request__c paidLeaveRequest = new Leave_Request__c(
    Leave_Balance__c = paidLeaveBalance.Id,
    Requester__c = teamMember.Id,
    Leave_Type__c = 'Paid Leave',
    Start_Date__c = Date.today().addMonths(1),
    End_Date__c = Date.today().addMonths(1).addDays(4)
);
requestsToCreate.add(paidLeaveRequest);

Leave_Request__c rttRequest = new Leave_Request__c(
    Leave_Balance__c = rttBalance.Id,
    Requester__c = teamMember.Id,
    Leave_Type__c = 'RTT',
    Start_Date__c = Date.today().addDays(7),
    End_Date__c = Date.today().addDays(7)
);
requestsToCreate.add(rttRequest);

try {
    insert requestsToCreate;
    System.debug(requestsToCreate.size() + ' leave requests created for your team member.');
} catch (DmlException e) {
    System.debug('An error occurred while creating requests: ' + e.getMessage());
}