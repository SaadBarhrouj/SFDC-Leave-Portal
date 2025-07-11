import { LightningElement, wire, track } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import LEAVE_REQUEST_SELECTED_CHANNEL from '@salesforce/messageChannel/LeaveRequestSelectedChannel__c';
import getLeaveRequestDetails from '@salesforce/apex/LeaveRequestDetailController.getLeaveRequestDetails';

export default class LeaveRequestDetail extends LightningElement {
    subscription = null;
    recordId;
    context;
    isLoading = false;

    @track leaveRequest;
    error;

    @wire(MessageContext)
    messageContext;

    @wire(getLeaveRequestDetails, { recordId: '$recordId' })
    wiredLeaveRequest({ error, data }) {
        this.isLoading = true;
        if (data) {
            this.leaveRequest = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.leaveRequest = undefined;
        }
        this.isLoading = false;
    }

    connectedCallback() {
        this.subscribeToMessageChannel();
    }

    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                LEAVE_REQUEST_SELECTED_CHANNEL,
                (message) => this.handleMessage(message)
            );
        }
    }

    unsubscribeToMessageChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    handleMessage(message) {
        this.recordId = message.recordId;
        this.context = message.context;
    }

    get hasRecord() {
        return this.leaveRequest;
    }

    get isMyRequestContext() {
        return this.context === 'myRequest';
    }

    get isTeamRequestContext() {
        return this.context === 'teamRequest';
    }
}