public class AnnualLeaveBalanceScheduler implements Schedulable {
    
    public void execute(SchedulableContext sc) {
        AnnualLeaveBalanceBatch batchJob = new AnnualLeaveBalanceBatch();
        Database.executeBatch(batchJob);
    }
}