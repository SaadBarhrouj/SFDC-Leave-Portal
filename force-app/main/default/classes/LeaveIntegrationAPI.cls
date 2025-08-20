@RestResource(urlMapping='/leave/requests')
global with sharing class LeaveIntegrationAPI {

    global class LeaveRequestWrapper {
        global String userEmail;
        global String leaveType;
        global Date startDate;
        global Date endDate;
        global String employeeComment;
        global String approverComment;
        global String status;
    }

    global class Result {
        global String status;
        global String message;
        global String salesforceRequestId;
        global LeaveRequestWrapper originalRequest;

        Result(String status, String message, String salesforceRequestId, LeaveRequestWrapper originalRequest) {
            this.status = status;
            this.message = message;
            this.salesforceRequestId = salesforceRequestId;
            this.originalRequest = originalRequest;
        }
    }

    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestBody = req.requestBody.toString();
        
        try {
            if (requestBody.trim().startsWith('[')) {
                processBulkRequests(req, res);
            } else {
                processNewRequest(req, res);
            }
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Result('Error', e.getMessage(), null, null)));
        }
    }

    private static void processNewRequest(RestRequest req, RestResponse res) {
        LeaveRequestWrapper wrapper;
        try {
            wrapper = (LeaveRequestWrapper) JSON.deserialize(req.requestBody.toString(), LeaveRequestWrapper.class);
        } catch (Exception e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new Result('Error', 'Invalid JSON format.', null, null)));
            return;
        }

        List<LeaveRequestWrapper> wrappers = new List<LeaveRequestWrapper>{ wrapper };
        List<Result> results = processLeaveRequests(wrappers);
        
        Result singleResult = results[0];
        if (singleResult.status == 'Success') {
            res.statusCode = 201;
        } else {
            res.statusCode = 400;
        }
        res.responseBody = Blob.valueOf(JSON.serialize(singleResult));
    }

    private static void processBulkRequests(RestRequest req, RestResponse res) {
        List<LeaveRequestWrapper> wrappers;
        try {
            wrappers = (List<LeaveRequestWrapper>) JSON.deserialize(req.requestBody.toString(), List<LeaveRequestWrapper>.class);
        } catch (Exception e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new Result('Error', 'Invalid JSON format for bulk request.', null, null)));
            return;
        }

        List<Result> results = processLeaveRequests(wrappers);
        res.statusCode = 207;
        res.responseBody = Blob.valueOf(JSON.serialize(results));
    }

    private static List<Result> processLeaveRequests(List<LeaveRequestWrapper> wrappers) {
        Map<String, User> emailToUserMap = getUsersFrom(wrappers);
        Map<String, Leave_Balance__c> balances = getLeaveBalancesFor(emailToUserMap.values());

        List<Leave_Request__c> requestsToInsert = new List<Leave_Request__c>();
        Map<Integer, LeaveRequestWrapper> indexToWrapperMap = new Map<Integer, LeaveRequestWrapper>();
        List<Result> results = new List<Result>();

        for (LeaveRequestWrapper wrapper : wrappers) {
            User u = emailToUserMap.get(wrapper.userEmail);
            if (u == null) {
                results.add(new Result('Error', 'Active user not found for email: ' + wrapper.userEmail, null, wrapper));
                continue;
            }

            Decimal requestYear = Decimal.valueOf(wrapper.startDate.year());
            String balanceKey = u.Id + '-' + requestYear + '-' + wrapper.leaveType;
            
            if (!balances.containsKey(balanceKey)) {
                results.add(new Result('Error', 'Leave balance not found for user.', null, wrapper));
                continue;
            }

            Leave_Request__c newRequest = new Leave_Request__c(
                Requester__c = u.Id,
                Leave_Balance__c = balances.get(balanceKey).Id,
                Leave_Type__c = wrapper.leaveType,
                Start_Date__c = wrapper.startDate,
                End_Date__c = wrapper.endDate,
                Employee_Comments__c = wrapper.employeeComment,
                Approver_Comments__c = wrapper.approverComment,
                Status__c = wrapper.status
            );
            requestsToInsert.add(newRequest);
            indexToWrapperMap.put(requestsToInsert.size() - 1, wrapper);
        }

        if (!requestsToInsert.isEmpty()) {
            List<Database.SaveResult> saveResults = Database.insert(requestsToInsert, false);

            for (Integer i = 0; i < saveResults.size(); i++) {
                Database.SaveResult sr = saveResults[i];
                LeaveRequestWrapper originalWrapper = indexToWrapperMap.get(i);
                
                if (sr.isSuccess()) {
                    results.add(new Result('Success', 'Leave request created.', sr.getId(), originalWrapper));
                } else {
                    String errorMessage = sr.getErrors().size() > 0 ? sr.getErrors()[0].getMessage() : 'Failed to create leave request.';
                    results.add(new Result('Error', errorMessage, null, originalWrapper));
                }
            }
        }

        return results;
    }

    private static Map<String, User> getUsersFrom(List<LeaveRequestWrapper> wrappers) {
        Set<String> userEmails = new Set<String>();
        for (LeaveRequestWrapper wrapper : wrappers) {
            if (wrapper.userEmail != null) {
                userEmails.add(wrapper.userEmail);
            }
        }

        Map<String, User> emailToUserMap = new Map<String, User>();
        if (!userEmails.isEmpty()) {
            for (User u : [SELECT Id, Email FROM User WHERE Email IN :userEmails AND IsActive = true]) {
                emailToUserMap.put(u.Email, u);
            }
        }
        return emailToUserMap;
    }

    private static Map<String, Leave_Balance__c> getLeaveBalancesFor(List<User> users) {
        Map<String, Leave_Balance__c> balances = new Map<String, Leave_Balance__c>();
        if (!users.isEmpty()) {
            Set<Id> employeeIds = new Map<Id, User>(users).keySet();
            for (Leave_Balance__c balance : [SELECT Id, Employee__c, Year__c, Leave_Type__c FROM Leave_Balance__c WHERE Employee__c IN :employeeIds]) {
                String key = balance.Employee__c + '-' + String.valueOf(balance.Year__c.intValue()) + '-' + balance.Leave_Type__c;
                balances.put(key, balance);
            }
        }
        return balances;
    }
}