import { LightningElement, api, wire, track } from 'lwc';
import getLeaveRequestDetails from '@salesforce/apex/LeaveRequestDetailController.getLeaveRequestDetails';

export default class LeaveRequestDetail extends LightningElement {
    @api recordId;
    @api context;
    @track leaveRequest;
    error;

    @wire(getLeaveRequestDetails, { recordId: '$recordId' })
    wiredLeaveRequest({ error, data }) {
        if (data) {
            this.leaveRequest = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.leaveRequest = undefined;
        }
    }

   get hasRecord() {
        return this.recordId && this.leaveRequest;
    }
}