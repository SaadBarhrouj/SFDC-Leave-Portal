import { LightningElement, wire } from 'lwc';
import { MessageContext, subscribe } from 'lightning/messageService';
import LEAVE_REQUEST_SELECTED_CHANNEL from '@salesforce/messageChannel/LeaveRequestSelectedChannel__c';

export default class LeaveRequestTabs extends LightningElement {

    activeTab = 'calendar';
    subscription;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.subscribeToMessageChannel();
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                LEAVE_REQUEST_SELECTED_CHANNEL,
                (message) => this.tabChangeHandler(message)
            );
        }
    }

    tabChangeHandler(message) {
        this.activeTab = 'detail';
    }
}
