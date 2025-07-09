// Get the ID of the user who will be the requester.
Id requesterId = '005Sv00000AwZnkIAF';
Decimal currentYear = Date.today().year();


// Create a list to hold the new leave requests.
List<Leave_Request__c> requestsToCreate = new List<Leave_Request__c>();

// Request 1: Vacation
Leave_Request__c vacationRequest = new Leave_Request__c(
    Leave_Balance__c = 'a02Sv00000BcwajIAB',
    Requester__c = requesterId,
    Status__c = 'Pending Approval',
    Leave_Type__c = 'Vacation',
    Start_Date__c = Date.today().addMonths(1),
    End_Date__c = Date.today().addMonths(1).addDays(4) // 5 days total
);
requestsToCreate.add(vacationRequest);

// Request 2: Sick Leave
Leave_Request__c sickRequest = new Leave_Request__c(
    Leave_Balance__c = 'a02Sv00000BcwakIAB',
    Requester__c = requesterId,
    Status__c = 'Pending Approval',
    Leave_Type__c = 'RTT',
    Start_Date__c = Date.today().addDays(7),
    End_Date__c = Date.today().addDays(7) // 1 day total
);
requestsToCreate.add(sickRequest);

// Insert the list of new requests into the database.
try {
    insert requestsToCreate;
    System.debug(requestsToCreate.size() + ' leave requests created successfully.');
} catch (DmlException e) {
    System.debug('An error occurred while creating requests: ' + e.getMessage());
}