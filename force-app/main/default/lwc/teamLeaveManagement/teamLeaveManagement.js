import { LightningElement, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import LEAVE_DATA_FOR_CALENDAR_CHANNEL from '@salesforce/messageChannel/LeaveDataForCalendarChannel__c';

export default class TeamLeaveManagement extends LightningElement {
    activetabContent = 'team';

    @wire(MessageContext)
    messageContext;

    tabChangeHandler(event) {
        this.activetabContent = event.target.value;

        const payload = {
            context: this.activetabContent
        };
        publish(this.messageContext, LEAVE_DATA_FOR_CALENDAR_CHANNEL, payload);
    }
        connectedCallback() {
             const payload = {
            context: this.activetabContent
                      };

         publish(this.messageContext, LEAVE_DATA_FOR_CALENDAR_CHANNEL, payload);
        console.log('Published initial leave data for calendar with context:', this.activetabContent);  
        }

    
}