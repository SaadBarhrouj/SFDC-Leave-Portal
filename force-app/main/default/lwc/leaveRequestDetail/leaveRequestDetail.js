import getLeaveRequestDetails from '@salesforce/apex/LeaveRequestDetailController.getLeaveRequestDetails';
import getRelatedFiles from '@salesforce/apex/LeaveRequestDetailController.getRelatedFiles';
import REFRESH_LEAVE_DATA_CHANNEL from '@salesforce/messageChannel/RefreshLeaveDataChannel__c';
import { MessageContext, subscribe } from 'lightning/messageService';
import { NavigationMixin } from 'lightning/navigation';
import { LightningElement, api, track, wire } from 'lwc';

export default class LeaveRequestDetail extends NavigationMixin(LightningElement) {
    _recordId;
    @api 
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        this.refreshKey = Date.now();
    }

    @api context;
    @track leaveRequest;
    @track relatedFiles = [];
    error;

    refreshKey = Date.now();
    refreshSubscription = null;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.subscribeToRefreshChannel();
    }

    subscribeToRefreshChannel() {
        if (this.refreshSubscription) {
            return;
        }
        this.refreshSubscription = subscribe(
            this.messageContext,
            REFRESH_LEAVE_DATA_CHANNEL,
            (message) => {
                if (message.recordId === this.recordId) {
                    this.refreshFiles();
                }
            }
        );
    }

    @wire(getLeaveRequestDetails, { recordId: '$_recordId', refresh: '$refreshKey' })
    wiredLeaveRequest({ error, data }) {
        if (data) {
            this.leaveRequest = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.leaveRequest = undefined;
        }
    }

    @wire(getRelatedFiles, { recordId: '$_recordId', refresh: '$refreshKey' })
    wiredRelatedFiles({ error, data }) {
        console.log('wire getRelatedFiles', { recordId: this.recordId, refreshKey: this.refreshKey, data, error });
        if (data) {
            this.relatedFiles = data;
        } else if (error) {
            console.error('Error loading related files:', error);
            this.relatedFiles = [];
        }
    }

    @api
    refreshFiles() {
        console.log(`[leaveRequestDetail] Refreshing files for ${this.recordId}`);
        this.refreshKey = Date.now();
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