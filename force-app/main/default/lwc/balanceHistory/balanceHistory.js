import { LightningElement } from 'lwc';

const STATIC_REMAINING_BALANCES = [
    { type: 'Vacation', days: 15.5 },
    { type: 'RTT', days: 8 }
];
const STATIC_CONSUMED_BALANCES = [
    { type: 'Training', days: 3 },
    { type: 'Sick Leave', days: 2 }
];

const HISTORY_COLUMNS_DEFINITION = [
    {
        label: 'Movement Date',
        fieldName: 'Movement_Date__c',
        type: 'date-local',
        typeAttributes: { month: "2-digit", day: "2-digit", year: "numeric" },
        initialWidth: 120
    },
    {
        label: 'Movement Type',
        fieldName: 'Movement_Type__c',
        type: 'text',
        initialWidth: 140
    },
    {
        label: 'Leave Type',
        fieldName: 'Leave_Type__c',
        type: 'text',
        initialWidth: 120
    },
    {
        label: 'Description',
        fieldName: 'Source_of_Movement__c',
        type: 'text',
        wrapText: true
    },
    {
        label: 'Change (Days)',
        fieldName: 'Number_of_Days__c',
        type: 'number',
        cellAttributes: {
            alignment: 'left'
        },
        initialWidth: 120
    },
    {
        label: 'New Balance',
        fieldName: 'New_Balance__c',
        type: 'number',
        cellAttributes: {
            alignment: 'left'
        },
        initialWidth: 120
    }
];

const STATIC_HISTORY_DATA = [
    { Movement_Date__c: '2025-07-21', Source_of_Movement__c: 'Approved Vacation Request (5 days)', Movement_Type__c: 'Leave Taken', Leave_Type__c: 'Vacation', Number_of_Days__c: -5, New_Balance__c: 15.5 },
    { Movement_Date__c: '2025-05-15', Source_of_Movement__c: 'HR Correction: End of year bonus day', Movement_Type__c: 'Adjustment', Leave_Type__c: 'N/A', Number_of_Days__c: 1, New_Balance__c: 20.5 },
    { Movement_Date__c: '2025-01-01', Source_of_Movement__c: 'Annual Allocation for new year', Movement_Type__c: 'Allocation', Leave_Type__c: 'Vacation', Number_of_Days__c: 21.5, New_Balance__c: 21.5 }
];

export default class BalanceHistory extends LightningElement {

    remainingBalances = STATIC_REMAINING_BALANCES;
    consumedBalances = STATIC_CONSUMED_BALANCES;
    historyColumns = HISTORY_COLUMNS_DEFINITION;
    historyData = STATIC_HISTORY_DATA;

    get hasData() {
        return this.historyData && this.historyData.length > 0;
    }
}