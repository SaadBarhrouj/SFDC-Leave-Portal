import { LightningElement, wire } from 'lwc';
import getBalanceHistoryForCurrentUser from '@salesforce/apex/LeaveBalanceController.getBalanceHistoryForCurrentUser';

const HISTORY_COLUMNS_DEFINITION = [
    { label: 'Movement Date', fieldName: 'Movement_Date__c', type: 'date-local' },
    { label: 'Movement Type', fieldName: 'Movement_Type__c', type: 'text' },
    { label: 'Leave Type', fieldName: 'Leave_Type__c', type: 'text' },
    { label: 'Description', fieldName: 'Source_of_Movement__c', type: 'text', wrapText: true, initialWidth: 350 },
    { label: 'Change (Days)', fieldName: 'Number_of_Days__c', type: 'text', cellAttributes: { alignment: 'left' } },
    { label: 'New Balance', fieldName: 'New_Balance__c', type: 'number', cellAttributes: { alignment: 'left' } }
];

export default class BalanceHistory extends LightningElement {
    remainingBalances = [];
    consumedBalances = [];
    historyData;
    error;
    historyColumns = HISTORY_COLUMNS_DEFINITION;
    
    @wire(getBalanceHistoryForCurrentUser)
    wiredHistory({ error, data }) {
        if (data) {
            this.historyData = data.map(row => {
                const newRow = { ...row };
                const days = newRow.Number_of_Days__c;
                
                if (days != null && !isNaN(days)) {
                    if (days > 0) {
                        newRow.Number_of_Days__c = `+${days}`;
                    } else {
                        newRow.Number_of_Days__c = String(days);
                    }
                }
                return newRow;
            });
            this.error = undefined;
        } else if (error) {
            this.error = error;
            console.error('Error loading balance history:', error);
            this.historyData = undefined;
        }
    }

    get hasData() {
        return this.historyData && this.historyData.length > 0;
    }
}