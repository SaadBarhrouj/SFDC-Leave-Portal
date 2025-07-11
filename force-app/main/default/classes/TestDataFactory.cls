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
            Country_Code__c = countryCode != null ? countryCode : 'US'
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
            Country_Code__c = countryCode != null ? countryCode : 'MA'
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
     * Creates a holiday record
     */
    public static Holiday__c createHoliday(String name, Date holidayDate, String countryCode, Decimal deductionValue) {
        Holiday__c holiday = new Holiday__c(
            Name = name,
            Unique_ID__c = countryCode + holidayDate.format() + System.currentTimeMillis(),
            Holiday_Date__c = holidayDate,
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
}