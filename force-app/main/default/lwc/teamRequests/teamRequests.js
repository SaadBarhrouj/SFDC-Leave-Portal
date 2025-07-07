import { LightningElement } from 'lwc';

const ACTIONS = [
    { label: 'Approve', name: 'approve' },
    { label: 'Reject', name: 'reject' }
];

const COLUMNS = [
    { label: 'Requester', fieldName: 'RequesterName', type: 'text' },
    { label: 'Leave Type', fieldName: 'Leave_Type__c', type: 'text' },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date-local' },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date-local' },
    { label: 'Days', fieldName: 'Number_of_Days_Requested__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { type: 'action', typeAttributes: { rowActions: ACTIONS } }
];

export default class TeamRequests extends LightningElement {
    requests = [{
            Id: 1,
            RequesterName: 'ELKIHAL Youness',
            Leave_Type__c: 'Medical',
            Start_Date__c: '2020-01-01',
            End_Date__c: '2020-01-01',
            Number_of_Days_Requested__c: 1
    }];

    columns = COLUMNS;

    get hasRequests() {
        return this.requests && this.requests.length > 0;
    }
}