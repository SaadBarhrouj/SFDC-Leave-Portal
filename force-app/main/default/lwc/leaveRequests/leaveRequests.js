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
        const selectedTab = event.detail.value;
        this.publishContext(selectedTab);
    }

    publishContext(context) {
        const payload = { context: context };
        publish(this.messageContext, LEAVE_DATA_FOR_CALENDAR_CHANNEL, payload);
    }
}