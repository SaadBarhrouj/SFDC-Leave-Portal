<<<<<<< Updated upstream
import { LightningElement } from 'lwc';

export default class MyRequests extends LightningElement {}
=======
import { LightningElement, track, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import LEAVE_REQUEST_SELECTED_CHANNEL from '@salesforce/messageChannel/LeaveRequestSelectedChannel__c';

const DATA =[
    {
        Id: '1',
        Name: 'REQ-001',
        Leave_Type__c: 'Annual Leave',
        Start_Date__c: '2024-02-15',
        End_Date__c: '2024-02-19',
        Number_of_Days_Requested__c: 5,
        Status__c: 'Pending',
        Employee_Comments__c: 'Family vacation',
        Approver_Comments__c: null,
        Rejection_Reason__c: null
    },
    {
        Id: '2',
        Name: 'REQ-002',
        Leave_Type__c: 'Sick Leave',
        Start_Date__c: '2024-02-10',
        End_Date__c: '2024-02-12',
        Number_of_Days_Requested__c: 3,
        Status__c: 'Approved',
        Employee_Comments__c: 'Medical appointment',
        Approver_Comments__c: 'Approved for medical reasons',
        Rejection_Reason__c: null
    },
    {
        Id: '3',
        Name: 'REQ-003',
        Leave_Type__c: 'Personal Leave',
        Start_Date__c: '2024-03-01',
        End_Date__c: '2024-03-01',
        Number_of_Days_Requested__c: 1,
        Status__c: 'Rejected',
        Employee_Comments__c: 'Personal matters',
        Approver_Comments__c: 'Not enough notice provided',
        Rejection_Reason__c: 'Insufficient advance notice'
    }
];

const actions = [
    { label: 'Show details', name: 'show_details' },
    { label: 'Edit', name: 'edit' },
    { label: 'Cancel', name: 'cancel' }
];

const COLUMNS = [
    { label: 'Request Number', fieldName: 'Name', sortable: true },
    { label: 'Leave Type', fieldName: 'Leave_Type__c', sortable: true },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date', sortable: true },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date', sortable: true },
    { label: 'Days Requested', fieldName: 'Number_of_Days_Requested__c', type: 'number', sortable: true },
    { 
        label: 'Status', 
        fieldName: 'Status__c',
        type: 'text',
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'statusClass' }
        }
    },
    { label: 'My Comments', fieldName: 'Employee_Comments__c', wrapText: true },
    {
        type: 'action',
        typeAttributes: { 
            rowActions: { fieldName: 'availableActions' }
        }
    }
];

export default class MyRequests extends LightningElement {
    @track requests = [];
    columns = COLUMNS;

    @wire(MessageContext)
    messageContext;
    
    connectedCallback() {
        this.requests = this.processRequestsForDisplay(DATA);
    }

    processRequestsForDisplay(rawData) {
        return rawData.map(request => {
            let managerResponse = '';
            let statusClass = '';
            let availableActions = [];

            switch(request.Status__c) {
                case 'Pending':
                    statusClass = 'slds-text-color_weak';
                    managerResponse = 'Pending...';
                    availableActions = [
                        { label: 'Show details', name: 'show_details' },
                        { label: 'Edit', name: 'edit' },
                        { label: 'Cancel', name: 'cancel' }
                    ];
                    break;
                case 'Approved':
                    statusClass = 'slds-text-color_success';
                    managerResponse = request.Approver_Comments__c || 'Approved';
                    availableActions = [
                        { label: 'Show details', name: 'show_details' }
                    ];
                    break;
                case 'Rejected':
                    statusClass = 'slds-text-color_error';
                    managerResponse = request.Rejection_Reason__c || request.Approver_Comments__c || 'Rejected';
                    availableActions = [
                        { label: 'Show details', name: 'show_details' }
                    ];
                    break;
                case 'Cancelled':
                    statusClass = 'slds-text-color_weak';
                    managerResponse = 'Cancelled by employee';
                    availableActions = [
                        { label: 'Show details', name: 'show_details' }
                    ];
                    break;
                default:
                    statusClass = '';
                    managerResponse = '';
                    availableActions = [];
            }

            return {
                ...request,
                statusClass: statusClass,
                managerResponse: managerResponse,
                availableActions: availableActions
            };
        });
    }
    

    get hasRequests() {
        return this.requests && this.requests.length > 0;
    }
    
    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows.length > 0) {
            const payload = { 
                recordId: selectedRows[0].Id,
                context: 'myRequest'
            };
            publish(this.messageContext, LEAVE_REQUEST_SELECTED_CHANNEL, payload);
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'show_details':
                this.showRowDetails(row);
                break;
            case 'edit':
                this.editRequest(row);
                break;
            case 'cancel':
                this.cancelRequest(row);
                break;
            default:
        }
    }

    showRowDetails(row) {
        const payload = { 
            recordId: row.Id,
            context: 'myRequest'
        };
        publish(this.messageContext, LEAVE_REQUEST_SELECTED_CHANNEL, payload);
    }

    editRequest(row) {
        console.log('Edit request:', row);
        if (row.Status__c !== 'Pending') {
            alert('You can only edit requests with Pending status');
            return;
        }
        alert('Edit functionality to be implemented');
    }

    cancelRequest(row) {
        console.log('Cancel request:', row);
        if (row.Status__c !== 'Pending') {
            alert('You can only cancel requests with Pending status');
            return;
        }
        
        if (confirm(`Are you sure you want to cancel request ${row.Name}?`)) {
            this.updateRequestStatus(row.Id, 'Cancelled');
        }
    }

    updateRequestStatus(requestId, newStatus) {
        this.requests = this.requests.map(request => {
            if (request.Id === requestId) {
                return { ...request, Status__c: newStatus };
            }
            return request;
        });
        
        this.requests = this.processRequestsForDisplay(this.requests);
        
        console.log(`Request ${requestId} status updated to ${newStatus}`);
    }

    handleNewRequest() {
        console.log('New Request clicked');
        alert('New Request functionality to be implemented');
    }

    

}
>>>>>>> Stashed changes
