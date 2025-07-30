import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { subscribe, MessageContext } from 'lightning/messageService';
import LEAVE_REQUEST_MODIFIED_CHANNEL from '@salesforce/messageChannel/LeaveRequestModifiedChannel__c';
import getTeamRequests from '@salesforce/apex/TeamRequestsController.getTeamRequests';

const STATUSES_TO_DISPLAY = [
    'Pending Manager Approval',
    'Pending HR Approval',
    'Escalated to Senior Manager',
    'Cancellation Requested'
];

export default class LeaveRequestDashboard extends LightningElement {

    wiredRequestsResult; 
    subscription = null; 

    @wire(MessageContext)
    messageContext;

    @wire(getTeamRequests)
    wiredRequests(result) {
        this.wiredRequestsResult = result;
    }

    connectedCallback() {
        this.subscribeToMessageChannel();
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                LEAVE_REQUEST_MODIFIED_CHANNEL, 
                (message) => this.handleRefresh() 
            );
        }
    }

    handleRefresh() {
        return refreshApex(this.wiredRequestsResult);
    }

    get requestCounts() {
        if (this.wiredRequestsResult && this.wiredRequestsResult.data) {
            const counts = {};
            STATUSES_TO_DISPLAY.forEach(status => {
                counts[status] = 0;
            });

            this.wiredRequestsResult.data.forEach(request => {
                if (counts.hasOwnProperty(request.Status__c)) {
                    counts[request.Status__c]++;
                }
            });

            let totalRequests = 0;
            const displayData = STATUSES_TO_DISPLAY.map(status => {
                const count = counts[status];
                totalRequests += count;
                return {
                    id: status,
                    label: status,
                    value: count,
                    unit: 'Requests'
                };
            });

            displayData.push({
                id: 'Total',
                label: 'Total Pending',
                value: totalRequests,
                unit: 'Requests'
            });

            return displayData;
        }

        return [];
    }

    get error() {
        return this.wiredRequestsResult && this.wiredRequestsResult.error;
    }
}