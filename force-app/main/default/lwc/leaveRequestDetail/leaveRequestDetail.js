import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLeaveRequestDetails from '@salesforce/apex/LeaveRequestDetailController.getLeaveRequestDetails';
import getRelatedFiles from '@salesforce/apex/LeaveRequestDetailController.getRelatedFiles';

export default class LeaveRequestDetail extends NavigationMixin(LightningElement) {
    @api recordId;
    @api context;
    @track leaveRequest;
    @track relatedFiles = [];
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

    @wire(getRelatedFiles, { recordId: '$recordId' })
    wiredRelatedFiles({ error, data }) {
        if (data) {
            this.relatedFiles = data;
        } else if (error) {
            console.error('Error loading related files:', error);
            this.relatedFiles = [];
        }
    }

    get hasRecord() {
        return this.recordId && this.leaveRequest;
    }

    get isRejected() {
        return this.leaveRequest && this.leaveRequest.Status__c === 'Rejected';
    }

    get hasFiles() {
        return this.relatedFiles && this.relatedFiles.length > 0;
    }

    handleFilePreview(event) {
        const fileId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                recordIds: fileId,
                selectedRecordId: fileId
            }
        });
    }
}