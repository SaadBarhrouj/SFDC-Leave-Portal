import { LightningElement, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import LEAVE_DATA_FOR_CALENDAR_CHANNEL from '@salesforce/messageChannel/LeaveDataForCalendarChannel__c';

export default class LeaveRequests extends LightningElement {
    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.publishContext('my');
    }

    handleTabSelect(event) {
        const selectedTab = event.target.value;
        this.publishContext(selectedTab);
    }

    publishContext(tabName) {
        const payload = { context: tabName };
        publish(this.messageContext, LEAVE_DATA_FOR_CALENDAR_CHANNEL, payload);
    }
}