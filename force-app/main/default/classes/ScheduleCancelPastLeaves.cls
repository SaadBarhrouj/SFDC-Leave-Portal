public class ScheduleCancelPastLeaves implements Schedulable {
    
    public void execute(SchedulableContext sc) {
        CancelPastLeaveRequestsBatch batch = new CancelPastLeaveRequestsBatch();
        Database.executeBatch(batch, 200);
    }
}