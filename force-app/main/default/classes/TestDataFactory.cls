@isTest
public class TestDataFactory {
    
    private static Integer userCounter = 0;
    
    /**
     * Creates a test user with unique identifiers
     */
    public static User createTestUser(String alias, String countryCode) {
        userCounter++;
        
        if (alias == null) {
            alias = 'tuser' + userCounter;
        }
        
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        
        User testUser = new User(
            Alias = alias,
            Email = 'testuser' + userCounter + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestUser' + userCounter,
            FirstName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser' + userCounter + '@test.com' + System.currentTimeMillis(),
            Work_Country__c = countryCode != null ? countryCode : 'US'
        );
        
        insert testUser;
        return testUser;
    }
    
    /**
     * Overloaded method to create a test user with specified profile
     */
    public static User createTestUser(String alias, String countryCode, String profileName) {
        userCounter++;
        if (alias == null) {
            alias = 'tuser' + userCounter;
        }
        if (profileName == null) {
            profileName = 'Standard User';
        }
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        
        User testUser = new User(
            Alias = alias,
            Email = 'testuser' + userCounter + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestUser' + userCounter,
            FirstName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser' + userCounter + '@test.com' + System.currentTimeMillis(),
            Work_Country__c = countryCode != null ? countryCode : 'MA'
        );
        
        insert testUser;
        return testUser;
    }
    
    /**
     * Creates a leave balance for a user
     */
    public static Leave_Balance__c createLeaveBalance(Id userId, String leaveType, Decimal allocatedDays) {
        Leave_Balance__c lb = new Leave_Balance__c(
            Employee__c = userId,
            Leave_Type__c = leaveType,
            Allocated_Days__c = allocatedDays,
            Year__c = Date.today().year()
        );
        insert lb;
        return lb;
    }
    
    /**
     * Creates a leave request
     */
    public static Leave_Request__c createLeaveRequest(Id requesterId, String leaveType, Date startDate, Date endDate, Id balanceId) {
        Leave_Request__c request = new Leave_Request__c(
            Requester__c = requesterId,
            Leave_Type__c = leaveType,
            Start_Date__c = startDate,
            End_Date__c = endDate
        );
        
        if (balanceId != null) {
            request.Leave_Balance__c = balanceId;
        }
        
        return request;
    }
    
    /**
     * Creates a leave request
     */
    public static Leave_Request__c createLeaveRequest(
        Id requesterId, String leaveType, Date startDate, Date endDate, Id balanceId, String status
    ) {
        Leave_Request__c req = new Leave_Request__c(
            Requester__c = requesterId,
            Leave_Type__c = leaveType,
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Leave_Balance__c = balanceId,
            Status__c = status
        );
        insert req;
        return req;
    }
    
    /**
     * Creates a holiday record
     */
    public static Holiday__c createHoliday(String name, Date holidayDate, String countryCode, Decimal deductionValue) {
        Holiday__c holiday = new Holiday__c(
            Name = name,
            Unique_ID__c = countryCode + holidayDate.format() + System.currentTimeMillis(),
            Start_Date__c = holidayDate, 
            End_Date__c = holidayDate,   
            Country_Code__c = countryCode,
            Deduction_Value__c = deductionValue
        );
        insert holiday;
        return holiday;
    }
    
    /**
     * Creates multiple holidays
     */
    public static List<Holiday__c> createHolidays(List<Map<String, Object>> holidayData) {
        List<Holiday__c> holidays = new List<Holiday__c>();
        for (Map<String, Object> data : holidayData) {
            holidays.add(createHoliday(
                (String) data.get('name'),
                (Date) data.get('date'),
                (String) data.get('countryCode'),
                (Decimal) data.get('deductionValue')
            ));
        }
        return holidays;
    }
    
    /**
     * Creates a leave request for current month
     */
    public static Leave_Request__c createLeaveRequest(Id requesterId, String leaveType, Integer daysFromToday, Integer duration) {
        Date startDate = Date.today().addDays(daysFromToday);
        Date endDate = startDate.addDays(duration - 1);
        return createLeaveRequest(requesterId, leaveType, startDate, endDate, null);
    }

    /**
     * Creates multiple test users
     */
    public static List<User> createTestUsers(Integer count, String countryCode) {
        List<User> users = new List<User>();
        for (Integer i = 0; i < count; i++) {
            users.add(createTestUser(null, countryCode));
        }
        return users;
    }

    /**
     * Creates multiple leave balances for a user
     */
    public static List<Leave_Balance__c> createLeaveBalances(Id userId, Map<String, Decimal> leaveTypesWithDays) {
        List<Leave_Balance__c> balances = new List<Leave_Balance__c>();
        for (String leaveType : leaveTypesWithDays.keySet()) {
            balances.add(createLeaveBalance(userId, leaveType, leaveTypesWithDays.get(leaveType)));
        }
        return balances;
    }
    
    public static Integer getMinimumNoticePeriod() {
        Integer minNotice = 5;
        Leave_Policy_Settings__c policy = Leave_Policy_Settings__c.getOrgDefaults();
        if (policy != null && policy.Minimum_Notice_Period_Days__c != null) {
            minNotice = Integer.valueOf(policy.Minimum_Notice_Period_Days__c);
        }
        return minNotice;
    }

    public static Leave_Request__c createSickLeaveApprovedForToday(Id userId) {
        Date today = Date.today();
        Leave_Request__c req = new Leave_Request__c(
            Requester__c = userId,
            Leave_Type__c = 'Sick Leave',
            Start_Date__c = today.addDays(-1),
            End_Date__c = today.addDays(1),
            Status__c = 'Approved'
        );
        insert req;
        return req;
    }

    public static Leave_Balance_History__c createCorrectionHistory(
        Id employeeId, String employeeName, Date movementDate, String leaveType, String source, String justification, Decimal days, Decimal newBalance
    ) {
        Leave_Balance_History__c hist = new Leave_Balance_History__c(
            Employee__c = employeeId,
            Leave_Type__c = leaveType,
            Movement_Date__c = movementDate,
            Movement_Type__c = 'Correction',
            Source_of_Movement__c = source,
            Justification__c = justification,
            Number_of_Days__c = days,
            New_Balance__c = newBalance
        );
        insert hist;
        return hist;
    }

    public static Leave_Balance_History__c createDeductionHistory(
        Id employeeId, Date movementDate, String leaveType, String source, String justification, Decimal days, Decimal newBalance
    ) {
        Leave_Balance_History__c hist = new Leave_Balance_History__c(
            Employee__c = employeeId,
            Leave_Type__c = leaveType,
            Movement_Date__c = movementDate,
            Movement_Type__c = 'Deduction',
            Source_of_Movement__c = source,
            Justification__c = justification,
            Number_of_Days__c = days,
            New_Balance__c = newBalance
        );
        insert hist;
        return hist;
    }

    public static Leave_Balance_History__c createAccrualHistory(
        Id employeeId, Date movementDate, String leaveType, String source, String justification, Decimal days, Decimal newBalance
    ) {
        Leave_Balance_History__c hist = new Leave_Balance_History__c(
            Employee__c = employeeId,
            Leave_Type__c = leaveType,
            Movement_Date__c = movementDate,
            Movement_Type__c = 'Accrual',
            Source_of_Movement__c = source,
            Justification__c = justification,
            Number_of_Days__c = days,
            New_Balance__c = newBalance
        );
        insert hist;
        return hist;
    }

    /**
     * Crée une Leave_Request__c générique pour n'importe quel type et statut.
     */
    public static Leave_Request__c createLeaveRequestGeneric(
        Id requesterId,
        String leaveType,
        Date startDate,
        String status
    ) {
        Leave_Request__c req = new Leave_Request__c(
            Requester__c = requesterId,
            Leave_Type__c = leaveType,
            Start_Date__c = startDate,
            Status__c = status
        );
        insert req;
        return req;
    }

    /**
     * Crée une Leave_Request__c pour Paid Leave.
     */
    public static Leave_Request__c createPaidLeaveRequest(Id requesterId, Date startDate, String status) {
        return createLeaveRequestGeneric(requesterId, 'Paid Leave', startDate, status);
    }

    /**
     * Crée une Leave_Request__c pour RTT.
     */
    public static Leave_Request__c createRTTLeaveRequest(Id requesterId, Date startDate, String status) {
        return createLeaveRequestGeneric(requesterId, 'RTT', startDate, status);
    }

    /**
     * Crée une Leave_Request__c pour Sick Leave.
     */
    public static Leave_Request__c createSickLeaveRequest(Id requesterId, Date startDate, String status) {
        return createLeaveRequestGeneric(requesterId, 'Sick Leave', startDate, status);
    }

    public static Leave_Balance__c createPaidLeaveBalance(Id userId, Decimal allocatedDays, Integer year) {
        Leave_Balance__c lb = new Leave_Balance__c(
            Employee__c = userId,
            Leave_Type__c = 'Paid Leave',
            Allocated_Days__c = allocatedDays,
            Year__c = year
        );
        insert lb;
        return lb;
    }

    public static Leave_Balance__c createRTTBalance(Id userId, Decimal allocatedDays, Integer year) {
        Leave_Balance__c lb = new Leave_Balance__c(
            Employee__c = userId,
            Leave_Type__c = 'RTT',
            Allocated_Days__c = allocatedDays,
            Year__c = year
        );
        insert lb;
        return lb;
    }
}