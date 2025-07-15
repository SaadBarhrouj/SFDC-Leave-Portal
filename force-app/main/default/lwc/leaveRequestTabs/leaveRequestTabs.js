import { LightningElement, wire, track } from 'lwc';
import { MessageContext, subscribe } from 'lightning/messageService';
import LEAVE_REQUEST_SELECTED_CHANNEL from '@salesforce/messageChannel/LeaveRequestSelectedChannel__c';
import LEAVE_DATA_FOR_CALENDAR_CHANNEL from '@salesforce/messageChannel/LeaveDataForCalendarChannel__c';
import { publish } from 'lightning/messageService';
import CLEAR_SELECTION_CHANNEL from '@salesforce/messageChannel/ClearSelectionChannel__c';

export default class LeaveRequestTabs extends LightningElement {
    activeTab = 'calendar';
    subscriptionDetails;
    subscriptionCalendar;

    @wire(MessageContext)
    messageContext;
    @track selectedRecordId;
    @track selectedContext;

    connectedCallback() {
        console.log('[LeaveRequestTabs] connectedCallback');
        this.subscribeToChannels();
    }

    subscribeToChannels() {
        if (!this.subscriptionDetails) {
            this.subscriptionDetails = subscribe(
                this.messageContext,
                LEAVE_REQUEST_SELECTED_CHANNEL,
                (message) => this.handleDetailsMessage(message)
            );
        }
        if (!this.subscriptionCalendar) {
            this.subscriptionCalendar = subscribe(
                this.messageContext,
                LEAVE_DATA_FOR_CALENDAR_CHANNEL,
                (message) => this.handleCalendarMessage(message)
            );
        }
    }

    handleDetailsMessage(message) {
        console.log('[LeaveRequestTabs] Details channel message:', message);
        this.selectedRecordId = message.recordId;
        this.selectedContext = message.context;
        this.activeTab = 'detail';
    }

    handleCalendarMessage(message) {
        console.log('[LeaveRequestTabs] Calendar channel message:', message);
        if (message.context) {
            this.selectedContext = message.context;
            this.selectedRecordId = null; 
            this.activeTab = 'calendar';
            publish(this.messageContext, CLEAR_SELECTION_CHANNEL, {});
        }
    }

    handleActive(event) {
        this.activeTab = event.target.value;
        console.log('[LeaveRequestTabs] Tab active changed to:', this.activeTab);
    }
}
